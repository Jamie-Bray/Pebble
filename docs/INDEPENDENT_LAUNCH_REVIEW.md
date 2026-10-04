# Independent Launch Readiness Review (Updated)

**Reviewer:** Antigravity AI
**Date:** 4 October 2026
**Target Branch:** `review/launch-readiness` 
**Review Commit:** `f5c3beb18b97a8046c2b4ca7ceb0021fc5386fe1` (Matches `origin/main` `f5c3beb18b97a8046c2b4ca7ceb0021fc5386fe1`)

## 1. Verdict

This review confirms that the repository's code correctly implements the Apple App Store requirements (Sign In with Apple, bundle ID, iOS notifications) and includes safeguards for silent restores, malformed backups, and completion email rate limiting. 

However, **the app is not yet proven ready for launch**. Code inspection and unit tests establish that the application is *built* to handle these scenarios, but many critical integration points—including real purchasing, account recovery on physical devices, and backend live configuration—remain **unverified** because they require dashboard access and real-device testing environments that I do not possess. 

## 2. Corrections to the First Draft

*   **Golden Test CI Failure:** My first report claimed the golden test failure would break the GitHub CI on every push. **This was false.** The `.github/workflows/ci.yml` correctly uses `continue-on-error: true` for golden tests, so CI remains green. I re-ran the test locally, and it failed with a pixel mismatch (`0.41%, 11800px diff detected`), which is a visual diff, not a layout overflow exception.
*   **"Fully Resolved" Claims:** I previously claimed the iOS blockers were "fully resolved" based solely on reading the code. That conclusion was unsupported. While the *code* is present, resolution requires configuring the Apple developer portals, which remains unverified.
*   **Reinstall Warning:** I stated free users without an account would lose data on reinstall. While true, I implied an account prevents this. **This was inaccurate.** Data is only backed up if the user: 1) Creates an account, 2) Has an active, server-verified Premium entitlement, 3) Explicitly accepts cloud backup consent, and 4) Completes a successful sync upload (`cloud_access_provider.dart:154`). The onboarding still lacks a warning about this.
*   **Deployment Checklist:** I previously listed deployment steps based on historical markdown documents. I cannot verify the current live deployment state of the Supabase edge functions or migrations because I do not have dashboard credentials.

## 3. Scenario Coverage Table

