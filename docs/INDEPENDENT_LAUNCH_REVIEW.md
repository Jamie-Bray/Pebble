# Independent Launch Readiness Review (Updated)

**Reviewer:** Antigravity AI
**Date:** 4 October 2026
**Target Branch:** `review/launch-readiness` 
**Review Commit:** `f5c3beb18b97a8046c2b4ca7ceb0021fc5386fe1` (Matches `origin/main` `f5c3beb18b97a8046c2b4ca7ceb0021fc5386fe1`)

## 1. Verdict

This review checks the codebase for the Apple App Store requirements (Sign In with Apple, bundle ID, iOS notifications) and the previously requested safeguards for silent restores, malformed backups, and completion email rate limiting. 

While code inspection and unit tests show that the application is built to handle these scenarios, **the app is not yet proven ready for launch**. A passing automated test only establishes the exact behavior the test covers. Many critical integration points—including real purchasing, real account recovery on physical devices, and backend live configuration—remain **unverified** because they require dashboard access and real-device testing environments.

## 2. Corrections to the Previous Drafts

*   **Unsupported "Perfectly Handles" Claims:** My earlier drafts included blanket assurances that the code "perfectly handles" edge cases. I have removed these. A passing test proves the tested path, not perfection across all environments.
*   **Golden Test CI Failure:** I initially claimed the golden test failure would break the GitHub CI on every push. **This was false.** The `.github/workflows/ci.yml` correctly uses `continue-on-error: true` for golden tests, so CI remains green. Additionally, the pixel mismatch (0.41%) occurred when running on a Windows host, whereas CI uses `ubuntu-latest`. I do not recommend changing golden baselines until cross-platform rendering differences are evaluated.
*   **Reinstall Warning:** I stated free users without an account would lose data on reinstall, implying an account alone prevents this. **This was inaccurate.** Data is only backed up if the user: 1) Creates an account, 2) Has an active, server-verified Premium entitlement, 3) Explicitly accepts cloud backup consent, and 4) Completes a successful sync upload (`cloud_access_provider.dart:154`). The onboarding still lacks a warning about this.
*   **Google Play Testers:** I previously cited 20 testers for 14 days. After re-reading the [Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), the official requirement was indeed reduced on December 11, 2024. The actual requirement is **12 testers opted in continuously for 14 days**.
*   **Missing Tests:** I recommended adding a test for malformed records. **This was incorrect.** `test/features/sync/cloud_restore_coordinator_test.dart` already contains the case `'skips one malformed remote session and still restores the rest'`. I have corrected the coverage table.
*   **Phantom Test Files:** I cited `auth_state_test.dart` and `email_otp_sheet_test.dart`. These do not exist. I have updated the coverage table to cite the actual test files (`sign_in_screen_test.dart`, `email_otp_flow_test.dart`, etc.) and their specific assertions.

## 3. Execution Evidence

I ran the following checks locally on Windows using Flutter `3.44.6` and Dart `3.12.2`:
*   `flutter analyze --no-fatal-infos`: 0 issues found.
*   `flutter test`: 412 tests passed, 1 failed (the `sandstone_theme_golden_test.dart` pixel mismatch).
*   **Screenshot Walkthrough:** `flutter test test/walkthrough/walkthrough_screens_test.dart`. Captured 50+ screenshots successfully, but 4 tests failed with a `StateError: Bad state: No element` due to a UI element not being found during the automated flow.
*   **Android Debug Build:** `flutter build apk --debug`. Built successfully.
*   **Backend Deno Tests:** *Skipped.* The `deno` CLI is not installed on this Windows environment, so I could not execute the backend tests in `supabase/functions`.

## 4. Scenario Coverage Table

