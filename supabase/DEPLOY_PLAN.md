# Deploy plan: backend fixes (October 2026)

Target: `pebble-production` (`yncgjqbjjzbinqkpukug`). The website and Anthropic secret were updated on 5 October 2026; see the live preparation record below. Database migrations and Edge Functions were not deployed during that preparation.
The live `verify_jwt` settings below were read with `list_edge_functions` on 3 Oct 2026, and `supabase/config.toml` now lists every function explicitly to match them.

## What changed

| Function | Live now | Change on this branch | Deploy? |
|---|---|---|---|
| `send-routine-completion-alert` | v14 (7 Jul) | **Rewritten (completion email review, `COMPLETION_EMAIL_REVIEW.md`).** Names the sender, shows the sender's local time, new template with plain text + List-Unsubscribe one-click headers, per-contact cap (3/hour, 12/day), retry of a failed run (max 3 attempts) with a Resend Idempotency-Key, honours blocks and the global opt-out at send time, does not store a hidden routine name, errors redacted. Logic in `handler.ts`. | **Yes, after migration 020** |
| `request-shared-alert-contact` | v14 (7 Jul) | **Rewritten.** Strict address check; invite limits (10 invite emails/sender/day, 3 per address/sender/week, 5 per address/day across all senders, 20 active contacts, 30-day wait after a decline); superseded invites stop working; invite names the sender and has no sender-written text; PATCH can hide the routine name/steps; turning emails off and removing a contact no longer need Premium; provider errors never reach the app. Logic in `handler.ts`. | **Yes, after migration 020** |
| `revenuecat-webhook` | v12 (4 Jun) | TRANSFER moves claims by app-user id, not product id, and is idempotent. Conflicts no longer return 409. Uses the shared normalisation, recomputes `profiles.tier` for every affected user, and compares the secret in constant time. | **Yes** |
| `revenuecat-sync-entitlement` | v9 (4 Jun) | Uses the same (store, product_id, hash) as the webhook, releases stale claims held by other accounts, and recomputes the tier (also when RevenueCat reports nothing active). | **Yes, with the webhook** |
| `cleanup-proof-retention` | v14 (19 May), **runs for anyone if its secret is unset** | Fails closed (503) without the secret, compares it in constant time, and never touches `users/*/guidance_audio/*` objects or `entity_type = 'guidance_audio'` rows. | **Yes. Must ship before any app build that backs up voice prompts.** The live v14 would delete those clips after 21 days. |
| `request-account-deletion` | v14 (19 May) | Fixes the `message.isEmpty` bug. Adds size limits, a stricter email check and throttles: 1 request per email per 24 h, 5 per IP per hour, 100 per hour globally. | Yes |
| `shared-alert-accept/decline/block` | v13 (19 May), old GET-acts code | **Rewritten** (`_shared/shared_alert_links.ts`). The earlier repo version served its confirm page as HTML from the function, which hosted Supabase rewrites to `text/plain` (it would have shown raw HTML). Now GET only redirects to the static page `web/shared-alert/confirm/` (token in the URL fragment, never logged); POST acts and redirects to a fixed result page; RFC 8058 one-click POST supported. Allow only works with an unexpired invitation sent to the contact's current address. | **Yes, after migration 020 and after the web pages are live** |
| `_shared/shared_alert_*.ts` | n/a | New shared code: policy (limits, validation, tokens, time), email templates, store, runtime (env, auth, Resend mailer). Bundled into each function. `shared_alert_fake_store.ts` is test-only. | Deployed with the functions |
| `web/shared-alert/confirm/` and result pages | (website) | New confirm page; result pages reworded (the blocked page wrongly said the sender is not told). | **Yes, publish before the link functions** |
| `delete-account`, `verify-purchase` | v13, v16 | Unchanged | No (consider deleting `verify-purchase`) |

`_shared/` (`revenuecat.ts`, `entitlements_db.ts`, `secrets.ts`) is imported relatively, and `supabase functions deploy` bundles it into each function automatically. It has no remote imports.

## Order

