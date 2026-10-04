# Sign-in, account switching and backup integrity audit

Date: 4 October 2026. Branch: `fix/auth-sync-integrity`.

**Status: stopped early.** The session hit its usage limit part-way through.
The account-switch work below is done and tested. The wider audit (sign-out,
account deletion, session expiry, offline start, consent gating) was read but
not finished, and the full test suite was not run. See "Not done".

Each finding is marked:

- **Demonstrated by test**: a test in this branch shows it.
- **Hypothesis from source**: read from the code, not run.
- **Intentional**: works as designed.
- **Blocked**: needs a real device or the live backend.

The tests use a stand-in for the server that follows two rules read from the
migrations: an id is unique across all accounts, and an account can only write
its own rows. It is a model of the server, not the server.

## 1. The run and session id hypothesis: holds

**What was wrong.** When a second person chose "Use this account" on a device,
every completed routine (run) and in-progress record (session) kept the cloud
id the first account had already used. The server keys those ids across all
accounts and only lets an account write its own rows, so the second account's
upload was refused.

**Evidence.**

- Source: `lib/features/sync/cloud_sync_coordinator.dart` sent
  `_toSupabaseUuid(run.id)` and `_toSupabaseUuid(session.sessionId)`, the same
  value whoever owned the row. `LocalDataOwnershipGuard` cleared `cloudId` for
  routines and reminders only.
- Live policies (read-only query on production, this session): `routine_runs`
  and `routine_sessions` have an update policy with
  `auth.uid() = owner_user_id`, matching migration 014.
- The backend audit, run in parallel, confirmed against the live policies that
  a cross-account upsert of an existing run or session id is rejected:
  SQLSTATE 42501, HTTP 403, and the whole request rolls back.
- Not run by me against a live server. Staging was unreachable (inactive).

**What the user would have seen** (Demonstrated by test, against the stand-in
server: `when the server does reject a write`): backup reports "Supabase
rejected the backup write...", the backup status goes to error, the item stays
queued with a retry time, and nothing on the device is lost or changed.
Automatic retries stop after 20 attempts (`sync_outbox_repository.dart`, tested
in `sync_outbox_repository_test.dart`); pressing "Back up now" starts them
again. So it never succeeded and never lost data.

**Fixed** (Demonstrated by test, `a second account takes over the device`):

- `lib/features/sync/local_data_ownership_guard.dart`,
  `useCurrentAccountForLocalData`: each run taken over from another account
  gets a new id scoped to the new owner. The original id and owner are kept in
  the run's sync metadata, so if the first account takes the device back the
  run returns to its original id and updates that account's existing backup
  instead of adding a second copy. If the new id is somehow already on the
  device the run is left as it was; nothing is deleted or merged.
- Sessions keep their local id (it names the photo folder on disk) and get a
  separate cloud id, stored in the existing `remoteSessionId` field.
  `cloud_sync_coordinator.dart` uploads under it and
  `cloud_restore_coordinator.dart` now matches a restored session by its own
  id rather than the cloud row id.
- Tests cover: backup succeeds for the second account; the first account's
  backup is untouched; nothing is doubled on the device after a restore; a
  later change to the same session reuses its cloud id; the first account
  coming back reuses its original backup.

## 2. Photos stayed pointing at the first account: fixed

**Demonstrated by test** (`photos are uploaded again into the new account`).
After a takeover, photos already backed up by the first account kept that
account's storage key, so they were never uploaded for the new account, and
the new account cannot read the old key
(`routine_session_proof_storage.dart`, `_downloadProofBytes`). On a new phone
those photos would have been missing. `cloud_sync_coordinator.dart` now treats
a key under another account's folder as not backed up and uploads the photo
again. Voice prompts already worked this way.

Not checked on a device: a photo whose file is no longer on the phone cannot
be re-uploaded and will show as failed.

## 3. Routines double up when an account takes a device back: not fixed

**Demonstrated by test** (`KNOWN ISSUE ... routines double up`). Account A
backs up, B takes over, A takes it back: A's routines appear twice on the
device. Cause: the takeover clears each routine's cloud id, then the restore
that follows cannot match A's cloud copy to the local routine and adds it as
new. The cloud copy is not doubled when the routine was created on that
device.

Left because a clean fix needs the routine to remember where it came from,
which means a new column in the local database. Recommended: add
origin columns to routines and reminders, as now done for runs, then match on
them in restore.

## 4. Two devices can overwrite each other's routines in the backup: not fixed

**Demonstrated by test** for the id clash (`two devices give different
routines the same cloud id`); the knock-on effects are **Hypothesis from
source**. A new routine's cloud id is built from the account and the routine's
local number (`_stableRemoteId`, `cloud_sync_coordinator.dart`). Local numbers
start at 1 on every device, so two devices on one account can give different
routines the same cloud id, and the later upload replaces the earlier one in
the backup. A later restore on the first device could then replace its
routine with the other one. The same applies to reminders. The likely trigger
is a new phone where a routine is created (onboarding does this) before
signing in.

Left because existing tests pin the current id scheme
(`account_backup_state_test.dart`), so it is a deliberate design that needs an
owner decision. Recommended: give each new routine and reminder a random id,
saved on the device before the first upload.

## 5. Smaller points (Hypothesis from source)

- Taken-over runs are only queued for upload when the queue is otherwise
  empty (`_queueUnsyncedLocalBaseline`), so they may wait until the next app
  start or change. Existing behaviour.
- The takeover and link steps overwrite a session's sync metadata, dropping
  `completedRunId` (`local_data_ownership_guard.dart`). Low risk.
- After sign-out and sign-in as a different account, "last backed up" time may
  carry over: `signOutIdentity` clears the user id, so
  `cacheAuthenticatedIdentity` no longer sees a different previous account and
  does not clear `lastSyncAt` (`subscription_provider.dart`). Not tested.
- Backup is blocked by default when another account's data is on the device,
  and restore runs only after that check. **Intentional.**

## 6. Proposed wording for the account-switch sheet (not applied)

Current body (`cloud_backup_screen.dart`): "This device has Pebble data from
another sign-in. Use *email* from now on so backup can continue."

Proposed body: "This device has routines, history and photos from another
sign-in. If you continue, they are copied into the backup for *email* and stay
on this device."

Proposed footer: "Nothing is uploaded until you choose. The other sign-in's
backup is not changed."

## Not done

- Full `flutter test` was not run. Only `test/features/sync` and
  `test/features/account_backup` were run (80 tests, all passing).
  `flutter analyze` showed one lint in the new test file, fixed afterwards and
  not re-run.
- No audit conclusions for: Google, Apple and email sign-in, account deletion,
  session expiry and refresh, offline start, consent gating, malformed
  restore records, stuck "preparing" states.
- Nothing was tested on a real device or against a live backend.
