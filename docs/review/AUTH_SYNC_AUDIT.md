# Sign-in, account switching and backup integrity audit

Date: 4 October 2026. Branch: `fix/auth-sync-integrity`.

Each finding is marked:

- **Demonstrated by test**: a test in this branch shows it.
- **Hypothesis from source**: read from the code, not run.
- **Intentional**: works as designed.
- **Blocked**: needs a real device or the live backend.

The tests use a stand-in for the server that follows two rules read from the
migrations: an id is unique across all accounts, and an account can only write
its own rows. It is a model of the server, not the server. Nothing in this
audit was run on a real device or written to a live backend.

## Summary

| # | Finding | Status | Outcome |
|---|---|---|---|
| 1 | Second account's history backup is refused after "Use this account" | Demonstrated by test (stand-in server); live rejection reasoned from live policies | Fixed |
| 2 | Photos stay under the first account after a takeover | Demonstrated by test | Fixed |
| 3 | Signed-in user looks signed out when the app starts offline | Demonstrated by test | Fixed |
| 4 | Failed restore leaves backup stuck on "preparing" | Demonstrated by test | Fixed |
| 5 | Next account inherits "last backed up" time after a sign-out | Demonstrated by test | Fixed |
| 6 | Routines double up when an account takes a device back | Demonstrated by test | Not fixed, needs a database change |
| 7 | Two devices can overwrite each other's routines in the backup | Id clash demonstrated by test; effects are hypothesis | Not fixed, needs an owner decision |
| 8 | Smaller points | Hypothesis from source | Not fixed |

## 1. The run and session id hypothesis: holds, fixed

**What was wrong.** When a second person chose "Use this account" on a device,
every completed routine (run) and in-progress record (session) kept the cloud
id the first account had already used. The server keys those ids across all
accounts and only lets an account write its own rows, so the second account's
upload was refused.

**Evidence.**

- Source: `lib/features/sync/cloud_sync_coordinator.dart` (`_syncRunItem`,
  `_syncSessionItem`) sent `_toSupabaseUuid(run.id)` and
  `_toSupabaseUuid(session.sessionId)`, the same value whoever owned the row.
  `LocalDataOwnershipGuard.useCurrentAccountForLocalData` cleared `cloudId`
  for routines and reminders only.
- Server: `supabase/migrations/001_personal_premium_profiles_and_data.sql:33`
  and `:44` make `id` the primary key across all accounts. A read-only query
  of the production policies in this session showed the update policy on
  `routine_runs` and `routine_sessions` is `auth.uid() = owner_user_id`,
  matching `014_rls_initplan_and_index.sql:82` and `:99`.
- The backend audit reasoned from the same live policies that a cross-account
  upsert of an existing run or session id is rejected (SQLSTATE 42501, HTTP
  403, the whole request rolls back). That was reasoned from the policies, not
  tested by writing.
- **Blocked:** nobody has run the rejection against a live server. Staging was
  unreachable (the project is inactive) and production is read-only.

**What the user would have seen** (Demonstrated by test against the stand-in
server, `when the server does reject a write`): "Back up now" fails with the
server-rejection message, backup status goes to error, the item stays queued
with a retry time, and nothing on the device is lost or changed. Automatic
retries stop after 20 attempts (`sync_outbox_repository.dart:70`, covered by
`sync_outbox_repository_test.dart`); "Back up now" starts them again. So it
never succeeded and never lost data.

**Fix** (Demonstrated by test, `a second account takes over the device`, in
`test/features/sync/account_switch_sync_integrity_test.dart`):

- `lib/features/sync/local_data_ownership_guard.dart`: each run taken over
  from another account gets a new id scoped to the new owner. The original id
  and owner are kept in the run's sync metadata. If the first account takes
  the device back, the run returns to its original id and updates that
  account's existing backup instead of adding a second copy.