| Scenario | Implementation / Files | Available Tests | Checks Performed | Outcome & Remaining Verification |
| :--- | :--- | :--- | :--- | :--- |
| **Authentication & Accounts** | | | | |
| Google sign-in (Android/iOS) | `supabase_client_provider.dart:58` | Mocked in `auth_state_test.dart` | Code inspection, `flutter analyze`, `flutter test` | Code conditionally renders button. **Unverified:** Real device OAuth redirect; Google Cloud Console config. |
| Apple sign-in | `sign_in_screen.dart:142`, `Runner.entitlements` | `auth_state_test.dart` | Code inspection | iOS-only button is in code. **Unverified:** App Store Connect config, real device token exchange. |
| Email sign-in | `auth_method_sheet.dart` | `email_otp_sheet_test.dart` | `flutter test` | UI and logic pass unit tests. **Unverified:** Receipt of real emails, deep-link return to app. |
| Sign-out & Switching | `auth_state_provider.dart` | `subscription_lifecycle_test.dart` | `flutter test`, code inspection | Data is isolated by `ownerUserId`. **Unverified:** Real-device test of switching accounts with offline data. |
| Account deletion | `request-account-deletion` Edge Function | Deno tests (in `supabase/functions/`) | Code inspection of SQL cascade | DB cascades clean up media/contacts. **Unverified:** Live function execution, actual storage bucket deletion. |
| **Purchases & Subscription** | | | | |
| Purchase & Cancellation | `revenuecat_purchase_repository.dart` | `subscription_lifecycle_test.dart` | Code inspection, `flutter test` | Flow logic passes unit tests. **Unverified:** Real sandbox purchases, store failure edge cases. |
| Explicit Restore | `revenuecat_purchase_repository.dart:212` | `subscription_lifecycle_test.dart` | Code inspection | Explicit restore present. Silent restore restricted to Android. **Unverified:** Real-device restore on iOS/Android. |
| Expiry & Grace Period | `subscription_lifecycle.dart` | `premium_lapse_test.dart` | `flutter test` | 7-day grace period logic passes tests. **Unverified:** Real-device test of subscription expiry. |
| Offline Startup | `revenuecat_purchase_repository.dart` | `routine_run_repository_test.dart` | Code inspection | Cached entitlement trusted until period ends. **Unverified:** Real-device offline startup test. |
| Reinstall with Purchase | `revenuecat_purchase_repository.dart` | N/A | Code inspection | Android attempts silent restore post-login. **Unverified:** Real-device reinstall and restore test. |
| **Backup & Recovery** | | | | |
| Backup Eligibility | `cloud_access_provider.dart:154` | `account_backup_state_test.dart` | Code inspection, `flutter test` | Backup requires login, verified Premium, and consent. **Unverified:** Live consent persistence. |
| Routines, Media, Voice | `cloud_sync_coordinator.dart` | `cloud_sync_coordinator_test.dart` | Code inspection | `SyncEntityType.guidanceAudio` included. **Unverified:** Real-device backup/restore of audio clips. |
| Malformed Records | `cloud_restore_coordinator.dart:478` | N/A | Code inspection | `_mergeRecordSafely` logs/skips bad records. **Missing Test:** Add a unit test in `cloud_restore_coordinator_test.dart` simulating a malformed JSON payload. |
| **Backend & Release Readiness** | | | | |
| Database Migrations | `supabase/migrations/` | Deno tests for policies | Inspected migration SQL | Migration 020 revokes app write access. **Unverified:** Live deployment state of Migration 020. |
| Edge Functions | `supabase/functions/` | 65 Deno tests | Inspected source code | Shared-alert functions are written. **Unverified:** Live deployment, secret configuration (`CLEANUP_PROOF_RETENTION_SECRET`). |
| Completion Emails | `_shared/shared_alert_policy.ts` | Deno tests | Code inspection | Rate limits (10/day) and consent required. **Unverified:** Live email delivery, web confirm pages. |
| iOS Config & Privacy | `ios/Runner.xcodeproj`, `PrivacyInfo.xcprivacy` | N/A | Code inspection | Bundle ID is `com.vix.pebbleroutines`. Privacy manifest exists. **Unverified:** Apple developer portal configuration. |

## 4. Confirmed Findings (Ordered by Severity)

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

3. **Golden Test Pixel Mismatch**
   * **What can go wrong:** Causes visual noise in CI logs (0.41% pixel mismatch).
   * **Evidence:** `flutter test test/features/theme/sandstone_theme_golden_test.dart` fails with `Pixel test failed, 0.41%, 11800px diff detected`.
   * **Certainty:** Confirmed by running tests locally.
   * **Next Action:** Have a developer investigate the UI differences causing the pixel mismatch and update the golden files.
   * **Blocks Launch?** No. `continue-on-error: true` is set in CI.

## 5. Verified External Requirements

*   **Google Play Closed Testing:** Google requires apps created by personal developers after Nov 13, 2023, to test with at least **20 testers** who are opted-in continuously for **14 days** before applying for production. *(Note: Your internal docs mention 12 testers, but Google's official policy for most accounts remains 20 testers. You should verify your specific account requirement in Play Console).* 
    *   *Source checked 4 Oct 2026:* [Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
*   **Apple Developer Program:** Enrollment requires an annual fee of **99 USD** (or local equivalent, approx. £79 GBP) and identity verification. 
    *   *Source checked 4 Oct 2026:* [Apple Developer Enrollment](https://developer.apple.com/programs/enroll/)
*   **Sign in with Apple:** Required by Apple App Store Review Guideline 4.8 if third-party sign-in (like Google) is offered. 
    *   *Source checked 4 Oct 2026:* [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple)

## 6. Jamie's Next Actions & Checklist

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
11. [ ] **Google Play:** Fill out store listings, Data Safety forms, and start the 14-day closed test with 20 testers (or 12 if explicitly allowed in your console).
12. [ ] **App Store:** Submit the TestFlight build to App Review.
