# Deploy plan: backend fixes (October 2026)

Target: `pebble-production` (`yncgjqbjjzbinqkpukug`). Nothing on this branch has been deployed.
The live `verify_jwt` settings below were read with `list_edge_functions` on 3 Oct 2026, and `supabase/config.toml` now lists every function explicitly to match them.

## What changed

| Function | Live now | Change on this branch | Deploy? |
|---|---|---|---|
| `send-routine-completion-alert` | v14 (7 Jul) | Live source captured into git (commit `440ecdc`). No other change. | Not needed. Repo = live. |
| `request-shared-alert-contact` | v14 (7 Jul) | Live source captured (`440ecdc`). 403 text "…required for trusted contacts." changed to "…required for completion emails." to follow `COPY_GUIDELINES.md`. The app matches on the "Personal Premium is required" prefix, so its mapping still works. | Optional, low risk |
| `revenuecat-webhook` | v12 (4 Jun) | TRANSFER moves claims by app-user id, not product id, and is idempotent. Conflicts no longer return 409. Uses the shared normalisation, recomputes `profiles.tier` for every affected user, and compares the secret in constant time. | **Yes** |
| `revenuecat-sync-entitlement` | v9 (4 Jun) | Uses the same (store, product_id, hash) as the webhook, releases stale claims held by other accounts, and recomputes the tier (also when RevenueCat reports nothing active). | **Yes, with the webhook** |
| `cleanup-proof-retention` | v14 (19 May), **runs for anyone if its secret is unset** | Fails closed (503) without the secret, compares it in constant time, and never touches `users/*/guidance_audio/*` objects or `entity_type = 'guidance_audio'` rows. | **Yes. Must ship before any app build that backs up voice prompts.** The live v14 would delete those clips after 21 days. |
| `request-account-deletion` | v14 (19 May) | Fixes the `message.isEmpty` bug. Adds size limits, a stricter email check and throttles: 1 request per email per 24 h, 5 per IP per hour, 100 per hour globally. | Yes |
| `shared-alert-accept/decline/block` | v13 (19 May), old GET-acts code | Unchanged here. The repo already has the confirm-then-POST version. | Yes (audit item 3, unchanged code) |
| `delete-account`, `verify-purchase` | v13, v16 | Unchanged | No (consider deleting `verify-purchase`) |

`_shared/` (`revenuecat.ts`, `entitlements_db.ts`, `secrets.ts`) is imported relatively, and `supabase functions deploy` bundles it into each function automatically. It has no remote imports.

## Order

1. **Migration 016** (service_role grant). It fixes completion emails and contact invites immediately, with no function deploy. See `MIGRATION_REPAIR_PLAN.md` for the history repair that `db push` needs first.
2. **Confirm `CLEANUP_PROOF_RETENTION_SECRET` exists** (Dashboard → Edge Functions → Secrets). Its value must equal the Vault secret `cleanup-proof-retention-header` (present since 10 May) that cron job `cleanup-proof-retention-daily` sends as `x-cleanup-secret`. If it is missing, set it from the Vault value *before* deploying, or the nightly cleanup will start returning 503.
3. Deploy the functions:
   ```bash
   supabase link --project-ref yncgjqbjjzbinqkpukug
   supabase functions deploy revenuecat-webhook          --no-verify-jwt
   supabase functions deploy revenuecat-sync-entitlement             # verify_jwt = true
   supabase functions deploy cleanup-proof-retention     --no-verify-jwt
   supabase functions deploy request-account-deletion    --no-verify-jwt
   supabase functions deploy shared-alert-accept         --no-verify-jwt
   supabase functions deploy shared-alert-decline        --no-verify-jwt
   supabase functions deploy shared-alert-block          --no-verify-jwt
   supabase functions deploy request-shared-alert-contact            # verify_jwt = true (optional)
   ```
   Do **not** pass `--no-verify-jwt` for the sync or shared-contact functions. Live `verify_jwt` is `true` for `revenuecat-sync-entitlement`, `request-shared-alert-contact`, `send-routine-completion-alert`, `delete-account` and `verify-purchase`, and `false` for the rest.
4. Repair history and push 014, 017, 018, 019 (`MIGRATION_REPAIR_PLAN.md`). 019 should go after the voice-prompt build's upload content type is confirmed as `audio/wav` or `audio/x-wav`.
5. Smoke checks:
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
| `request-shared-alert-contact`, `send-routine-completion-alert` | `RESEND_API_KEY`, `SHARED_ALERT_FROM_EMAIL`, `SHARED_ALERT_PUBLIC_BASE_URL`. Optional: `SHARED_ALERT_REPLY_TO_EMAIL`. |

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
| `send-routine-completion-alert`, `request-shared-alert-contact` | commit `440ecdc` (byte-for-byte live v14 capture; `request-shared-alert-contact` differs only in the 403 text after `4101a3c`) |
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

`supabase/functions/**/index_test.ts` and `_shared/revenuecat_test.ts`: 40 Deno tests, all passing. In this sandbox they were run with an import map that swaps `deno.land/std` for a local stub and `esm.sh/@supabase/supabase-js` for `npm:@supabase/supabase-js@2`, because deno.land is blocked here.

```bash
cd supabase/functions && deno test --allow-env --allow-net=127.0.0.1
```
