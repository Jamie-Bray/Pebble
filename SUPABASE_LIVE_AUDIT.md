# Supabase Live Audit

**Date:** 3 October 2026
**Projects audited:** `pebble-production` (ref `yncgjqbjjzbinqkpukug`, us-east-2), with a short look at `pebble-staging` (ref `lxvrvrrxdjbrjwsxzppl`)
**How:** read-only checks through the Supabase connector: project and org metadata, migrations, deployed edge functions and their source, security and performance advisors, database catalog queries (counts and metadata only), cron history, and logs.
**Changed in Supabase:** nothing. No user content was read. The report contains no secret values and no personal data.

## Which project is which

| Project | Ref | Status | Role |
|---|---|---|---|
| pebble-production | `yncgjqbjjzbinqkpukug` | Active, healthy | **Production.** `web/delete-account.html` posts to this project, and its functions handle RevenueCat traffic. |
| pebble-staging | `lxvrvrrxdjbrjwsxzppl` | **Paused (inactive)** | Staging. `lib/main.dart` blocks production builds from using it. |
| south-yarra-rentals | `ywdrofllyptbpwpanxhj` | Paused | Not part of Pebble. It is in the same org, so it counts toward the org's free-project limit. |

All three projects are in the org **"pebble routines"**, which is on the **Free plan**.

---

## Verdict

**The backend is well built, but not quite launch-ready.** The security model is sound. Row-level security (RLS) is on for every table, storage is private and scoped to each user, and Premium is controlled by the server. Five things need fixing first:

1. **The Free plan is a launch risk.** Free projects pause after about a week of low activity (staging already has), get no backups, and have caps a small launch could hit.
2. **Purchase syncing breaks when a buyer switches accounts.** Live logs show the RevenueCat webhook rejecting a purchase about 20 times with "already linked to another account", and two test accounts still marked Premium after their subscriptions ended.
3. **Some live functions are older than the repo, and some are newer.** The email-link functions (accept, decline, block) and the photo-cleanup job run older code than git, without the fixes in the repo. Two email-sending functions run newer code that isn't in git at all.
4. **Email sign-in for the public may not work** unless custom SMTP is set up. I couldn't see the auth settings to confirm.
5. **iOS sign-in isn't set up in Supabase.** Only Google and email identities exist. Apple sign-in has never been used.

---

## 🔴 Must fix before launch

### 1. Upgrade the org from Free to Pro (or accept the risks)
- **Evidence:** `get_organization` returns `plan: free`. Staging is already `INACTIVE` (paused). Production stayed awake only because of light test traffic and the daily cleanup job. The last real sign-in was 12 August 2026.
- **Why it matters:**
  - Free projects are paused after about 7 days of low activity. While paused, the app can't sign in, back up, restore, sync Premium, or delete accounts.
  - The Free plan has no daily backups.
  - Limits that matter here: 1 GB file storage for the whole project, about 5 GB egress per month, a 500 MB database and 50k monthly active users. The proof-photo quota trigger allows **1 GB per user**, so a single heavy Premium user could fill the project's entire Free storage.
- **Fix:** move the org to Pro before launch (about $25/month, which includes daily backups and no pausing). Then decide whether to keep or delete the two paused projects.
- **Where:** https://supabase.com/dashboard/org/pqyurqsaeviqomycbsrt/billing

### 2. The RevenueCat webhook fails after an account switch, and Premium status goes stale
- **Evidence (production, 12 Aug 2026):**
  - The test purchase flowed normally: `INITIAL_PURCHASE`, then a `TRANSFER` (the buyer signed into a different Pebble account), then `RENEWAL`, `CANCELLATION` and `EXPIRATION` events.
  - After the transfer, the webhook logged `purchase_claim_conflict` **24 times** and returned **HTTP 409 19 times** in one day. RevenueCat retries any response that isn't 2xx.
  - Database state now: one purchase is stored as two kinds of row. The webhook writes `product_id = personal_premium:yearly`. `revenuecat-sync-entitlement` writes `product_id = personal_premium` with a different `purchase_token_hash`.
  - The transfer handler expired only the `personal_premium` row. The old owner's `personal_premium:yearly` row stayed `active`, so every later event for the new owner collided with it.
  - **Both test accounts' `profiles.tier` still read `personalPremium`,** although every entitlement period ended on 12 Aug. The EXPIRATION events never got past the 409.