- Sessions keep their local id, because it names the photo folder on disk, and
  get a separate cloud id in the existing `remoteSessionId` field.
  `cloud_sync_coordinator.dart` uploads under it. `cloud_restore_coordinator.dart`
  now matches a restored session by its own id, not the cloud row id.
- Safety: the change runs inside the existing database transaction. It never
  deletes a row. If the new id is already on the device the run is left as it
  was (test: `a moved run is never dropped when its new id is taken`). Data
  that never had an owner keeps its ids.
- Tests cover: backup succeeds for the second account; the first account's
  backup is untouched; nothing is doubled on the device after a restore; a
  later change to the same session reuses its cloud id; the first account
  coming back reuses its original backup.

**Left over.** If account B restores on a brand-new phone and account A later
takes over that phone, A's backup can end up with a second copy of the same
run. Hypothesis from source. It needs three hand-overs across two phones.

## 2. Photos stayed pointing at the first account: fixed

**Demonstrated by test** (`photos are uploaded again into the new account`).
After a takeover, photos the first account had backed up kept that account's
storage key. They were never uploaded for the new account, and the new account
cannot read the old key (`routine_session_proof_storage.dart:181`). On a new
phone those photos would have been missing. `cloud_sync_coordinator.dart`
(`_hasOwnBackup`) now treats a key under another account's folder as not
backed up and uploads the photo again. Voice prompts already worked this way.

Not checked on a device: a photo whose file is no longer on the phone cannot
be uploaded again and is marked failed.

## 3. Offline start showed a signed-in user as signed out: fixed

**Demonstrated by test** (`starting offline keeps a stored session signed in`,
`test/features/auth/auth_session_integrity_test.dart`). At launch the app
touched the user's profile on the server before marking them signed in
(`auth_state_provider.dart`, `_hydrateAuthSession`). With no connection that
call failed and the rest of the start-up was skipped, so the app treated a
valid session as signed out until the next launch. The profile touch is now
best-effort.

## 4. A failed restore left backup stuck on "preparing": fixed

**Demonstrated by test** (`a failed restore leaves a retryable error, not
"preparing"`). `_ensureCloudReady` set the status to "preparing", then ran the
restore. If the restore failed, seven callers swallowed the error (app resume in
`main.dart`, the backup screen, the account screen, the paywall) and nothing
reset the status until the app was restarted. It now records a retryable error
at the source, so every caller is covered.

## 5. The next account inherited "last backed up": fixed

**Demonstrated by test** (`sign-out does not hand backup times to the next
account`). Sign-out clears the stored user id, so the existing check for "a
different account signed in" (`subscription_provider.dart`,
`cacheAuthenticatedIdentity`) never fired after a sign-out, and account B saw
account A's last backup time. The times are now cleared whenever the user id
changes, including from signed out. Sign-out still keeps the time on screen
for the paused view. The existing test `different account clears the previous
backup bootstrap` still passes.

Sign-out otherwise leaves: Premium (a store purchase on the device, kept on
purpose), all routines and history on the device, and any queued backup
changes. **Intentional.** The next account is blocked from backup until it
chooses "Use this account" or "Keep backup off".

## 6. Routines double up when an account takes a device back: not fixed

**Demonstrated by test** (`KNOWN ISSUE ... routines double up`). Account A
backs up, B takes over, A takes it back: A's routines appear twice on the
device. The takeover clears each routine's cloud id, so the restore that
follows cannot match A's cloud copy to the routine on the device and adds it
as new. The cloud copy is not doubled when the routine was made on that
device.

Not fixed because a clean fix needs the routine to remember where it came
from, which means new columns in the on-device database. Recommended: add
origin columns to routines and reminders, as this branch does for runs inside
their existing metadata, and match on them in restore.

## 7. Two devices can overwrite each other's routines: not fixed

**Demonstrated by test** for the id clash (`two devices give different
routines the same cloud id`). The effects below are **Hypothesis from
source**.

