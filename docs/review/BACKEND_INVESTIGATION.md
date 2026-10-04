# Backend and Dependencies Investigation

This document evaluates the Supabase backend configuration, database migrations, and Edge Functions as they relate to launch readiness.

## 1. Backend Dependencies and Deployment

The mobile application relies heavily on the Supabase backend for authentication, cloud sync, media storage, subscription verification, and completion emails.

According to `supabase/DEPLOY_PLAN.md` and the SQL migration files (e.g., `020_completion_email_hardening.sql`), the backend has recently undergone significant architectural changes.

**Required Changes Identified:**
*   **Database Migrations:** Migrations 014, 017, 018, 019, and 020 must be applied to production. 020 is particularly critical as it revokes the app's direct write access to completion email status, moving that responsibility to the Edge Functions.
*   **Edge Functions:** 10 Edge Functions must be deployed with specific JWT verification settings (`verify_jwt = true` for internal app-facing functions like `send-routine-completion-alert`, `verify_jwt = false` for webhooks and public web endpoints).
*   **Secrets:** Functions rely on secrets such as `RESEND_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`, and `CLEANUP_PROOF_RETENTION_SECRET`.

**Deployed State Cannot Be Verified:**
Because this review is conducted without authorized access to the live Supabase dashboard or the production project ref, I cannot confirm whether the steps in `DEPLOY_PLAN.md` have been executed in production. 

## 2. Test Coverage and Execution

*   **Deno Test Results:** **Blocked.** I attempted to run the 65 Deno backend tests (`deno test --allow-env --allow-net=127.0.0.1` in `supabase/functions`). However, the `deno` CLI is not installed on this Windows environment. I am strictly prohibited from altering project dependencies or global machine configuration to install it. 
*   **Action for Claude:** Claude should run the Deno test suite locally using the command above to guarantee backend logic regressions have not occurred.

## 3. Tracing Function Flows

**Entitlement Verification:**
*   `revenuecat-webhook` and `revenuecat-sync-entitlement` handle Premium logic.
*   The webhook processes RevenueCat events, handling cross-account transfer logic gracefully without returning 409s to RevenueCat.
*   Local app checks `personalCloudEnabled` via `CloudAccessProvider`, which checks `SubscriptionAccountState`.

**Completion Email Consent & Flow:**
*   `_shared/shared_alert_policy.ts` implements strict rate limiting (10 emails per day).
*   Consent is handled by `shared-alert-accept`, `shared-alert-decline`, and `shared-alert-block` functions (web endpoints).
*   Migration 020 successfully hardens the `routine_shared_alert_contacts` table by revoking `UPDATE` and `DELETE` from the `authenticated` role, preventing a compromised client from spoofing consent.

**Account Deletion:**
*   `request-account-deletion` function cleanly triggers a backend-driven deletion flow.
*   The SQL schema relies on `ON DELETE CASCADE` for foreign keys.
*   **Unverified:** Whether deleting the auth user correctly triggers the cascade to delete all storage objects (media, voice prompts).

**Retention Cleanup:**
*   `cleanup-proof-retention` runs daily (via `pg_cron`) to delete old proof photos.
*   It now requires `CLEANUP_PROOF_RETENTION_SECRET` (matching a Vault secret) to prevent unauthorized triggering.

## 4. Source-Level Findings and Dashboard Checks Needed

**Confirmed Findings:**
*   Code architecture for completion emails correctly separates concerns. The client can only *request* an alert; the Edge Function verifies consent and rate limits before sending via Resend.
*   Migration 020 correctly locks down the database.

**Dashboard Checks Still Needed (Action for Jamie/Claude):**
1.  **Supabase Auth:** Verify Anonymous sign-ins are disabled in the dashboard (Auth -> Providers).
2.  **Supabase Edge Functions:** Verify the secrets (`RESEND_API_KEY`, `CLEANUP_PROOF_RETENTION_SECRET`, `REVENUECAT_WEBHOOK_SECRET`) are correctly populated.
3.  **Supabase pg_cron:** Verify that `cleanup-proof-retention-daily` and `prune-shared-alert-data-daily` jobs are active and succeeding in the database `cron.job_run_details` table.
4.  **Web Assets:** Ensure `web/delete-account.html` and the alert response pages are actually hosted at the URL defined by `SHARED_ALERT_PUBLIC_BASE_URL`.