- **Root cause, in code:** `supabase/functions/revenuecat-webhook/index.ts`, `handleTransfer()`.
  - RevenueCat `TRANSFER` events carry no `product_id`, so `productId` falls back to `'personal_premium'`. The update `.eq('product_id', productId)` then misses the rows the webhook itself wrote (`personal_premium:yearly`).
  - Separately, the sync function (`activePersonalEntitlement()`) and the webhook (`mapRevenueCatEvent()`) store `product_id` and `purchase_token_hash` differently. So the "one active claim per purchase" index (migration 009) can't see that the two rows are the same purchase.
- **Impact:** cloud writes are still gated correctly. RLS uses `has_active_personal_entitlement()`, which checks `period_ends_at`. The risks are:
  - a user who switches accounts (Google ↔ email, or after reinstalling) may not get Premium through the webhook;
  - the old account may keep Premium until its period ends;
  - `profiles.tier` can't be trusted. **I could not confirm whether the app reads `profiles.tier`.**
- **Fix (developer):**
  - In `handleTransfer`, expire **all** active `personal_premium`-tier rows for the `transferred_from` users. Don't filter by `product_id`.
  - Store `product_id` and `purchase_token_hash` the same way in both functions (for example, always the full `product:baseplan` and the `original_transaction_id`).
  - Return 200 with a logged `conflict` status instead of 409, so RevenueCat doesn't retry in a loop.
  - Recompute `profiles.tier` on `EXPIRATION`, even when the claim check fails.
  - Then test: buy on account A, sign into account B, and let the subscription renew and expire.

### 3. The live email-link functions are older than the repo
Deployed code compared with the repo using `get_edge_function`:

| Function | Deployed | Repo vs live |
|---|---|---|
| `shared-alert-accept` | v13, 19 May | **Old.** A plain GET to the link accepts immediately. The repo version (commit `1f61457`, 2 Jun) shows a confirmation page on GET and acts only on POST. |
| `shared-alert-decline` | v13, 19 May | **Old,** same problem. |
| `shared-alert-block` | v13, 19 May | **Old,** same problem. Confirmed in the deployed source. |
| `cleanup-proof-retention` | v14, 19 May | **Old.** If `CLEANUP_PROOF_RETENTION_SECRET` is unset, the deployed version **runs for anyone who POSTs to it**. The repo version refuses. |
| `send-routine-completion-alert` | v14, 7 Jul | **Newer than git.** The live email template ("Here is the completion update you asked Pebble to send", subject "Routine completed · Pebble") is not in any git commit or branch. |
| `request-shared-alert-contact` | v14, 7 Jul | **Newer than git.** The invite email template differs ("What may be included" box). The request logic matches. |
| `revenuecat-webhook` | v12, 4 Jun | Matches the repo (spot-checked). |
| `revenuecat-sync-entitlement` | v9, 4 Jun | Matches the repo. |
| `delete-account` | v13, 19 May | Matches the repo. |
| `request-account-deletion` | v14, 19 May | Matches the repo. |
| `verify-purchase` | v16, 19 May | Still deployed. The app doesn't call it. Not compared. |

- **Why the email links matter:** corporate mail scanners (Outlook Safe Links, Defender, some antivirus) open every link in an email automatically. With the live code, a scanner can **accept** alerts for someone who never agreed, which is a consent problem, or **block** the sender permanently.
- **Fix (developer), in this order:**
  1. Copy the live `send-routine-completion-alert` and `request-shared-alert-contact` sources into the repo and commit them, so a redeploy doesn't roll back the new email designs.
  2. Deploy `shared-alert-accept`, `shared-alert-decline`, `shared-alert-block` and `cleanup-proof-retention` from the repo, keeping `--no-verify-jwt` as in `supabase/config.toml`.
  3. Confirm the `CLEANUP_PROOF_RETENTION_SECRET` secret exists. The cron job already sends a header taken from the Vault secret `cleanup-proof-retention-header`. If the function secret is missing, the new code will return 401 and cleanup will stop.