1. **Migration 016** (service_role grant). **Done on production 3 Oct 2026:** the `GRANT` was run directly with `execute_sql`, and `has_function_privilege` now returns true. It is not yet recorded in `supabase_migrations`; the history repair below should mark 016 as applied rather than re-run it (re-running is harmless). Roll back with `revoke execute on function public.has_active_personal_entitlement(uuid) from service_role;`. It fixes completion emails and contact invites immediately, with no function deploy. See `MIGRATION_REPAIR_PLAN.md` for the history repair that `db push` needs first.
2. **Confirm `CLEANUP_PROOF_RETENTION_SECRET` exists** (Dashboard → Edge Functions → Secrets). Its value must equal the Vault secret `cleanup-proof-retention-header` (present since 10 May) that cron job `cleanup-proof-retention-daily` sends as `x-cleanup-secret`. If it is missing, set it from the Vault value *before* deploying, or the nightly cleanup will start returning 503.
3. **Completion emails** (can go in the same window, in this order):
   1. Publish `web/` so `https://pebbleroutines.com/shared-alert/confirm/` is live. Open `…/confirm/#action=accept&token=xxxxxxxxxxxxxxxxxxxxxxxx` and check the page shows "Allow completion emails?".
   2. Apply migration **020** (`020_completion_email_hardening.sql`). It is additive and the live functions keep working. It revokes the app's direct write access to the four `shared_alert_*` tables (the critical fix: today a Premium user can mark their own contact as accepted through the REST API and email anyone), adds token purpose/recipient columns, decline cooldowns, the global opt-out table, the retry counter and the daily `prune-shared-alert-data-daily` cron job (02:40 UTC).
      If the migration-history repair is not ready, 020 can be run on its own with `execute_sql`; it does not depend on 014–019.
   3. Optional secrets (defaults shown): `SHARED_ALERT_PAGES_BASE_URL` (`https://pebbleroutines.com/shared-alert`), `SHARED_ALERT_PRIVACY_URL` (`https://pebbleroutines.com/privacy.html`), `SHARED_ALERT_POSTAL_ADDRESS` (footer line, unset = none). Set `SHARED_ALERT_FROM_EMAIL` to the display-name form `Pebble Routines <alerts@your-domain>`.
   4. Deploy the five shared-alert functions (commands below).
4. Deploy the functions:
   ```bash
   supabase link --project-ref yncgjqbjjzbinqkpukug
   supabase functions deploy revenuecat-webhook          --no-verify-jwt
   supabase functions deploy revenuecat-sync-entitlement             # verify_jwt = true
   supabase functions deploy cleanup-proof-retention     --no-verify-jwt
   supabase functions deploy request-account-deletion    --no-verify-jwt
   supabase functions deploy shared-alert-accept         --no-verify-jwt
   supabase functions deploy shared-alert-decline        --no-verify-jwt
   supabase functions deploy shared-alert-block          --no-verify-jwt
   supabase functions deploy request-shared-alert-contact            # verify_jwt = true
   supabase functions deploy send-routine-completion-alert           # verify_jwt = true
   ```
   Do **not** pass `--no-verify-jwt` for the sync or shared-contact functions. Live `verify_jwt` is `true` for `revenuecat-sync-entitlement`, `request-shared-alert-contact`, `send-routine-completion-alert`, `delete-account` and `verify-purchase`, and `false` for the rest.
