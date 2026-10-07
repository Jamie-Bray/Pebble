# Independent audit: backup, accounts, player and widget

7 October 2026. Audited Claude's `claude/vibrant-euler-ltockb` at `c5cfd16`,
including its `feat/phone-feedback-1` base, against `origin/main` at `3538694`.
Work is on `codex/audit-backup-account-ux`. No production deployment or release
upload is part of this audit.

## Verdict

Claude's changes address the reported problems and the shorter backup/sign-in
screens are a better direction. However, "everything is fixed" was too strong:
independent review found additional retry, restore, account-switch and
accessibility bugs. The follow-up fixes below retain that design and strengthen
the existing backup implementation without adding dependencies or new services.

This is a code and automated-test audit, with rendered-screen inspection.
It is not proof of a successful backup on Jamie's phone or a two-phone restore.

## What the original work does cover

| Original problem | Evidence reviewed |
| --- | --- |
| Misleading last-backup time, lost retries and completed runs not queued | Coordinator/outbox changes and failure, queueing, concurrent-edit and timestamp tests |
| Backup/sign-in is too complicated | Single backup status card, short consent sheet, account-choice guard, sign-in routing and recovery actions |
| Camera return loses AI captions | Stable player dependencies, caption store and regression tests for provider refresh and late completion |
| Multiple photos and missing descriptions | Per-photo caption selection, retry feedback, completion/photo gallery and history persistence |
| Four or more completion photos overflow | Width-constrained thumbnail strip, extra-photo tile and small/large-text renders |
| Widget link opens an unknown route | Native deep-link opt-out, external-location parsing, launch tests and Android compilation attempt |
| Home checked state is unpredictable | Shared checked-window rule and tests; next qualifying reminder or next 4am boundary |

Reviewed the wider diff as well: onboarding/composer changes, consent text/hash,
UTC serialisation, billing/access gates, account ownership, navigation, native
widget resources and the additional tests. No purchase/restore call ordering,
consent version, build number or server schema was changed by this follow-up.

## Additional defects fixed

1. **Voice-tip metadata retry.** An audio file could upload successfully, then
   its routine write could fail. The retry used to see an existing local file
   key and clear the queue without saving that key remotely. It now retries the
   row write, while avoiding pointless row writes when the clip still fails.
2. **Deleted routines returning during audio upload.** A missing local row was
   replaced with the old snapshot. A deleted routine now stays deleted.
3. **Held-back session photos losing their retry.** Saving a session with a
   photo still waiting could clear its only queue item. The session remains
   retryable and cannot produce a clean-backup timestamp.
4. **Restore overwriting edits made during download.** Restore now reads the
   current local row and queue inside the merge transaction, after downloading.
5. **Restore undoing pending deletions.** Queued deletions act as tombstones
   until acknowledged; downloading an older server copy cannot recreate them.
6. **Unconfirmed backup appearing green.** An empty queue does not prove backup
   is confirmed. Cached consent that could not be checked stays in a waiting
   state, with useful wording even when there are zero queued items.
7. **Reconnect retry using the wrong operation.** Manual/foreground retry now
   rechecks consent and finishes failed setup before attempting uploads. A
   failed restore cannot be hidden by a later successful upload.
8. **Old-account upload updating the new account.** Backup checks its starting
   account and upload permission after remote work and before completing queue
   items. Changed access stops the pass without marking the new account clean.
9. **Stale completion/history screens.** Open screens observe the saved run.
   The completion receipt uses live backup status; an uploaded run alone does
   not prove its photos are backed up. Late saved captions reach open history.
10. **Backup exit error.** The deferred prompt reset no longer writes into a
    disposed provider; a deferred consent prompt also checks screen lifetime.
11. **Screen-reader controls without actions.** Backup's switch remains in the
    accessibility tree. Caption retry/expand, photo controls and checked-step
    expansion expose working actions, with activation tests.
12. **AI upload after permission changes during preparation.** The describer
    rechecks the account and active AI consent before sending the prepared
    image. Account changes or withdrawal cancel preparation.

Regression coverage also checks that a photo uploaded before a failed run-row
write eventually gets its remote key saved, rather than merely clearing its
queue item.

## UX and simplification decisions

- Keep the one-card Backup screen and details behind links. It is substantially
  easier to scan than the previous multi-section dashboard.
- Keep the short sign-in and consent sheets. The recorded backup statement is
  unchanged; the introductory sentence now describes backup without promising
  that the account makes data "safe".
- Keep the photo strip and one selected caption. No extra permanent panels,
  account modes or setup steps were added.
- Use existing providers and database streams for live receipts/history.
  The completion receipt conservatively waits if any backup work remains,
  instead of introducing a second per-run backup state machine.
- AI preparation conservatively stops if any originally active AI routine is
  disabled during preparation. The existing describer API has no routine ID;
  cancelling is preferable to sending under a changed permission snapshot.

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| Required CI-equivalent unit/widget suite | 574 passed; 141 opt-in walkthrough cases skipped in this invocation |
| Full opt-in screenshot walkthrough | 141 passed, 303 PNGs, empty layout-error report |
| Final coordinator regressions, including metadata retry and account switch | 26 passed |
| `flutter build apk --debug --no-pub` | Android debug APK built, including Kotlin widget code |
| Unfiltered `flutter test` | Known Windows golden difference remains; see below |

Local Flutter is 3.44.6 / Dart 3.12.2; CI pins Flutter 3.47.6. SDK-generated
desktop files and lockfile changes from local tooling are excluded.

Logs and screenshots are ignored local artifacts in `artifacts/`: use
`audit-tests-ci.log`, `audit-analyze-final.log`, `audit-android-build-final.log`,
`audit-coordinator-final.log` and `audit-walkthrough-final/`. Representative
screens inspected include narrow sign-in, Backup, multi-photo player at 2x text,
AI description selection and the completion receipt.

The first walkthrough found four Backup-screen disposal errors; those produced
the lifecycle fix above. The initial full test run also reproduced the known
Windows Sandstone golden mismatch (0.41%, 11,800 pixels). The golden and its
tolerance were not changed to hide this difference. CI already runs goldens as
informational separately from its required unit/widget suite.

GitHub's failed run `37583935464` has no executed job steps. Its check annotation
explicitly says recent account payments failed or the spending limit needs
increasing. This is confirmed evidence, not an inference from a short runtime.
The branch must not be merged into `main` until required CI can run and passes.

## Remaining phone/release checks

1. With a currently active test subscription, sign in, enable backup, complete
   a routine with multiple photos and a voice tip, then restore on another
   phone using the same account. Check actual content, not only the status.
2. Start offline, make edits, reconnect with Pebble still open, and confirm
   backup catches up. Repeat after an app restart and after pausing backup.
3. Return from the real camera, finish before descriptions arrive, and inspect
   both the completion screen and history. Test consent withdrawal and account
   switching while preparation/upload is pending.
4. Add and tap the Android widget in cold and warm app states. Native periodic
   refresh is not an exact alarm, so a sleeping widget can lag the checked-window
   boundary. There is still no iOS widget target.

No live subscription, Supabase state, AI provider response, completion-email
delivery or store release has been certified by these local tests. Resolve CI
availability and run the phone checks before describing the build as released.
