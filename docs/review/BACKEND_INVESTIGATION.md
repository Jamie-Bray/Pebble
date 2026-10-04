# Backend and Dependencies Investigation

This document evaluates the Supabase backend configuration, database migrations, and Edge Functions as they relate to launch readiness.

## 1. Backend Dependencies and Deployment

The mobile application relies heavily on the Supabase backend for authentication, cloud sync, media storage, subscription verification, and completion emails.

According to `supabase/DEPLOY_PLAN.md` and the SQL migration files (e.g., `020_completion_email_hardening.sql`), the backend has recently undergone significant architectural changes.

**Required Changes Identified:**
*   **Database Migrations:** Migrations 014, 017, 018, 019, and 020 must be applied to production. 020 revokes the app's direct write access to completion email status, moving that responsibility to the Edge Functions.
*   **Edge Functions:** 10 Edge Functions must be deployed with specific JWT verification settings (`verify_jwt = true` for internal app-facing functions like `send-routine-completion-alert`, `verify_jwt = false` for webhooks and public web endpoints).
*   **Secrets:** Functions rely on secrets such as `RESEND_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, and `CLEANUP_PROOF_RETENTION_SECRET`.

**Deployed State Cannot Be Verified:**
Because this review is conducted without authorized access to the live Supabase dashboard or the production project ref, I cannot confirm whether the steps in `DEPLOY_PLAN.md` have been executed in production. 

## 2. Test Coverage and Execution

*   **Deno Test Results:** **Incomplete.** I did not run the 65 Deno backend tests in `supabase/functions` because `deno` was not installed, although temporary isolated installation was permitted. 
*   **Action for Claude:** Claude should install Deno and run `deno test --allow-env --allow-net=127.0.0.1` locally to guarantee backend logic regressions have not occurred.

## 3. Tracing Function Flows

**Entitlement Verification:**
*   `revenuecat-webhook` and `revenuecat-sync-entitlement` handle Premium logic.
*   The webhook processes RevenueCat events, handling cross-account transfer logic gracefully without returning 409s to RevenueCat.
*   Local app checks `personalCloudEnabled` via `CloudAccessProvider`, which checks `SubscriptionAccountState`.

**Completion Email Consent & Flow:**
*   `_shared/shared_alert_policy.ts` implements rate limiting (10 emails per day).
*   Consent is handled by `shared-alert-accept`, `shared-alert-decline`, and `shared-alert-block` functions (web endpoints).

**Account Deletion:**
*   `request-account-deletion` function triggers a backend-driven deletion flow.
*   The SQL schema relies on `ON DELETE CASCADE` for foreign keys.

**Retention Cleanup:**
*   `cleanup-proof-retention` runs daily (via `pg_cron`) to delete old proof photos.
*   It now requires `CLEANUP_PROOF_RETENTION_SECRET` (matching a Vault secret).

## 4. Source-Level Findings and Dashboard Checks Needed

**Confirmed Findings:**
*   Migration 020 revokes `UPDATE` and `DELETE` from the `authenticated` role on the `routine_shared_alert_contacts` table.

**Dashboard Checks Still Needed (Action for Jamie/Claude):**
1.  **Supabase Auth:** Verify Anonymous sign-ins are disabled in the dashboard (Auth -> Providers).
2.  **Supabase Edge Functions:** Verify the secrets (`RESEND_API_KEY`, `CLEANUP_PROOF_RETENTION_SECRET`, `REVENUECAT_WEBHOOK_SECRET`) are correctly populated.
3.  **Supabase pg_cron:** Verify that `cleanup-proof-retention-daily` and `prune-shared-alert-data-daily` jobs are active and succeeding in the database `cron.job_run_details` table.
4.  **Web Assets:** Ensure `web/delete-account.html` and the alert response pages are actually hosted at the URL defined by `SHARED_ALERT_PUBLIC_BASE_URL`.
