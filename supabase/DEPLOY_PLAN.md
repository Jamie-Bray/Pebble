# Deploy plan: backend fixes (October 2026)

Target: `pebble-production` (`yncgjqbjjzbinqkpukug`). Nothing on this branch has been deployed.
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
