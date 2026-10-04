# Data Ownership and Recovery Investigation

This document traces local data ownership, cloud sync triggers, cross-account transitions, and data lifecycle events. 

## 1. Local Data Ownership Lifecycle

Local data (routines, runs, reminders, sessions) is stored in SQLite (`core/database/local_db.dart`) with an `ownerUserId` column.

*   **Signed-out use:** Data is created with `ownerUserId` as `null` (or empty string). This is unowned data.
*   **First sign-in (`auth_state_provider.dart:470`):** The `LocalDataOwnershipGuard` inspects local data. If it finds only `unownedOnly` data, and the user has Premium and grants Backup consent, it automatically calls `linkUnownedLocalData()`, which stamps all `null` rows with the newly `signedInUserId`.
*   **Sign-out:** Data remains in the local database with the old `ownerUserId`. Local database rows are *not* deleted on sign-out, allowing offline access and later recovery.
*   **Account Switching (`cloud_backup_screen.dart`):** If a *different* user signs in on the same device, the ownership guard detects `differentOwner` or `mixed`. Cloud sync is blocked. The user is presented with a "Link this device's data?" sheet:
    *   **"Keep backup off":** The new account stays entirely offline on this device.
    *   **"Use this account" (`useCurrentAccountForLocalData`):** This strips the `cloudId` and forces the `ownerUserId` of *all* rows to the new `signedInUserId`, marking them `pendingUpload`. This explicit transfer behavior is confirmed by tests in `test/features/sync/local_data_ownership_guard_test.dart` which asserts that `useCurrentAccountForLocalData` overwrites `ownerUserId` and sets state to `sameOwnerOnly`.

## 2. Recovery and Restores

*   **Premium Purchase & Uploads:** Triggered by `CloudAccessProvider.personalCloudEnabled`. Uploads require: an active account, server-verified Premium, and explicit `CloudBackupConsentStore.accepted`.
*   **Reinstall / New Device:** `revenuecat_purchase_repository.dart` attempts a silent restore on Android. Once an active purchase is restored (or explicitly restored), the `cloud_restore_coordinator.dart` kicks off a sync.
*   **Malformed Records:** Handled gracefully. Existing tests (`cloud_restore_coordinator_test.dart`) confirm `_mergeRecordSafely` logs and skips a bad remote session without halting the entire restore.

## 3. Expiry and Deletion

*   **Offline Startup with Old Expiry:** `revenuecat_purchase_repository.dart` considers an entitlement valid until its cached `period_end`, even offline. `test/data/repositories/routine_run_repository_test.dart` explicitly asserts `'a lapse inferred from an old cached period end deletes nothing'`.
*   **Confirmed Expiry:** When the server confirms the subscription has lapsed, the `premium_lapse_provider.dart` triggers. The local history is retained during a 7-day grace period. However, `test/data/repositories/routine_run_repository_test.dart` proves that `'a confirmed lapse keeps history for 7 days, then applies Free limits'`. Once the 7-day grace period passes, `enforceRetentionPolicy` deletes the expired local historical runs entirely. Cloud data retention depends on backend `cleanup-proof-retention` jobs.
*   **Account Deletion:** 
    *   **Local:** `lib/features/auth/ui/delete_account_confirm.dart` clears the local database on successful deletion.
    *   **Cloud:** `request-account-deletion` Edge Function calls a SQL cascade in Migration 020 to delete cloud rows. (See `BACKEND_INVESTIGATION.md`).

## 4. Gaps and Missing Tests

**Unverified Paths (Needs Device/Live Testing):**
*   **Privacy Concerns:** If User A signs out, and User B logs in and selects "Use this account", User B explicitly claims User A's un-uploaded data. This is confirmed behavior, but it remains an unverified privacy concern if left this way in production.
*   **Return-to-Original-Account:** The scenario where User A logs back in after User B claimed their local data is untested. What happens when User A tries to restore from the cloud? Does the data duplicate?
*   Actual restore speed and deduplication of media (audio clips) during a fresh reinstall.

**Proposed Missing Test (for Claude to implement):**
*   **Scenario:** Return-to-Original-Account after cross-account claiming.
*   **Action:**
    1. Seed local DB with User A's data (`cloudId` = A1).
    2. Run `useCurrentAccountForLocalData` for User B (which strips `cloudId` and assigns to B).
    3. Assert all data is now owned by B and `cloudId` is null.
    4. Assert what happens when User A logs back in and syncs. Expectation: The data should not duplicate destructively.