### 4. Email OTP for real users depends on custom SMTP (verify before launch)
- I can't read auth settings through the connector.
- Supabase's built-in email service only delivers to members of your Supabase org, and is rate-limited to a few emails an hour. If custom SMTP isn't set, **strangers who choose "Use email" won't get a code.**
- The 12 Aug log shows `POST /otp` then `POST /verify`, both 200. So the **numeric-code flow works** (it isn't a magic link). That test was probably your own address.
- **Fix:** see "Things only the owner can do", items 3–4.

### 5. iOS: the Apple provider and the iOS Google client ID
- `auth.identities` contains only `email` and `google`. Apple sign-in has never been used on production, and I can't see whether the provider is enabled.
- iOS also needs the iOS OAuth client ID added to the Google provider. This is also listed in `LAUNCH_READINESS_AUDIT.md`, iOS blockers 1 and 3.
- **Fix:** owner tasks, items 1–2.

---

## 🟠 Should fix

### 6. Migration history doesn't match the repo, and migration 014 was never applied

| Repo file | Production record | State |
|---|---|---|
| 001–011 | `001`…`011` | ✅ Match |
| `012_function_grant_hardening` | `20260610083720_function_grant_hardening` | Applied under a timestamp version |
| `013_restore_rls_helper_grants` | *(no record)* | **The effect is present.** `authenticated` has EXECUTE on both helpers, so cloud writes work. But it isn't recorded. |
| `014_rls_initplan_and_index` | *(no record)* | **Not applied.** Policies still use bare `auth.uid()` and `roles = {public}`, and index `idx_routine_reminders_routine_id` doesn't exist. |
| `015_proof_usage_soft_delete_without_entitlement` | `20260714194247_proof_usage_soft_delete_without_entitlement` | Applied under a timestamp version (the one policy it touches is correct) |

- **Effect:** `supabase db push` will refuse to run, or will try to reapply files, because the remote has versions the repo doesn't know.
- **Effect:** the advisors report 36 `auth_rls_initplan` warnings and 1 unindexed foreign key, all of which 014 fixes.
- **Fix (developer):**
  1. `supabase migration repair --status reverted 20260610083720 20260714194247`
  2. `supabase migration repair --status applied 012 013 015`
  3. Apply `014` (it's safe: it only changes roles and wraps `auth.uid()` in a select).
  4. Re-run the advisors.
- Advisor docs:
  - https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
  - https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

### 7. Anonymous sign-ins may be switched on
- `supabase/config.toml` has `enable_anonymous_sign_ins = true`, and the security advisor raises `auth_allow_anonymous_sign_ins` on every table.
- The app never calls `signInAnonymously`, and production has 0 anonymous users.
- If the setting is on, anyone holding the public anon key can create unlimited throwaway accounts that count toward the MAU limit and can call JWT-protected functions. The functions do check Premium, and the sync function rejects anonymous users.
- **Fix:** turn it off in the dashboard (owner task 5) and set `enable_anonymous_sign_ins = false` in `config.toml`.
- Advisor doc: https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins

### 8. The app keeps re-downloading proof photos that don't exist
- **Evidence:** on 4–5 Aug, `edge_logs` show 540 × HTTP 400 over about 5 hours: the same 5 `routine-proofs/users/<id>/…webp` objects requested 108 times each, about every 3 minutes.
- The requests carried on **after that account was deleted** through `delete-account`.
- **Cost:** wasted egress, which matters on the Free plan, and battery.
- **Fix (app code):** treat "object not found" as permanent. Mark the proof as missing and stop retrying. Also cancel the sync and image loops on sign-out or deletion.

### 9. Public account-deletion form: no spam protection and no alert to you
- `request-account-deletion` (`verify_jwt = false`, which is correct for a public form) accepts any POST.
- There's no rate limit or CAPTCHA, and nobody is told when a request arrives. The table currently has 0 rows.
- Google Play requires you to act on these requests.
- **Small bug:** `message.isEmpty` (line 67) is Dart syntax and is always `undefined` in JavaScript, so empty messages are stored as `''` instead of `null`.
- **Fix:**
  - add a per-IP rate limit using the stored `request_ip_hash`, or Cloudflare Turnstile;
  - send yourself an email or webhook when a request arrives;
  - change `message.isEmpty` to `message.length === 0`.
  - Until then, check the table regularly (owner task 8).

### 10. The storage bucket has no file-size or file-type limits
- `routine-proofs` is correctly private, but `file_size_limit` and `allowed_mime_types` are both `null`.
- The quota trigger only caps total bytes per user (1 GB) and uploads (500 per 30 days).
- **Fix:** set something like a 5 MB limit and `image/webp, image/jpeg, image/png`. The location is Storage → `routine-proofs` → Edit bucket.

---

## 🟡 Housekeeping

- **`verify-purchase` is still deployed and callable** (v16, JWT required). The app doesn't use it. Delete it (Edge Functions → verify-purchase → Delete) to shrink the attack surface, and remove `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` if that secret is set.
- **Test data in production:** 2 test users, 4 test Google Play entitlement rows, and both profiles stuck on Premium (see item 2). Clear or reset them before launch so dashboards and support start clean. The rows are dated 5 and 12 Aug.
- **The RLS helper functions can be called directly as RPCs.** Signed-in users can call `has_active_personal_entitlement(uuid)` and `has_personal_cloud_write_access(uuid)` with *any* user id, so they can learn whether another user is Premium if they know that user's UUID. The risk is low because UUIDs aren't guessable. A tidy fix is to have the function ignore its argument and use `auth.uid()`, or move it to a non-exposed schema.
  - Advisor doc: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- **`pg_net` is installed in the `public` schema.** Supabase recommends the `extensions` schema. It's low risk, but the cron job depends on it, so only move it with a tested migration.
  - Advisor doc: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
- **Multiple permissive policies** on `profiles` (`profiles_upsert_own` is `ALL` and overlaps `profiles_select_own`) and on `sync_tombstones`. This is a performance nit, not a security issue. Split `ALL` into insert, update and delete.
  - Advisor doc: https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies
- **Leftover table grants:** `anon` and `authenticated` still hold `TRUNCATE`, `TRIGGER` and `REFERENCES` on every public table. The API can't use these, but revoking them makes the grants match the intent of migration 008.
- **Leaked-password protection is off.** It doesn't matter much because Pebble doesn't use passwords. Turn it on if you upgrade to Pro (Authentication → Policies/Passwords).
  - Doc: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- **Six unused indexes** were flagged. Ignore this until there's real traffic.
- **Advisor noise you can ignore:**
  - `information_schema.routines` is a false positive caused by the name clash with `public.routines`.
  - `cron.job` and `cron.job_run_details` policies are managed by Supabase.
  - `account_deletion_requests` "RLS enabled, no policy" is intended: only the service role writes to it.
- **Staging is paused and out of date.** It has only the 5 shared-alert functions (deployed early May) and no RevenueCat, delete-account or cleanup functions. Its migrations couldn't be listed (connection timeout while paused). Either restore it and redeploy everything before the next test cycle, or retire it.
- **`supabase/config.toml` sets `otp_length = 8`.** The app's code field accepts any length, so this is fine. Make sure the email template says "8-digit code" if you keep it.
- **The cleanup README still calls the secret optional.** Update it to match the repo code, where the secret is required.

---

## ✅ What's solid

- **RLS is on for all 14 public tables.** Every user-facing policy checks `auth.uid() = owner_user_id` (or `id` / `sender_user_id`). Shared-alert invites are checked through the owning contact.
- **Cloud writes are double-gated.** Inserts and updates need an active entitlement **and** a current backup consent. The consent hash stored in the database (`447b6676…`) matches the hash the app computes, and the privacy and terms versions match (`2026-05-04`).
- **Users can't give themselves Premium.** The `guard_profile_tier_client_write` trigger forces `personalFree` on insert and blocks any client change to `tier`. Only the service role can change it.
- **One purchase can't be active on two accounts** for the same row format. The partial unique index from migration 009 is present.
- **Function hardening (migration 012) is live:**
  - trigger functions have no EXECUTE for API roles;
  - `anon` can't execute any public function;
  - every SECURITY DEFINER function has a pinned `search_path`;
  - the grants restored by 013 are present.
- **Storage:** `routine-proofs` is private. Read, write and delete are limited to `users/<your-uid>/…`. Uploads also need a matching, unexpired `proof_asset_usage` row and an active entitlement. Per-user quotas are enforced by trigger.
- **The `verify_jwt` settings are correct, and they match `config.toml`:**
  - `revenuecat-webhook` is `false` and checks `REVENUECAT_WEBHOOK_SECRET` by comparing hashes;
  - `revenuecat-sync-entitlement`, `delete-account`, `request-shared-alert-contact` and `send-routine-completion-alert` are `true`;
  - the public link and form functions and the cron function are `false`.
- **The secrets appear to be set.** No "not configured" 500s were seen:
  - the webhook returned 200 and 409, not 500;
  - sync-entitlement returned 200 (8 times on 12 Aug, 16 on 4–5 Aug);
  - `request-shared-alert-contact` returned 200 and 403;
  - `delete-account` returned 200.
- **Daily cleanup works.** `pg_cron` job `cleanup-proof-retention-daily` runs at 02:00 UTC. It has had 146 successful runs since 11 May; the last was today and returned HTTP 200. It reads its auth header from Vault rather than hard-coding it.
- **The email code flow works.** `POST /otp` was followed by `POST /verify` (a typed code, not a magic link), and the Site URL in use is `https://pebbleroutines.com`, not localhost.
- **The database is healthy:** Postgres 17, 13 MB, no errors in the Postgres logs, no development branches left lying around.

---

## Secrets each function needs

Set these under Edge Functions → Secrets. `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase automatically.

| Function | Secrets you must set | Seen working in logs? |
|---|---|---|
| `revenuecat-webhook` | `REVENUECAT_WEBHOOK_SECRET` (or legacy `REVENUECAT_WEBHOOK_AUTH`); optional `REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID` (defaults to `personal_premium`) | Yes (200/409) |
| `revenuecat-sync-entitlement` | `REVENUECAT_REST_API_KEY` (or `REVENUECAT_SECRET_API_KEY`); optional `REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID` | Yes (200) |
| `request-shared-alert-contact`, `send-routine-completion-alert` | `RESEND_API_KEY`, `SHARED_ALERT_FROM_EMAIL`, `SHARED_ALERT_PUBLIC_BASE_URL`; optional `SHARED_ALERT_REPLY_TO_EMAIL` | Contact endpoint yes. **No completion email was seen being sent.** |
| `cleanup-proof-retention` | `CLEANUP_PROOF_RETENTION_SECRET` (must match the Vault secret the cron job sends) | Runs (200). Can't tell whether the secret is set. |
| `delete-account`, `request-account-deletion`, `shared-alert-accept/decline/block` | none beyond the built-ins | `delete-account` 200 |
| `verify-purchase` (unused) | `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Delete it |

`SHARED_ALERT_PUBLIC_BASE_URL` must be the production functions URL (`https://yncgjqbjjzbinqkpukug.supabase.co/functions/v1`, or the `functions.supabase.co` form). Otherwise the accept, decline and block links in emails will point at staging or nowhere.

---

## Things only the owner can do

Production dashboard: https://supabase.com/dashboard/project/yncgjqbjjzbinqkpukug

1. **Apple sign-in (for iOS):** Authentication → Sign In / Providers → **Apple** → Enable.
   - **Client IDs:** your iOS bundle ID (the new one, without an underscore) plus your Services ID.
   - **Secret Key:** generate it from Apple Developer → Keys → Sign in with Apple key (.p8), with your Team ID and Key ID.
   - https://supabase.com/dashboard/project/yncgjqbjjzbinqkpukug/auth/providers
2. **Google for iOS:** same page → **Google** → add the new iOS OAuth client ID to **Client IDs**, comma-separated after the existing web client ID. Save.
3. **Custom SMTP:** Authentication → Emails → **SMTP Settings** → Enable custom SMTP.
   - Use Resend's SMTP (host `smtp.resend.com`, port 465, user `resend`, password = a Resend API key) or another provider.
   - Sender name: "Pebble". Sender address on your verified domain.
   - Then raise the email rate limit under Authentication → Rate Limits.
   - https://supabase.com/dashboard/project/yncgjqbjjzbinqkpukug/auth/smtp
4. **Email templates:** Authentication → Emails → **Templates.**
   - In both **Magic Link** and **Confirm signup**, make sure the body shows `{{ .Token }}` (the code) and doesn't rely on `{{ .ConfirmationURL }}`.
   - Send yourself a test to Gmail, Outlook and iCloud from a brand-new address that **isn't** a member of your Supabase org.
5. **Turn off anonymous sign-ins:** Authentication → Sign In / Providers → (User Signups section) **Allow anonymous sign-ins** → Off → Save.
6. **URL configuration:** Authentication → **URL Configuration.**
   - Site URL: `https://pebbleroutines.com`.
   - Redirect URLs must include `com.vix.pebble.routines://login-callback`.
   - https://supabase.com/dashboard/project/yncgjqbjjzbinqkpukug/auth/url-configuration
7. **Check that the secrets exist:** Edge Functions → **Secrets.** Check every name in the table above is listed, especially `CLEANUP_PROOF_RETENTION_SECRET`. You'll see names, not values.
   - https://supabase.com/dashboard/project/yncgjqbjjzbinqkpukug/functions/secrets
8. **Deletion requests:** Table Editor → `account_deletion_requests`. Check it weekly until notifications exist (item 9), and handle each request within the time your privacy policy promises.
9. **RevenueCat dashboard:**
   - Project → Integrations → **Webhooks:** the URL must be `https://yncgjqbjjzbinqkpukug.supabase.co/functions/v1/revenuecat-webhook`, and the Authorization header value must exactly match `REVENUECAT_WEBHOOK_SECRET`.
   - Project settings → **Restore behavior:** confirm which mode is chosen (default "Transfer to new App User ID"). It decides how often item 2 will happen.
10. **Plan:** org **pebble routines** → Billing → upgrade to **Pro.** While you're there, set the spend cap the way you want it.
    - https://supabase.com/dashboard/org/pqyurqsaeviqomycbsrt/billing

---

## What I couldn't check

- **Auth settings:** which providers are enabled (Apple, Google), templates, SMTP, OTP length and expiry, rate limits, the anonymous sign-in toggle, MFA. The connector has no auth-config endpoint. The conclusions above come from `auth.identities`, auth logs and `config.toml`.
- **Secret values, and whether each secret exists.** I inferred presence from function responses only. Whether `CLEANUP_PROOF_RETENTION_SECRET` is set can't be told from outside without calling the function, which I didn't do.
- **Whether shared-alert emails are actually delivered,** including Resend domain verification. No completion email was sent in the logs I sampled, and there are currently 0 contacts.
- **Whether the app shows Premium based on `profiles.tier`.** This decides how visible the stale tier from item 2 is. A read of the app code for this was blocked in this session.
- **A line-by-line diff of every function.** I compared the deployed source directly for 9 of the 11; `verify-purchase` and `shared-alert-decline` weren't fetched. `decline` was deployed at the same time and is the same age as `accept` and `block`, so it's almost certainly the old version too.
- **Staging internals.** The project is paused, and database calls timed out. Only its function list was readable.
- **Usage against quotas** (egress, MAU, storage). I could count only 0 stored objects and a 13 MB database.
- **Logs older than the windows I sampled:** 24-hour windows on 3 Oct, 4–5 Aug and 12 Aug. Traffic is very light, so these may not show every failure pattern.
- **RevenueCat, Google Play Console and Apple dashboards:** outside Supabase.