A new routine's cloud id is built from the account and the routine's number
on the device (`_stableRemoteId`, `cloud_sync_coordinator.dart`). Numbers
start at 1 on every device. So two devices on one account can give different
routines the same cloud id, and the later upload replaces the earlier one in
the backup. A later restore on the first device could then replace its
routine with the other one. Reminders use the same scheme. The likely trigger
is a second phone or tablet where a routine is made before signing in
(onboarding makes one), or two devices both adding routines.

Not fixed because existing tests pin the current scheme
(`account_backup_state_test.dart:2267` and `:2903`), so it is a design choice
that needs an owner decision, and it should be tried on two real devices.
Options:

1. Give each new routine and reminder a random id, saved on the device before
   the first upload. Recommended. Small, and existing backed-up routines keep
   their ids.
2. Add a per-install id into the existing formula. Also small, but needs a
   new stored value.

## 8. Smaller points (Hypothesis from source, not fixed)

- **Taken-over history waits for an empty queue.** Runs moved by "Use this
  account" are only queued when nothing else is waiting
  (`_queueUnsyncedLocalBaseline`), so they may upload at the next app start
  or the next change, not straight away.
- **Sign-in fails if the profile touch fails.** In `_completeSignIn` a failed
  profile write reports "sign-in did not finish" although the server session
  exists. The next launch shows the user as signed in. Left strict on purpose
  until the owner decides.
- **Queued deletes can be lost across accounts.** If account A deletes a
  routine while offline and account B then backs up on the same device, B's
  backup sends A's delete, the server ignores it, and the item is cleared.
  A's backup keeps the routine.
- **Account deletion** removes the server account and signs out. Routines and
  history stay on the device, still marked with the deleted account, so the
  next account sees the "Use this account" choice. **Intentional**, but the
  owner may want a "remove this device's data" option later.
- **Sign-out or account switch during a backup.** A backup already running
  keeps the user id it started with. After sign-out its remaining uploads
  fail and are retried. Not tested.
- **Start-up order.** `_hydrateAuthSession` reads the plan without waiting for
  it to load from the device. If it reads too early, backup setup is skipped
  at launch and picked up on the next resume. Not tested.
- **Debug builds only.** In tests, start-up for a signed-in Premium user logs
  a provider cycle error when reading backup consent, and reports "Backup
  setup is not ready yet". Riverpod only checks this in debug builds, so
  release builds should be unaffected. Worth knowing when testing a debug
  build. **Blocked:** needs a release build on a device to confirm.
- **Takeover drops one session detail.** The takeover and link steps replace
  a session's sync metadata, dropping the id of the run it completed. Low
  risk.

## Checked and found sound

- **Backup needs account, server-verified Premium and consent.**
  `_ensureCloudReady` and `_syncInternal` both stop without all three. Covered
  by existing tests in `cloud_restore_coordinator_test.dart` and
  `account_backup_state_test.dart`.
- **Another account's data blocks backup until the user chooses.** Restore
  only runs after that check. Existing tests.
- **One bad record does not stop a restore** (`_mergeRecordSafely`,
  `parseRemoteRows`). Existing tests.
- **Nothing in this area deletes on-device routines or history** on sign-in,
  sign-out or account switch. History pruning for Free is separate and waits
  for the plan to load (`CloudSyncCoordinator.kick`).
- **The purchase, restore and sync call order** in
  `revenuecat_purchase_repository.dart` was not touched.

## Account-switch sheet wording (applied)

Was: "This device has Pebble data from another sign-in. Use *email* from now
on so backup can continue."

Now: "This device has routines, history and photos from another sign-in. If
you carry on, Pebble copies them into the backup for *email*. They stay on
this device too."

Footer now: "Nothing uploads until you choose. The other sign-in's backup
isn't changed."

The load-bearing strings in `local_data_ownership_guard.dart` were not
changed.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: all pass except the known local-only golden
  (`sandstone_theme_golden_test.dart`).
- Blocked: Google and Apple sign-in, session expiry and token refresh, and
  everything above marked as needing a device or live backend.