| Scenario | Implementation / Files | Specific Test Assertions / Checks Performed | Outcome & Remaining Verification |
| :--- | :--- | :--- | :--- |
| **Authentication & Accounts** | | | |
| Google sign-in (Android/iOS) | `supabase_client_provider.dart:58` | `sign_in_screen_test.dart`: Asserts `find.text('Continue with Google')` is hidden on iOS when `googleIosClientId` is empty. | Conditionally renders button. **Unverified:** Real device OAuth redirect; Google Cloud Console config. |
| Apple sign-in | `sign_in_screen.dart:142`, `Runner.entitlements` | `sign_in_screen_test.dart`: Asserts Apple button is present and positioned above Google button. | Apple button is iOS-only. **Unverified:** App Store Connect config, real device token exchange. |
| Email sign-in | `auth_method_sheet.dart` | `email_otp_flow_test.dart`: Asserts `'email OTP request reports failure without advancing state'`. | Logic passes unit tests. **Unverified:** Receipt of real emails, deep-link return to app. |
| Sign-out & Switching | `auth_state_provider.dart` | Code inspection of local db cleanup on sign-out. | Data is isolated by `ownerUserId`. **Unverified:** Real-device test of switching accounts with offline data. |
| Account deletion | `request-account-deletion` Edge Function | Inspected `supabase/migrations/` SQL cascades. | DB cascades clean up media/contacts. **Unverified:** Live function execution, storage bucket deletion. |
| **Purchases & Subscription** | | | |
| Purchase & Cancellation | `revenuecat_purchase_repository.dart` | `subscription_lifecycle_test.dart`: Asserts state changes during purchase flows. | Flow logic passes unit tests. **Unverified:** Real sandbox purchases, store failure edge cases. |
| Explicit Restore | `revenuecat_purchase_repository.dart:212` | Code inspection. | Explicit restore calls `Purchases.restorePurchases`. Silent restore restricted to Android. **Unverified:** Real-device restore. |
| Expiry & Grace Period | `subscription_lifecycle.dart` | `premium_lapse_test.dart`: Asserts `'a confirmed lapse keeps history for 7 days, then applies Free limits'`. | Grace period logic passes tests. **Unverified:** Real-device test of subscription expiry. |
| Offline Startup | `revenuecat_purchase_repository.dart` | `routine_run_repository_test.dart`: Asserts `'a lapse inferred from an old cached period end deletes nothing'`. | Cached entitlement trusted until period ends. **Unverified:** Real-device offline startup test. |
| Reinstall with Purchase | `revenuecat_purchase_repository.dart` | Code inspection. | Android calls `syncPurchasesSilently` post-login. **Unverified:** Real-device reinstall and restore test. |
| **Backup & Recovery** | | | |
| Backup Eligibility | `cloud_access_provider.dart:154` | Code inspection. | Cloud upload gated behind login, verified Premium, and explicit consent. **Unverified:** Live consent persistence. |
| Routines, Media, Voice | `cloud_sync_coordinator.dart` | Code inspection. | `SyncEntityType.guidanceAudio` included in sync loop. **Unverified:** Real-device backup/restore of audio clips. |
| Malformed Records | `cloud_restore_coordinator.dart:478` | `cloud_restore_coordinator_test.dart`: Asserts `'skips one malformed remote session and still restores the rest'`. | `_mergeRecordSafely` logs/skips bad records in tests. **Unverified:** Live cloud restore behavior on device. |
| **Backend & Release Readiness** | | | |
| Database Migrations | `supabase/migrations/` | Inspected `020_completion_email_hardening.sql`. | Migration 020 revokes app write access. **Unverified:** Live deployment state of Migration 020. |
| Edge Functions | `supabase/functions/` | Inspected TypeScript source code. | Shared-alert functions are written. **Unverified:** Live deployment, Deno test run, secret config. |
| Completion Emails | `_shared/shared_alert_policy.ts` | Inspected TypeScript source code. | Rate limits (10/day) and consent logic exist. **Unverified:** Live email delivery, web confirm pages. |
| iOS Config & Privacy | `ios/Runner.xcodeproj`, `PrivacyInfo.xcprivacy` | Code inspection. | Bundle ID is `com.vix.pebbleroutines`. Privacy manifest exists. **Unverified:** Apple developer portal configuration. |

## 5. Confirmed Findings (Ordered by Severity)

1. **Reinstall Data Loss (Product Risk)**
   * **What can go wrong:** Users who uninstall the app or change phones will permanently lose their routines and history unless they have fulfilled *all four* backup conditions: an account, a server-verified Premium entitlement, explicit backup consent, and a successful sync upload.
   * **Evidence:** `android:allowBackup="false"` prevents OS-level backups. `cloud_access_provider.dart:154` strictly gates cloud uploads. `lib/features/onboarding/ui/onboarding_screen.dart` contains no warning about this behavior.
   * **Certainty:** Confirmed in code.
   * **Next Action:** Add a clear notice to the onboarding flow or free-tier UI explaining these strict conditions for data safety.
   * **Blocks Launch?** No, but it risks negative user reviews.

