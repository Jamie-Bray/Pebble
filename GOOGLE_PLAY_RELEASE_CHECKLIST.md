# Google Play Release Checklist

This checklist turns the pre-launch audit into a concrete release plan for Pebble.

## 1. Launch gate blockers

- [x] Remove accidental debug signing from `release` builds.
- [x] Stop production builds from granting Premium through the local/dev purchase path.
- [x] Add an in-app account deletion action backed by a Supabase Edge Function.
- [x] Add an explicit in-app cloud-backup consent gate before paid backup uploads user content.
- [x] Add a web account-deletion request form backed by a Supabase Edge Function scaffold.
- [x] Wire real Google Play Billing purchase and restore flows in the Flutter client.
- [x] Connect the client purchase flow to `supabase/functions/verify-purchase`.
- [ ] Configure `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, and `SUPABASE_SERVICE_ROLE_KEY` for the verification function.
- [x] Remove the pre-store entitlement bridge with `supabase/migrations/007_remove_pre_store_entitlement_bridge.sql`.
- [x] Publish a working account deletion webpage and pass its URL via `PEBBLE_ACCOUNT_DELETION_URL`.
- [ ] Deploy `supabase/functions/request-account-deletion` and confirm the public deletion form posts successfully.

## 2. Android policy and permission hardening

- [x] Remove legacy `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` permissions.
- [x] Stop declaring `SCHEDULE_EXACT_ALARM` and use inexact reminder scheduling by default.
- [ ] Confirm camera, microphone, notifications, boot completed, vibrate, and wake lock are all declared in Play Console disclosures.
- [ ] Disclose photo/media library access because users can choose existing proof photos.
- [ ] Verify the app still captures camera photos and reminder notifications correctly on a release build after the permission changes.

## 3. Release signing and build pipeline

- [x] Add `android/key.properties.example` and require a real release keystore for `bundleRelease` / `assembleRelease`.
- [x] Create the upload keystore and copy values into `android/key.properties`.
- [x] Accept Android SDK licenses on the build machine with `flutter doctor --android-licenses`.
- [x] Re-run `flutter build appbundle --release` until it succeeds cleanly from Flutter, not just Gradle.
- [ ] Upload the release AAB to Play Console internal testing.

## 4. Store listing and compliance

- [x] Draft tailored privacy, terms, and account-deletion web pages in `web/`.
- [ ] Publish a privacy policy URL and link it in Play Console.
- [ ] Confirm the legal publication details in `LEGAL_PUBLICATION_CHECKS.md`.
- [ ] Review `LEGAL_PROCESSOR_MAP.md` against the Play Data safety form before submission.
- [ ] Review `COPY_RISK_SCAN.md` against store listing, screenshots, onboarding, and paywall copy.
- [ ] Create and monitor the `privacy@pebbleroutines.app` and `support@pebbleroutines.app` inboxes, or update the pages with the final inboxes.
- [x] Add a clear in-app opt-in before cloud backup of sensitive user-added content goes live.
- [ ] Complete the Data safety form for account data, photos, audio, and diagnostics/logging if applicable.
- [ ] Confirm the account deletion web link in Play Console matches the in-app deletion destination.
- [ ] Prepare screenshots, feature graphic, app icon, short description, full description, and content rating questionnaire.
- [ ] Complete Play App Signing enrollment and verify the upload certificate fingerprint.

## 5. App quality verification

- [x] `flutter test`
- [x] `flutter analyze` with zero blocking issues and an intentional decision on remaining infos.
- [ ] Manual release smoke test:
- [ ] Install the signed release build.
- [ ] Create/edit/run routines.
- [ ] Capture proof photos from camera and library.
- [ ] Record and play guidance audio.
- [ ] Sign in with supported providers.
- [ ] Trigger backup/restore flows.
- [ ] Delete account from the app and verify cloud data disappears.

## Current release stance

- Production builds now require `APP_ENV=production`, real Supabase values, and Google Play Billing entitlement. Local/dev Premium grant paths have been removed.
- Internal testing can use Google Play license testers against the production-safe build once the Play products and verification function credentials are configured.
