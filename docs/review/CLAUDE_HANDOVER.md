# Claude Engineering Handover

This document summarizes the independent launch readiness review for Claude to take over implementation and verification.

## 1. Important Confirmed Findings (Ordered by Impact)

1.  **Cross-Account Data Claiming (Product/Security Risk)**
    *   **Context:** `lib/features/sync/local_data_ownership_guard.dart` (lines ~138-197) and `lib/features/account_backup/ui/cloud_backup_screen.dart` (lines ~238).
    *   **Finding:** When User A signs out and User B signs in, the UI detects `differentOwner` local data and prompts User B. If User B selects "Use this account", the app executes `useCurrentAccountForLocalData()`. This function strips the `cloudId` and re-assigns the `ownerUserId` of *all* of User A's un-uploaded data to User B, queuing it for upload to User B's account. This exposes User A's data to User B.
    *   **Action:** Evaluate if a "Delete local data" option should be added to the account switch flow to protect privacy.
2.  **Walkthrough Test Harness Defect (CI / DX)**
    *   **Context:** `test/walkthrough/walkthrough_screens_test.dart` (lines 836, 1075, 1370).
    *   **Finding:** Six automated screenshot scenarios fail with `Bad state: No element`. The test harness attempts to `await env.tapText('Add')`, but the application UI has updated the photo capture buttons to say `Add photo` and `Add more` (`lib/features/routines/execution/ui/routine_player_screen.dart`).
    *   **Action:** Update the string literals in the test file to match the current UI copy.
3.  **Outdated Launch Checklists (Process)**
    *   **Context:** `LAUNCH_READINESS_AUDIT.md`, `GOOGLE_PLAY_RELEASE_CHECKLIST.md`.
    *   **Finding:** Historical documents still reference the deprecated `verify-purchase` flow, which could cause confusion during deployment.
    *   **Action:** Remove or update obsolete references.

## 2. Checks Completed and Actual Outcomes

*   **Flutter Analyze:** Executed `flutter analyze --no-fatal-infos`. Outcome: **0 issues found**.
*   **Flutter Unit & Widget Tests:** Executed `flutter test`. Outcome: **412 tests passed**, 1 golden test failed (platform rendering differences).
*   **Screenshot Walkthrough:** Executed `flutter test test/walkthrough/walkthrough_screens_test.dart` (with `WALKTHROUGH=1`). Outcome: Captured 114 screens successfully, **6 failures** (due to the `tapText` string mismatch).
*   **Android Debug Build:** Executed `flutter build apk --debug`. Outcome: **Built successfully** in ~1500s.
*   **Source Inspection:** Verified database schema, RLS, and Edge Function code against `DEPLOY_PLAN.md`.

## 3. Open Questions and Blocked Checks

*   **Real-Device Validations Blocked:** Sandbox purchases, silent restores, account token exchanges, and offline OS-level background syncs require physical test devices and Apple/Google developer accounts, which are unavailable.
*   **Live Dashboard Config Unverified:** Supabase Edge Function secrets, database migrations, pg_cron jobs, and App Store Connect/Google Play configurations remain unverified.

## 4. Proposed Fixes and Missing Tests

*   **Walkthrough Fix:** Change `env.tapText('Add')` to `env.tapText('Add photo')` (or `Add more`) in `walkthrough_screens_test.dart`.
*   **Cross-Account Test:** Implement a new test in `local_data_ownership_guard_test.dart` or `cloud_sync_coordinator_test.dart` to assert exactly what happens when User B claims User A's local data via `useCurrentAccountForLocalData()`, and what happens if User A subsequently logs back in (does data duplicate?).

## 5. What Claude Should Verify First

1.  **AI Photo Descriptions Proposal (PR #4):** Review the optional feature feasibility study in [PR #4](https://github.com/Jamie-Bray/Pebble/pull/4). 
    *   **Action for Claude:** Assess the usefulness, photo accuracy, conversion potential, margins, and server-enforced abuse controls *before* any implementation begins.
    *   **Pricing Options for Claude to Evaluate:** Review Option A (Introductory 5-analysis allowance) vs. Option B (1 free analysis daily) against the 10-analysis daily Premium tier. Does an introductory allowance successfully demonstrate value and drive conversion without selling "safety assurance"?
2.  **Cross-Account Claiming:** Confirm with Jamie if the "Use this account" destructive merge behavior on account switching is an intended product decision or a privacy bug that must be addressed before launch.
3.  **Apply Walkthrough Fix:** Apply the proposed string change to the test harness and re-run to ensure 100% screenshot coverage.