5. Repair history and push 014, 017, 018, 019, and record 020 as applied if it was run by hand (`MIGRATION_REPAIR_PLAN.md`). 019 should go after the voice-prompt build's upload content type is confirmed as `audio/wav` or `audio/x-wav`.
6. Smoke checks:
   - Completion emails, with two inboxes you own (A = sender account, B = contact): invite B from the app; the email names A and has List-Unsubscribe headers (Gmail: "Show original"). Open Allow → confirm page → Allow → "Completion emails allowed". Complete the routine; the app shows "Completion email sent to B" and the email shows your local time. Use Gmail's Unsubscribe; the app then shows "They declined". Re-invite B: refused for 30 days.
   - `select public.prune_shared_alert_data();` returns counts; the cron job `prune-shared-alert-data-daily` exists.
   - Check the next `cleanup-proof-retention-daily` run (02:00 UTC) in `cron.job_run_details` / `net._http_response`. Expect HTTP 200 with `skippedGuidanceAudio` in the body. A 503 means the secret is missing.
   - RevenueCat dashboard → Webhooks → "Send test event". Expect 200.
   - In the app, buy on account A, sign into account B, then restore. B should get Premium and A should drop to Free, with no `purchase_claim_conflict` 409s in the logs.
   - Submit `web/delete-account.html` twice with the same email. Both get 200, and only one row is stored.

## Secrets each changed function needs

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected by Supabase.

| Function | Secrets |
|---|---|
| `revenuecat-webhook` | `REVENUECAT_WEBHOOK_SECRET` (or legacy `REVENUECAT_WEBHOOK_AUTH`). It must match the Authorization header set in RevenueCat; a `Bearer ` prefix is optional on either side. Optional: `REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID` (default `personal_premium`). |
| `revenuecat-sync-entitlement` | `REVENUECAT_REST_API_KEY` (or `REVENUECAT_SECRET_API_KEY`). Optional: `REVENUECAT_PERSONAL_PREMIUM_ENTITLEMENT_ID`. |
| `cleanup-proof-retention` | `CLEANUP_PROOF_RETENTION_SECRET`, now **required** (same value as the Vault secret `cleanup-proof-retention-header`). |
| `request-account-deletion` | none |
| `request-shared-alert-contact`, `send-routine-completion-alert` | `RESEND_API_KEY`, `SHARED_ALERT_FROM_EMAIL` (use `Pebble Routines <alerts@domain>`), `SHARED_ALERT_PUBLIC_BASE_URL` (functions base, used for the one-click unsubscribe URL). Optional: `SHARED_ALERT_REPLY_TO_EMAIL`, `SHARED_ALERT_PAGES_BASE_URL`, `SHARED_ALERT_PRIVACY_URL`, `SHARED_ALERT_POSTAL_ADDRESS`. |
| `shared-alert-accept/decline/block` | none beyond the built-ins. Optional: `SHARED_ALERT_PAGES_BASE_URL`. |

## Behaviour notes for reviewers

- **Purchase key.** Both functions now store `product_id` as `<subscription>:<basePlan>` (for example `personal_premium:yearly`) and `purchase_token_hash = sha256(original order id)`. Google Play renewal suffixes (`..N`) are stripped. When no transaction id is available, a stable per-user key is used instead of the RevenueCat event id, and the sync function reuses the webhook's row for the same product.
  - Existing webhook rows keep their key.
  - Old sync rows (`personal_premium`) stay as they are. They are harmless because their periods have ended.
  - **Assumption to confirm with a real purchase:** the REST v1 `subscriptions[...].store_transaction_id` for Google Play is `<original order id>..N`. If it isn't, the sync falls back to the per-user key. That still works, but the cross-account check then relies on the webhook alone.
- **Conflicts.** When another account holds the same purchase as active:
  - a newer RevenueCat event, or a sync (RevenueCat confirmed server-to-server), expires that claim and recomputes that account's tier;
  - an event older than the other claim's last write (a stale retry) gets 200 `conflict_stale_event` and changes nothing;
  - nothing returns 409 to RevenueCat any more.
- **TRANSFER.** Moves every active premium claim of the `transferred_from` users to the first existing `transferred_to` user, keeping the period end. Lapsed claims are only expired. Re-delivery is a no-op.
- **Tier.** `profiles.tier` is recomputed from entitlement rows by the functions, and by the database once 017 is applied (trigger plus daily reconcile). The app and RLS never read it.
- **Copy.** "Trusted contacts" no longer appears anywhere under `supabase/functions` (`COPY_GUIDELINES.md` → Completion Emails).
- **config.toml:**
  - `enable_anonymous_sign_ins = false`;
  - the magic-link and confirmation templates print `{{ .Token }}` (8-digit code);
  - this only affects the hosted project through `supabase config push`. Turn anonymous sign-ins off in the dashboard (Authentication → Sign In / Providers). Compare the hosted email templates before any `config push`, because a push overwrites them.

