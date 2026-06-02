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
- [ ] Complete `AUTH_RELEASE_CHECKLIST.md` against the target Supabase project.
- [ ] Configure `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` for the verification function. `GOOGLE_PLAY_PACKAGE_NAME` is set to `com.vix.pebble_routines`; Supabase platform secrets provide `SUPABASE_SERVICE_ROLE_KEY`.
- [x] Remove the pre-store entitlement bridge with `supabase/migrations/007_remove_pre_store_entitlement_bridge.sql`.
- [x] Use `https://pebbleroutines.com/delete-account` as the account deletion webpage and pass it via `PEBBLE_ACCOUNT_DELETION_URL`.
- [x] Deploy `supabase/functions/request-account-deletion` and confirm the public deletion function posts successfully.
- [x] Confirm the hosted public deletion form posts successfully from the final legal URL.

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
- [x] Add `build_production_aab.ps1` so production bundles are built from local env vars instead of committed secrets.
- [ ] Upload the release AAB to Play Console internal testing.

## 4. Store listing and compliance

- [x] Draft tailored privacy, terms, and account-deletion web pages in `web/`.
- [x] Publish the updated privacy policy at `https://pebbleroutines.com/privacy`.
- [ ] Confirm the legal publication details in `LEGAL_PUBLICATION_CHECKS.md`.
- [ ] Review `LEGAL_PROCESSOR_MAP.md` against the Play Data safety form before submission.
- [ ] Review `COPY_RISK_SCAN.md` against store listing, screenshots, onboarding, and paywall copy.
- [ ] Create and monitor the `privacy@pebbleroutines.app` and `support@pebbleroutines.app` inboxes, or update the pages with the final inboxes.
- [x] Add a clear in-app opt-in before cloud backup of sensitive user-added content goes live.
- [ ] Complete the Data safety form for account data, photos, audio, and diagnostics/logging if applicable.
- [x] Confirm the account deletion web link in Play Console matches the in-app deletion destination.
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
- [ ] Confirm email sign-in sends a numeric code, not a Supabase confirmation link.
- [ ] Trigger backup/restore flows.
- [ ] Delete account from the app and verify cloud data disappears.

## Current release stance

- Production builds now require `APP_ENV=production`, real Supabase values, and Google Play Billing entitlement. Local/dev Premium grant paths have been removed.
- Internal testing can use Google Play license testers against the production-safe build once Play products and `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` are configured.