2. **Outdated Documentation**
   * **What can go wrong:** Could cause confusion during future development or backend audits.
   * **Evidence:** `LAUNCH_READINESS_AUDIT.md` notes that `GOOGLE_PLAY_RELEASE_CHECKLIST.md` and `RETROSPECTIVE_PRD_GOOGLE_PLAY_PREMIUM_READINESS.md` still reference the deprecated `verify-purchase` backend flow.
   * **Certainty:** Confirmed via file inspection.
   * **Next Action:** Delete references to `verify-purchase` in those historical files.
   * **Blocks Launch?** No.

3. **Walkthrough Screenshot Test Failures**
   * **What can go wrong:** Automated screenshots for some home screen states cannot be captured.
   * **Evidence:** `flutter test test/walkthrough/walkthrough_screens_test.dart` failed on 4 tests (e.g., `home checked nordicNight iphone 1.0`) with a `StateError: Bad state: No element` when attempting to tap an element.
   * **Certainty:** Confirmed by running tests locally.
   * **Next Action:** Have a developer fix the finder elements in the walkthrough script.
   * **Blocks Launch?** No.

## 6. Verified External Requirements

*   **Google Play Closed Testing:** Google Play requires apps created by personal developers after Nov 13, 2023, to test with at least **12 testers** who are opted-in continuously for **14 days**. 
    *   *Source checked 4 Oct 2026:* [Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
*   **Apple Developer Program:** Enrollment requires an annual fee of **99 USD** (or local equivalent, approx. £79 GBP) and identity verification. 
    *   *Source checked 4 Oct 2026:* [Apple Developer Enrollment](https://developer.apple.com/programs/enroll/)
*   **Sign in with Apple:** Required by Apple App Store Review Guideline 4.8 if third-party sign-in (like Google) is offered. 
    *   *Source checked 4 Oct 2026:* [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple)

## 7. Jamie's Next Actions & Checklist

Because I cannot access your production dashboards, you must personally verify the following configurations before launch:

### Phase 1: Dashboard Prep & Backend Deployment
1. [ ] **Legal & Web:** Set up email forwarding. Fill in legal details. Publish the `web/` folder to `pebbleroutines.com` so the completion email confirmation links work.
2. [ ] **Supabase Security:** Manually verify in the Supabase Dashboard (Authentication → Providers) that anonymous sign-ins are turned off.
3. [ ] **Supabase Secrets:** Manually verify that `CLEANUP_PROOF_RETENTION_SECRET` exists in the Edge Functions secrets and matches the vault secret `cleanup-proof-retention-header`.
4. [ ] **Deploy Backend Fixes:** Verify Migration 020 (`020_completion_email_hardening.sql`) has been applied, and deploy the Edge Functions as ordered in `supabase/DEPLOY_PLAN.md`.

### Phase 2: iOS Setup
5. [ ] **Apple Developer:** Join the program, register App ID `com.vix.pebbleroutines` (ensure "Sign in with Apple" is checked).
6. [ ] **RevenueCat:** Add the App Store app in RevenueCat and retrieve the `appl_` key.
7. [ ] **Auth:** Configure Apple Sign-In and (optionally) Google iOS Client ID in Supabase.

### Phase 3: Cloud Builds & Real-Device Testing (Critical)
8. [ ] **Codemagic Config:** Add your Android `upload-keystore.jks` and Apple App Store API key to Codemagic. Set up the `pebble_production` environment variables.
9. [ ] **Build:** Trigger the **iOS - TestFlight** and **Android - signed App Bundle** workflows in Codemagic.
10. [ ] **Device Testing:** Use TestFlight (iOS) and Internal Testing (Android) on real devices to physically verify:
    *   Signing in via Apple, Google, and Email.
    *   Purchasing Premium (sandbox), restoring purchases, and ensuring backup uploads trigger successfully.
    *   Submitting a routine and receiving the completion email.

### Phase 4: Store Submission
11. [ ] **Google Play:** Fill out store listings, Data Safety forms, and start the 14-day closed test with 12 testers.
12. [ ] **App Store:** Submit the TestFlight build to App Review.