## Rollback

Live sources before this branch:

| Function | Roll back to |
|---|---|
| `send-routine-completion-alert`, `request-shared-alert-contact` | commit `440ecdc` (byte-for-byte live v14 capture; `request-shared-alert-contact` differs only in the 403 text after `4101a3c`). Migration 020 can stay: the old code ignores the new columns. **Do not** roll back 020's revokes. |
| `shared-alert-accept/decline/block` | Do not restore live v13 (it acts on GET). If the new version misbehaves, keep it deployed and fix forward; the old repo version showed raw HTML on hosted Supabase. |
| `revenuecat-webhook` (v12), `revenuecat-sync-entitlement` (v9), `request-account-deletion` (v14) | commit `1c2116c` (matched live per the audit) |
| `cleanup-proof-retention` (v14) | commit `1c2116c` is *stricter* than live v14 (live runs without a secret). Do not restore the live behaviour. Roll back to `1c2116c`. Note that `1c2116c` does not skip guidance audio. |

Roll back with, for example:

```bash
git checkout 1c2116c -- supabase/functions/revenuecat-webhook
supabase functions deploy revenuecat-webhook --no-verify-jwt
git checkout HEAD -- supabase/functions/revenuecat-webhook
```

Migration rollback SQL is in `MIGRATION_REPAIR_PLAN.md`.

## Tests

`supabase/functions/**/index_test.ts`, `_shared/revenuecat_test.ts` and the completion-email tests `_shared/shared_alert_policy_test.ts` + `_shared/shared_alert_flow_test.ts` (in-memory store, whole invite → accept → send → stop/block flow): 65 Deno tests, all passing. In this sandbox they were run with an import map that swaps `deno.land/std` for a local stub and `esm.sh/@supabase/supabase-js` for `npm:@supabase/supabase-js@2`, because deno.land is blocked here.

```bash
cd supabase/functions && deno test --allow-env --allow-net=127.0.0.1
```

## Proposed (backend live audit, 4 Oct 2026; not yet agreed or done)

Added by the read-only audit in `docs/review/BACKEND_LIVE_AUDIT.md`. Nothing here has been run. The sections above are unchanged.

- **Proposed correction to the record.** Section 1 of migration 020 (the `revoke` statements on the four `shared_alert_*` tables) is already in effect on production. The Postgres log shows it run on 3 Oct 2026 at 10:08 UTC, and the grants confirm it. Sections 2 to 6 are not applied. Line 3 above ("Nothing on this branch has been deployed") and Order step 3.2 should be updated by whoever made that change. Running the whole of 020 is still correct: every statement is safe to repeat.
- **Proposed step 0, before Order step 3:** the confirm page is not published. `https://pebbleroutines.com/shared-alert/confirm/` returned 404 on 4 Oct. Do not deploy the three link functions until it returns 200.
- **Proposed order within Order step 4:** deploy `cleanup-proof-retention` first, on its own, once the secret is confirmed. It is the only function whose live version destroys data (voice prompts after 21 days).
- **Proposed addition to Order step 5:** record both 016 and 020 as applied (`supabase migration repair --status applied 016 020 --linked`) after 020 has been run in full.
- **Proposed smoke check for Order step 6:** `select jobname, schedule, active from cron.job;` should list three jobs: `cleanup-proof-retention-daily`, `reconcile-profile-tiers-daily`, `prune-shared-alert-data-daily`. Today only the first exists.
- **Proposed test before launch:** one real billing-retry (grace period) case, to confirm the webhook keeps Premium on while the store is retrying payment. See risk 6 in the audit.

## Policy dates for the 21-day history window (8 Oct 2026; step 1 done)

