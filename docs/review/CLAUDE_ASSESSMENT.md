# Claude's assessment of the Gemini review (PRs #3 and #4)

**Date:** 4 October 2026
**Base:** `origin/main` at `f5c3beb`
**Local toolchain:** Flutter 3.44.6 on Windows (the project pins 3.47.6; CI uses the pin)

Each item is marked **Demonstrated** (reproduced or shown by a test or log),
**Hypothesis** (supported by source reading only), **Intentional** (works as
designed) or **Blocked** (cannot be checked from this machine).

## 1. What I ran

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 389 passed, 120 skipped (the walkthrough, which needs `WALKTHROUGH=1`), 1 failed (Sandstone golden, 0.41%) |
| Walkthrough on unchanged `main` | 114 scenarios passed, 6 failed |
| Walkthrough with Gemini's proposed fix | Not run. Existing tests already show it cannot work (section 2) |
| Walkthrough with the fix in this branch | 120 passed, 0 failed, 235 captures |
| CI on `main` and on PRs #3 and #4 | "Analyze and test" passes. "Android debug build" fails |

Gemini reported 412 passing tests; I count 389 on the same commit. I could not
account for the difference. Gemini's "114 captures" is the number of passing
scenarios, not screenshots.

## 2. Walkthrough failures: Demonstrated, and Gemini's fix was wrong

Gemini's diagnosis (stale `tapText('Add')`) is half of the cause. Its fix
(`'Add photo'` for the first photo, `'Add more'` for the second) would not work:

- Before the first photo there is no "Add photo" button. The control is the
  main **Take photo** button. `routine_player_guidance_audio_test.dart` asserts
  `find.text('Add photo')` finds nothing at that point.
- **Add more** is the locked upgrade button shown to Free users. It opens the
  paywall; it does not add a second photo.

The second half of the cause, which Gemini did not find: the harness's fake
camera reads `sample_photo_1.jpg` and `sample_photo_2.jpg` from
`walkthrough_support/`. Those files were never committed and exist on neither
machine, so the fake camera silently returned nothing and the photo step never
completed.

Fix in this branch (`test/walkthrough/walkthrough_screens_test.dart`):

- First photo taps the primary button; the second taps "Add photo".
- When the sample photos are missing, the fake camera falls back to tracked
  fixtures so a fresh checkout still completes the run. Photos placed in
  `walkthrough_support/` still take priority.

Two free-to-use sample photos (a door handle and a pill organiser) are now
committed in `test/walkthrough/fixtures/`, so the screenshots show realistic
proof photos on any machine.

## 3. CI is red on `main`: Demonstrated, not reported by Gemini

The "Android debug build" job fails on `main` and on both PRs with
`No space left on device` while unpacking Android NDK r27. Gemini's local debug
build passing does not cover this. `CLAUDE.md` requires green CI before
anything merges, so this blocks every PR.

Fix in this branch (`.github/workflows/ci.yml`): remove preinstalled toolchains
the job never uses before the build starts. Whether that frees enough space is
shown by this branch's own CI run.

## 4. Golden mismatch: environment-specific, cause not isolated

The same golden test **passes in CI** (Linux, Flutter 3.47.6) and fails locally
(Windows, Flutter 3.44.6) by 0.41%. So it is not an app defect. Gemini
attributed it to the operating system; the Flutter version differs too, and
nothing here separates the two. No baseline change is needed.

## 5. Account switching and "Use this account"

**Intentional:** the behaviour Gemini describes exists and is covered by the
test `can move this device local data to the signed-in account`. Backup is
blocked by default when another account's data is on the device. The sheet
offers "Keep backup off" as the alternative.

**Where Gemini overstated it:**

- "Exposes User A's data to User B." Local data is not separated by account on
  the device. The local queries do not filter by owner, so User B already sees
  User A's routines and photos before choosing anything. The device is the
  boundary, as in most local-first apps. Gemini's review table also says data
  is "isolated by `ownerUserId`", which is not true for local reads.
