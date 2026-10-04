# Independent Launch Readiness Review

**Reviewer:** Antigravity AI
**Date:** 4 October 2026
**Target Branch:** `review/launch-readiness` (based on commit `f5c3beb18b97a8046c2b4ca7ceb0021fc5386fe1`)

This review independently verifies the claims made in the recent audits (`LAUNCH_READINESS_AUDIT.md`, `SUBSCRIPTION_REVIEW.md`, `COMPLETION_EMAIL_REVIEW.md`, etc.) against the current app code and configuration.

## 1. Verified Fixes (Ready for Launch)

I checked the code for the critical blockers raised in earlier audits. I can confirm these are **fully resolved** and the code is safe:

*   **iOS Store Blockers:** 
    *   Sign in with Apple is properly implemented (`lib/features/auth/ui/sign_in_screen.dart:142`).
    *   The iOS bundle ID is now Apple-compliant (`com.vix.pebbleroutines`).
    *   Google Sign-In on iOS safely hides itself if the client ID isn't configured, allowing you to launch iOS without Google if preferred.
    *   iOS Notification permissions are correctly configured in `ios/Podfile` and `AppDelegate.swift`.
    *   Silent purchases restore is now safely restricted to Android only (`revenueCatAllowsSilentRestore` check), keeping iOS compliant with App Review guidelines.
*   **Data Safety & Reliability:**
    *   Voice prompts are now successfully backed up to the cloud (`lib/features/sync/cloud_sync_coordinator.dart` handles `SyncEntityType.guidanceAudio`).
    *   A malformed cloud record will no longer block an entire account restore. It is safely caught and skipped in `_mergeRecordSafely`.
    *   App startup exceptions (like notification init failures) are properly caught and will no longer freeze the splash screen (`_runStartupStep` in `main.dart`).

## 2. Material Findings

These are remaining items that need attention. None of them strictly block you from starting the Android closed test or uploading to Apple TestFlight today, but you should address them soon.

### A. Failing Automated Test (CI Red Cross)
*   **User Impact:** None directly. But it causes your automated code checks (GitHub Actions CI) to fail with a red cross on every update.
*   **Evidence:** Running `flutter test` fails on `test/features/theme/sandstone_theme_golden_test.dart` due to a 46px UI overflow in the test-only preview.
*   **Certainty:** 100%. Verified via CLI.
*   **Next Action:** Have a developer fix the overflow in the golden test so your CI runs "green" again.
*   **Blocks Launch?** No. Codemagic will still build the app even if GitHub shows a red cross, but it masks real future errors.

### B. Free User Data Loss on Android Reinstall
*   **User Impact:** Free Android users who never create an account will permanently lose all their routines and history if they reinstall the app or change phones.
*   **Evidence:** Android automatic backup is disabled (`android:allowBackup="false"`). I checked the onboarding screens (`lib/features/onboarding/ui/onboarding_screen.dart`), and there is currently no warning to the user about this.
*   **Certainty:** 100%.
*   **Next Action:** This is a product decision. If you keep this behavior, add a small warning in the onboarding or free-tier limits screen explaining that an account is required to keep data safe.
*   **Blocks Launch?** No, but it risks negative user reviews.

### C. Outdated Documentation
*   **User Impact:** Could cause confusion during future development.
*   **Evidence:** `GOOGLE_PLAY_RELEASE_CHECKLIST.md` and `RETROSPECTIVE_PRD_GOOGLE_PLAY_PREMIUM_READINESS.md` still reference the old, dead `verify-purchase` backend flow. 
*   **Certainty:** 100%.
*   **Next Action:** Delete references to `verify-purchase` in those files.
*   **Blocks Launch?** No.

---

## 3. Jamie's Launch Checklist

Here is your exact, ordered checklist to get Pebble into testers' hands and launched, avoiding the pitfalls found in the audit:

### Phase 1: Setup & Web (Do this now)
1. [ ] **Email Forwarding:** Set up `@pebbleroutines.com` forwarding for `support@` and `privacy@` to your personal Gmail.
2. [ ] **Legal Details:** Fill in the postal address and ICO registration in your legal documents.
3. [ ] **Publish Web Pages:** Publish the `web/` folder so `https://pebbleroutines.com/shared-alert/confirm/` is live. (Completion emails will break without this).
4. [ ] **Supabase Security:** 
    *   Turn off **anonymous sign-ins** in the Supabase Dashboard (Authentication → Providers).
    *   Confirm the `CLEANUP_PROOF_RETENTION_SECRET` exists in Edge Functions secrets.

### Phase 2: Backend Deployment
5. [ ] **Database & Functions:** Follow `supabase/DEPLOY_PLAN.md` exactly to deploy the backend fixes. Run Migration 020 **before** deploying the Edge Functions to close the security hole.

### Phase 3: Android Release
6. [ ] **Play Console:** Fill out the Google Play Store listings and Data Safety forms.
7. [ ] **Build:** Connect Codemagic, upload the `upload-keystore.jks`, and start the **Android - signed App Bundle** build.
8. [ ] **Test:** Upload the `.aab` to Play Console and start the 14-day closed test with 12 testers.

### Phase 4: iOS Release
9. [ ] **Apple Developer:** Join the program (£79/yr), register App ID `com.vix.pebbleroutines` (ensure "Sign in with Apple" is checked).
10. [ ] **RevenueCat & Auth:** Set up the iOS app in RevenueCat, and configure Apple Sign-In in Supabase. 
11. [ ] **Build:** Add the Apple App Store API key to Codemagic and run the **iOS - TestFlight** workflow.
12. [ ] **Test & Submit:** Test on a borrowed iPhone via TestFlight, then submit to App Review.