**Why.** Every plan now keeps 21 days of history on the phone and Free shows the last 48 hours, so `web/privacy.html` and `web/terms.html` changed and their date is now 8 October 2026. The app records that date with each backup consent, and `public.has_current_cloud_backup_consent` checks it.

**Proposed step.** Apply `supabase/migrations/024_history_window_policy_dates.sql` (staging first, then production). It accepts consents recorded under either the 5 October or the 8 October pages, so build 38 and earlier keep backing up, and the new build works too. Same consent sentence and hash as 022. The consent hash test checks this file.

**Order.**
1. Apply 024. Safe at any time: old builds are unaffected.
2. Publish the updated `web/privacy.html` and `web/terms.html`.
3. Release the app build with this change. Before step 1, the new build's consents would be refused by the database and backup would not upload (nothing is lost).

**Smoke check.** Same as 022 below, and the consent row should show `privacy_version = '2026-10-08'`.

**Roll back** by re-running `022_voice_tip_backup_consent_text.sql`, only together with rolling back the app build.

Live record, 8 Oct 2026 (Claude): Jamie approved applying 024 in the project thread. Before: the live function matched 022. Applied the 024 SQL with `execute_sql` in one transaction and recorded version `024` (`history_window_policy_dates`) in `supabase_migrations.schema_migrations`, so history still matches `001`–`024`. Checked afterwards: the one active consent (recorded under the 5 Oct pages) still passes the gate; grants unchanged (`EXECUTE` for `postgres` only, as before). Steps 2 and 3 (publish the pages, release the build) are still to do.

## Proposed (backup consent text, 5 Oct 2026; not yet agreed or done)

Added with the legal accuracy pass (branch `fix/legal-accuracy`). Nothing here has been run. The matching migration is prepared as 022_voice_tip_backup_consent_text.sql. The sections above are unchanged.

**Why.** Voice tip recordings are uploaded when backup is on, but the sentence people agree to did not mention them. The app's consent sentence now does, and the recorded policy versions are now the dates on the published privacy and terms pages. The database decides whether an account may write backup data in `public.has_current_cloud_backup_consent`, which has the old sentence's hash and the old policy dates written into it (migration 011). Until that function is updated, it does not recognise a consent given in the new app.

**Proposed step: update the consent gate.** The SQL below is saved as `supabase/migrations/022_voice_tip_backup_consent_text.sql` (021 is used by AI descriptions). After approval, apply it to staging first, then production. The consent hash test checks the migration file.

```sql
-- Keep the database write-access gate aligned with the in-app cloud-backup
-- consent text, which now names voice tip recordings, and with the privacy
-- and terms dates recorded with each consent.

create or replace function public.has_current_cloud_backup_consent(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cloud_backup_consents c
    where c.owner_user_id = user_id
      and c.feature = 'personal_cloud_backup'
      and c.feature_enabled = true
      and c.withdrawn_at is null
      and c.privacy_version = '2026-10-05'
      and c.terms_version = '2026-10-05'
      and c.consent_text_hash =
        '19e2a2c7f63deef9320b02fe2e5950245a1ff4c08259af5551f0a76058d27e4f'
  );
$$;
```

`create or replace` keeps the function's existing grants (012, 013), so nothing else changes. The three values must equal `cloudBackupConsentPrivacyVersion`, `cloudBackupConsentTermsVersion` and the SHA-256 of `cloudBackupConsentText` in `lib/features/subscription/providers/cloud_backup_consent_provider.dart`. The test named above fails if they differ from this section.

**Order, and what happens if it is wrong.**

- Apply this **before any build that contains the new consent sentence reaches a phone** (any build made from `integration/launch-pass` after this branch is merged).
- New build, old database: the user turns on backup, the consent row is saved, and the database then refuses every backup write. Nothing is uploaded and nothing is lost, but backup does not work.
- New database, old build (34 or earlier): the old build's uploads are refused in the same way until the phone is updated.
- Once both are in place, every account that agreed to the old sentence is asked again the next time the new build checks its backup setting. Only test accounts exist today.
- Any later change to the consent sentence, or to the dates in `web/privacy.html` or `web/terms.html` that the app records, needs this function updated again in the same release.