- "Destructive merge." User A's cloud copy is not changed or deleted.
- "Un-uploaded data." The function moves every row, uploaded or not.

**What is left is a wording decision for the owner, not a launch blocker.** The
sheet says "This device has Pebble data from another sign-in. Use *email* from
now on so backup can continue." It does not say plainly that the other
sign-in's routines and photos will be copied into this account's backup. A
clearer sentence would cost one line of copy. A "remove this device's data"
option at sign-out is a larger feature and can wait.

**Hypothesis, more serious than the privacy point, not found by Gemini:**
after "Use this account", runs and sessions keep the same cloud id
(`_toSupabaseUuid(run.id)` in `cloud_sync_coordinator.dart`). In the database,
`routine_runs.id` and `routine_sessions.id` are primary keys across all users,
and row-level security only lets an account touch its own rows. If User A had
already backed those runs up, User B's upload of the same ids should be
rejected, leaving User B's backup failing and retrying. Routines and reminders
are not affected because their cloud ids are cleared. No local data would be
lost. This needs a test against the staging project to confirm.

The same reasoning applies if User A later signs back in on that device and
chooses "Use this account": routines would be uploaded again under new ids and
could appear twice after restore. Also a hypothesis.

## 6. Other corrections needed in PR #3 before it merges

- `docs/INDEPENDENT_LAUNCH_REVIEW.md` still says "50+ screenshots, 4 failures"
  and "Deno tests skipped". The handover in the same PR says 6 failures and
  65 Deno tests passed.
- It cites `lib/features/auth/ui/delete_account_confirm.dart`, which does not
  exist.
- The handover's proposed walkthrough fix should be replaced by a pointer to
  section 2 above.
- "Outdated checklists mention `verify-purchase`" is true but wider than
  stated: ten documents mention it, some as accurate history. Low priority.

Backend claims I spot-checked and found correct in source: migration 020
revokes the app's write access to the completion-email tables, and the limit of
10 invites per sender per day exists. The 65 Deno tests run against mocks and
say nothing about the live project.

## 7. Still blocked

Unchanged from Gemini's list, and these are the real launch gates: sandbox
purchase and restore on real devices, Apple and Google sign-in on real devices,
completion email delivery, and the live Supabase state (migrations, secrets,
scheduled jobs).

## 8. AI photo descriptions (PR #4)

Recommendation: keep it out of launch and treat the document as research only.

- **Privacy is the main issue, not cost.** Free users' photos never leave the
  phone today. A free allowance of any size means uploading photos of door
  locks and pill boxes to a third party from people who currently upload
  nothing. Pill-box photos can reveal health information. The privacy policy,
  the processor list and both store privacy forms would all change.
- **The design assumes the photo is already in the cloud** (it checks ownership
  of a `proofId` in the database). That is only true for Premium users with
  backup on, which is another reason to make it Premium-only if it is built.
- **Value is unproven.** The person has just taken the photo and can see it. A
  one-line description adds little unless it is for accessibility or search.
  It also sits awkwardly with Pebble's rule against feeding repeated checking.
- **Pricing options.** Option B (one free per day) creates a permanent cost and
  a permanent stream of uploads from Free users. Option A (five in total) is
  bounded. If there must be a free taste, A; my preference is Premium-only with
  consent asked each time. Ten per day for Premium is fine: Gemini's arithmetic
  is right and the cost is a fraction of a penny per user per month.
- **Model choice.** Only one model was assessed, and it is an old one. At these
  volumes price barely matters. Choose on accuracy, willingness to say "cannot
  tell", and data-handling terms, using the 50-photo test set the document
  already proposes, run across at least two current providers.
- **Spending controls.** The reserve-then-settle design, the server-side off
  switch and failing closed are sound. Missing: a per-user counter enforced in
  the same transaction, the day boundary for "daily", a hard monthly cap set at
  the provider as a backstop, and a check that a 50-token limit does not cut
  sentences short.
