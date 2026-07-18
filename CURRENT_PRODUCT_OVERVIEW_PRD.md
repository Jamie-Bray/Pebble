# Pebble Routines Current Product Overview

Last updated: May 11, 2026

This is the current product source of truth for Pebble Routines as it moves
toward Google Play testing. It describes what the app is now, not older roadmap
or exploratory assumptions.

## Product Shape

Pebble Routines is a local-first routine support app for everyday checks. Users
can create reusable routines, run them step by step, keep recent completion
history, and optionally add proof photos when a visual record helps.

Pebble should feel private and simple. Internally it has careful account,
subscription, history, proof-photo, and backup rules, but users should see one
clear current state and one obvious next action.

Pebble is not a medical, emergency, workplace safety, legal evidence, or
permanent archive service.

## Core Principles

- Works without an account.
- Local-first by default.
- No silent upload.
- No silent merge.
- No silent wipe.
- Explicit backup consent before supported routine data is uploaded.
- Pebble deletes only its own private app copies, never the user's camera roll
  or photo library.
- Account switching is privacy-critical and must stay guarded.
- User-facing copy should use simple words: backup, account, signed in, stored
  on this device, saved, paused, ready, recent history, review, keep local.

## Free Tier

Free users do not need to sign in.

Free includes:

- Local-only use.
- Up to 2 routines.
- Up to 10 steps per routine.
- Recent local history.
- Pebble-owned proof-photo copies retained for 48 hours.
- Two standard themes plus accessibility themes.

After 48 hours, expired free history runs and Pebble-owned proof-photo copies are
deleted from Pebble's private app storage. Pebble must not delete camera-roll or
photo-library originals.

## Premium

Premium is for longer recent history, cloud backup, and account recovery.

Premium cloud features require all three:

- Active paid subscription.
- Signed-in user.
- Explicit cloud backup consent.

Premium includes:

- Longer recent history.
- Cloud backup for supported routine data.
- Proof-photo backup while the retention window allows it.
- Account recovery for backed-up data.

Premium recent history and proof-photo backup use a rolling 21-day retention
window unless the user deletes data earlier.

Guidance audio files currently stay local. If audio backup is added later, the
app UI, privacy policy, Play Data safety form, and processor map must be updated
first.

## Subscription Expiry

Premium ending should not immediately destroy extended history.

Current lifecycle model:

- Active Premium: 21-day recent history/proof retention and cloud backup can run.
- Recently ended Premium: 7-day grace state, no new cloud uploads, extended
  history remains visible for now.
- After grace: revert to free behaviour and prune local history/proofs older
  than 48 hours.

Expiry and grace behaviour should stay explicit in code rather than hidden in a
generic free-tier cleanup path.

## Sign-In And Backup

Signing in is only needed for cloud backup and account recovery. Pebble should
not imply that an account is required for normal local use.

Backup starts only after:

- Premium is active.
- User is signed in.
- User turns backup on.
- Local data passes account-safety checks.

History and Account should use the same backup language:

- Stored on this device.
- Ready to turn on backup.
- Backup is on.
- Backing up now.
- Backup is paused.

"Backing up now" should only appear when a real sync/upload/restore job is
running.

## Sign-Out

Signing out pauses cloud backup and sync. It must not delete local data,
downgrade local state, or wipe device history by itself.

Signing back into the same account may resume backup, subject to Premium and
backup consent.

## Account Switching

If a different account signs in on the same device:

- Do not automatically upload existing local data to the new account.
- Do not automatically merge existing local data into the new account.
- Do not silently wipe local data.
- Keep existing local data local by default.
- Block backup until the user makes an explicit account-switch/local-data choice.

The app distinguishes:

- Local data with no cloud owner yet.
- Local data linked to the same signed-in account.
- Local data linked to a different signed-in account.

Unowned local data can be linked only after explicit user review. Different-owner
local data must stay blocked.

## Photo And History Behaviour

PhotoVault/history should not show broken proof-photo tiles as normal content.

Current expectations:

- Missing proof files are not shown as normal available proof tiles.
- Deleted runs delete associated local proof copies.
- Orphaned local proof files can be reconciled/deleted.
- Proof references with no valid local/cloud object are cleaned up or shown only
  in a deliberate removed/expired state.
- Deleted cloud-backed proofs should also delete the Supabase object where
  possible.

For current product feel, prefer removing unavailable proof tiles over filling
the UI with broken unavailable cards.

## Save To Photos

Manual export is not a Premium-only feature.

Current status:

- The product wording should be "Save a copy to Photos", not "Download".
- It is available to Free and Premium users while the proof photo is still
  retained, from the shared full-screen photo viewer (history, run detail,
  and the routine player all use it).
- Implemented with the least-permission platform APIs: Android 10+ and iOS
  save with no runtime permission prompt; only Android 9 and below ask, and
  only at the moment the user exports. Do not add broad photo/gallery/delete
  permissions for this feature.

## Permissions

Do not ask for every permission on first launch.

Use just-in-time explanations:

- Camera: when the user first takes a proof photo.
- Photos/media: when the user chooses or saves a proof photo.
- Notifications: when the user enables reminders.
- Microphone: only when voice guidance/audio notes are actually used.

Before each OS prompt, Pebble should explain in plain language why the
permission is needed.

## Cloud Cleanup

Cloud cleanup is required in addition to app-side cleanup.

Production Supabase has:

- Database migrations applied.
- Edge Functions deployed.
- `cleanup-proof-retention` scheduled daily at 02:00 UTC.
- Cleanup protected by `CLEANUP_PROOF_RETENTION_SECRET`.
- `request-account-deletion` deployed for public deletion requests.

Cleanup must remain idempotent. Running it twice should not corrupt data or fail
because a row or storage object is already gone.

## Public Website And Store Copy

The public website is `https://pebbleroutines.com`.

Play Console URLs:

- Privacy policy: `https://pebbleroutines.com/privacy`
- Account deletion: `https://pebbleroutines.com/delete-account`

The website must match the app before upload:

- Free local history/proof retention: 48 hours.
- Premium recent history/proof backup retention: 21 days.
- Pebble never deletes the user's camera roll or photo library.
- Pebble works without an account.
- Premium backup requires subscription, sign-in, and backup consent.

Whenever product lifecycle rules change, update app copy, web copy, Play Data
safety answers, and this overview together.

## Pending Before Google Play Testing

- Publish the latest `web/` files to `pebbleroutines.com`.
- Confirm public deletion form posts successfully from the hosted page.
- Configure Google Play products.
- Set purchase verification secrets for `verify-purchase`.
- Complete Play Console Data safety, privacy, account deletion, permissions, and
  content rating forms.
- Upload the production AAB to the chosen testing track.
- Run manual release smoke tests on the installed Play build.