**Smoke check.** On a test account with Premium and the new build: turn on backup, then run `select public.has_current_cloud_backup_consent('<that account id>');` as the service role. Expect `true`, and `app_version` in `cloud_backup_consents` should show the real build (for example `1.0.0+35`), not `1.0.0+1`. Record a voice tip, wait for backup, and check an object appears under `users/<account id>/guidance_audio/`.

**Roll back** by re-running `supabase/migrations/011_align_cloud_backup_consent_hash.sql`. Only do that together with rolling back the app build.

## Proposed (AI photo descriptions, 5 Oct 2026; not yet agreed or done)

Prepared during the Claude-to-Codex handover. **No live changes made.**
Implementation and outstanding real-device checks: `docs/AI_PHOTO_STEPS.md`.

1. Finish the earlier backend repair steps above. In staging, apply
   `021_ai_photo_descriptions.sql`, `022_voice_tip_backup_consent_text.sql`,
   then `023_ai_photo_monthly_allowance.sql`.
   022 must precede release of the app with the changed backup wording.
2. Configure `ANTHROPIC_API_KEY` in function secrets, with
   `AI_PHOTO_ENABLED=false`. Never put the key in Flutter build arguments.
   023 fixes the account allowance at 200 attempts/UTC calendar month across
   phones; apply it before deploying the new allowance-reader action. The
   existing four-argument reserve RPC remains compatible with older workers.
   Defaults are also 20 requests/account/day and 5,000 reservations/month globally;
   optional secrets are `AI_PHOTO_DAILY_LIMIT` and
   `AI_PHOTO_MONTHLY_REQUEST_BUDGET`.
3. Deploy `describe-proof-photo` and the updated
   `send-routine-completion-alert`. Preserve JWT verification in config.toml.
   With AI off, confirm feature discovery reports disabled and ordinary
   completion emails continue working.
4. In staging only, enable AI and test Premium/consent refusals, withdrawal,
   image rejection, repeated photo IDs, concurrent requests at the allowance
   boundary (including two requests for the 100th monthly place), own-account
   allowance reads and month rollover, real descriptions and optional email inclusion. Check the app's
   new backup consent produces a true database gate and working uploads.
5. Publish the privacy/terms changes and align store disclosures. Complete the
   real-photo and real-phone checks in `docs/AI_PHOTO_STEPS.md`.
6. After approval of this production step, apply the migrations and deploy the
   functions with AI still disabled; verify ordinary flows, then enable AI.
   Record dates, deployed versions and results here. No blanket migration push:
   the existing production migration history needs the repairs above first.

**Stop switch:** set `AI_PHOTO_ENABLED=false` or set the singleton
`ai_photo_settings.paused` row to `true`. Requests already sent to Anthropic may
finish. Existing descriptions remain in history. Withdrawal still works while
AI is disabled. Keep migration 023 during worker rollback so the monthly cap
still applies; older workers show a generic budget message for that refusal.
Keep the additive tables during rollback; do not delete history
or roll back the backup-consent gate independently of the app.

## Email redesign, 7 to 8 Oct 2026 (Jamie approved the live steps on 8 Oct)

New look for the invitation, completion and sign-in code emails, and the
completion email now lists each step with the time it was checked (only when
the contact's "Show each step" switch is on; step names are never stored).
No database change.

1. Deploy `send-routine-completion-alert` and `request-shared-alert-contact`
   (both use `_shared/shared_alert_email.ts`). Older app builds don't send
   steps, so their emails just show the step count, as before.
2. Paste `supabase/templates/email_code.html` into Authentication > Emails in
   the dashboard for both "Magic link" and "Confirm signup" (subject "Your
   Pebble sign-in code"). Hosted projects don't read `config.toml`.
3. Publish `web/privacy.html` (completion emails paragraph only; the date is
   unchanged on purpose, because backup consent checks the exact policy date).

Live record, 8 Oct 2026 (Claude):

- **Live change:** deployed `send-routine-completion-alert`, now version 20,
  and `request-shared-alert-contact`, now version 18, from `main` (PR #31).
  Both were fetched back and every file matches `main`.
- Versions 18 and 19 of `send-routine-completion-alert` were live for about 15
  minutes with a deploy-tool escaping fault: the title clean-up stripped
  backslashes and the characters u, 0, 2, 8 and 9 from routine and step names. Version 20 fixed it. No
  completion email was sent in that window (`shared_alert_events` had no rows).
  When deploying through the Supabase MCP tool, write a `\uXXXX` escape in the
  source as `\u005cuXXXX` in the tool's JSON, then fetch the function back and
  diff it against git.
- **Live change (Codex, 8 Oct):** pasted `supabase/templates/email_code.html`
  from `main` into both the Magic link or OTP and Confirm sign up templates in
  the production Supabase dashboard. Both subjects are "Your Pebble sign-in
  code". Reopening each template showed the new design and `{{ .Token }}` in
  the preview. No `supabase config push` was run.
- **Live change (Codex, 8 Oct):** uploaded all 24 files in `web/` from `main`
  at `d03401b` to the existing Cloudflare static-assets Worker
  `pebbleroutines-site`. Production version `dfc60136` serves the new `/r/`
  sharing page; a live sample link rendered its name and two steps. The
  `.well-known` files still contain signing placeholders, so verified Android
  App Links and iOS Universal Links remain pending the store signing IDs.
- **Live change (Codex, 8 Oct):** after PR #35 merged, uploaded all 24 files in
  `web/` from `main` at `75bd42a` to the same Worker. Production version
  `36055461` places "Open in Pebble" ahead of the steps. Reloading a live
  sample link confirmed the new layout, app link, and step preview.
- Existing custom SMTP was already enabled in Supabase with
  `smtp.resend.com` on port 465 and a stored password when checked on 8 Oct.
  A sign-in code sent to an external Proton Mail address arrived, and
  `auth/v1/verify` accepted the code (HTTP 200, session issued). No SMTP
  credential was changed during this check.

## Live preparation record — 5 October 2026 (Codex)

Jamie asked Codex to carry out the owner setup tasks in Claude's pasted launch
instructions. The following preparation is complete, with the current app
source from merged PR #21 (`origin/main` at `3538694`, build 35):

- Supabase CLI login completed under Jamie's account and the checkout linked
  to production `yncgjqbjjzbinqkpukug`. `projects list` returned production
  `ACTIVE_HEALTHY`; `migration list --linked` successfully read the database.
- **Live change:** set `ANTHROPIC_API_KEY` on production from the existing
  ignored local `.env.local` key. Verified the server-reported digest against
  the local key; the value was not printed or committed. The temporary upload
  file was removed. No other Supabase secret, AI switch, migration, database
  history record or Edge Function was changed by Codex during this preparation.
- **Live change:** manually published all 20 files from the current `web/`
  folder to the existing Cloudflare Worker **`pebbleroutines-site`**. This is
  a static-assets Worker, not a Pages project. The existing route is
  `pebbleroutines.com/*`; its alternate address is
  `https://pebbleroutines-site.jamiebray23.workers.dev`. New version prefix
  **`4aeb8d39`**; previous version prefix **`316adc16`** remains in deployment
  history. No DNS, route, paid plan or build integration was changed.
- Website checks: `/shared-alert/confirm/`, `/privacy.html` and `/terms.html`
  all returned HTTP 200 and their expected current wording. The confirm page
  displayed **Allow completion emails?** with the dummy fragment from this
  plan; no invitation was accepted and no email was sent. Privacy has the AI
  section, and terms describe the current 200-attempt allowance from PR #21.

Local signing preparation: copied `upload-keystore.jks` and `key.properties`
from the owner's mounted Google Drive backup into `android/`, normalised only
the local `storeFile` path to `upload-keystore.jks`, verified the keystore
matches the backup and opens with the copied store password. Both files are
ignored; no signing passwords or keys enter Git. Production build settings
passed the existing script's dry run. No signed AAB was built in this step.

Current local app checks: `flutter analyze` clean; 479 CI-equivalent non-golden
tests passed. The latest GitHub checks on build 35 were prevented from starting
by the account's billing/spending limit, rather than failing in analysis or
compilation. The known Windows golden difference remains separate. Incidental
local Flutter changes to the lockfile/generated platform files were restored.

**Next:** Claude can now perform the approved backend deployment and build 35
using the ordered plan above. Repair the migration history deliberately before
any blanket `db push`: the read still showed `001`–`011` and timestamp versions
`20260610083720`, `20260714194247`. This preparation did not change the database
or supersede the audit of already-applied grants/revokes. Confirm cleanup-secret
and migration prerequisites, deploy the data-protecting cleanup first, verify
ordinary flows, then test and enable AI as in the owner's approved plan.
Record each actual deployment separately; these prerequisites do not mean
the AI feature or the signed app is ready/live.

Handoff details: `docs/CLAUDE_LAUNCH_PREREQUISITES_2026-10-05.md`. Private
verification logs and website screenshot are under ignored
`artifacts/phone-build/`.

## Live deployment record — 5 October 2026 (Claude)

Owner approval: Jamie approved "update live now" for this plan in chat on
5 October 2026. Target `pebble-production` (`yncgjqbjjzbinqkpukug`), Supabase
CLI 2.119.0, functions bundled with `--use-api` from `main` at `3538694`
(build 35). Two accounts existed, both test accounts.

**Migration history (records only, no SQL run).** Marked the two timestamp
versions `20260610083720` and `20260714194247` as reverted, then recorded
`012`, `013`, `015` and `016` as applied, as `MIGRATION_REPAIR_PLAN.md` describes.

**Migrations applied** with `supabase db push --linked --include-all`, in this
order: `014`, `017`, `018`, `019`, `020`, `021`, `022`, `023`. Local and remote
history now match for `001`–`023`.

Checked afterwards with read-only SQL:
- cron jobs `cleanup-proof-retention-daily`, `reconcile-profile-tiers-daily`
  and `prune-shared-alert-data-daily` exist and are active;
- `get_ai_photo_allowance` returns limit 200 and is not executable by
  `authenticated`; `service_role` can execute the entitlement helper;
- `routine-proofs` bucket: 5 MB, webp/jpeg/png/wav;
- the SHA-256 of Vault secret `cleanup-proof-retention-header` equals the
  digest of function secret `CLEANUP_PROOF_RETENTION_SECRET`;
- one public policy still has `roles = {public}`; not investigated.

**Functions deployed**, `cleanup-proof-retention` first: `cleanup-proof-retention`
v16, `shared-alert-accept` / `-decline` / `-block` v15,
`request-shared-alert-contact` v16, `send-routine-completion-alert` v16,
`revenuecat-webhook` v14, `revenuecat-sync-entitlement` v11,
`request-account-deletion` v16, `describe-proof-photo` v1 (new). `verify_jwt`
matches `config.toml` for each. `delete-account` and `verify-purchase` unchanged.

Smoke checks, no real data sent: the accept link redirects (303) to the
published confirm page; cleanup and the RevenueCat webhook return 401 without
their secrets; `describe-proof-photo` reported `{"enabled":false}` before the
switch and refuses a caller who is not signed in (401).

**AI enabled.** Set function secret `AI_PHOTO_ENABLED=true`; discovery now
reports `{"enabled":true}`. `ai_photo_settings.paused` is `false`.
`ANTHROPIC_API_KEY` was already set (Codex record above).

**Not done, still owed.** No signed-in test of any flow: no real AI description,
purchase, restore, backup upload, completion email or cron run has been
observed since this deployment. Staging was skipped (it is paused), so plan
step 4's staged tests, including concurrent allowance requests, were not run.
The Anthropic key was printed into a local agent session log by a CLI parse
error on `.env.local`; rotate it and update the secret. Stop switch if needed:
`supabase secrets set AI_PHOTO_ENABLED=false`.
