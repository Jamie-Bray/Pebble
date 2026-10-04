# Migration history repair plan (production)

Project: `pebble-production`, ref `yncgjqbjjzbinqkpukug`.
Checked read-only on 3 Oct 2026 with `list_migrations` and catalog queries.
**Nothing has been repaired or applied yet.**

## Current state

`supabase_migrations.schema_migrations` on production:

| Repo file | Recorded version on production | Effect present in the database? |
|---|---|---|
| `001` … `011` | `001` … `011` | Yes |
| `012_function_grant_hardening` | `20260610083720` (name `function_grant_hardening`) | Yes. Trigger functions have no API EXECUTE; `tg_set_updated_at` and `guard_profile_tier_client_write` have `search_path=""`. |
| `013_restore_rls_helper_grants` | *not recorded* | Yes. `authenticated` has EXECUTE on `has_active_personal_entitlement` and `has_personal_cloud_write_access`. |
| `014_rls_initplan_and_index` | *not recorded* | **No.** 36 public policies still have `roles = {public}` and bare `auth.uid()`; `idx_routine_reminders_routine_id` does not exist. |
| `015_proof_usage_soft_delete_without_entitlement` | `20260714194247` (name `proof_usage_soft_delete_without_entitlement`) | Yes. `proof_asset_usage_update_with_entitlement` is `to authenticated` with the `deleted_at is not null` escape. |
| `016` | *not recorded* | **Yes**, the grant was run directly on 3 Oct 2026. Record it with `supabase migration repair --status applied 016 --linked`. |
| `017` … `019` (new on this branch) | *not recorded* | No |

Because the remote has two versions the repo does not know (`20260610083720`, `20260714194247`), `supabase db push` refuses to run until history is repaired.

## Commands, in order

Run from the repo root with the Supabase CLI logged in. Each step is safe to re-run.

```bash
# 0. Link and look before touching anything
supabase link --project-ref yncgjqbjjzbinqkpukug
supabase migration list --linked

# 1. Forget the two timestamp versions (history rows only; no SQL is run)
supabase migration repair --status reverted 20260610083720 20260714194247 --linked

# 2. Record 012, 013, 015 as applied (their effects are already live; no SQL is run)
supabase migration repair --status applied 012 013 015 --linked

# 3. Check: remote should now show 001-013 and 015; 014 and 016-019 pending
supabase migration list --linked
supabase db push --linked --dry-run
#    expected pending list: 014, 016, 017, 018, 019

# 4. Apply
supabase db push --linked

# 5. Verify
supabase migration list --linked
```

Then re-run the security and performance advisors (Dashboard → Advisors). The 36 `auth_rls_initplan` warnings and the `unindexed_foreign_keys` warning should be gone.

`supabase db push` applies every pending file in one run. To stage it (for example, ship `016` immediately and the rest later), apply a file's SQL in the SQL editor and then record it with `supabase migration repair --status applied <version> --linked`, in version order.

## What 014 does, and whether it is safe

`014_rls_initplan_and_index.sql`:

1. Uses `ALTER POLICY ... TO authenticated USING/WITH CHECK (...)` on 37 existing policies across `cloud_backup_consents`, `personal_entitlements`, `profiles`, `proof_asset_usage`, `routine_reminders`, `routine_runs`, `routine_sessions`, `routines`, `shared_alert_blocks`, `shared_alert_contacts`, `shared_alert_events`, `shared_alert_invites` and `sync_tombstones`. Each one:
   - changes the role from `public` to `authenticated`;
   - wraps `auth.uid()` as `(select auth.uid())`, so Postgres evaluates it once per statement instead of once per row.
   The predicates are otherwise identical.
2. Creates `idx_routine_reminders_routine_id` (`create index if not exists`).

**Safe to apply.**

- Every policy name it alters exists on production (all 37 were checked), so no `ALTER POLICY` will fail.
- `anon` could never pass an `auth.uid() = owner` check, and `service_role` bypasses RLS, so narrowing to `authenticated` changes no access.
- The `proof_asset_usage_update_with_entitlement` statement matches what 015 already set, so it does not undo 015.
- The new index is on a tiny table, so the brief lock is negligible.
- It does not touch `storage.objects` policies.

## What the new migrations do

| File | Effect | Risk |
|---|---|---|
| `016_service_role_entitlement_helper_grant` | `grant execute on has_active_personal_entitlement(uuid) to service_role`. Today `has_function_privilege('service_role', …)` is **false**, so `request-shared-alert-contact` returns 403 to every Premium user and `send-routine-completion-alert` never sends. | None. service_role already bypasses RLS. **Apply first.** It fixes completion emails without any function deploy. |
| `017_profile_tier_mirror_from_entitlements` | Derives `profiles.tier` from `personal_entitlements`: a trigger on every entitlement write, `reconcile_profile_tiers()` backfill, a daily pg_cron job `reconcile-profile-tiers-daily` at 02:20 UTC, and the tier guard also accepts `current_user = 'postgres'`. | Low. The backfill sets the 2 stuck test profiles to `personalFree`. RLS and the app don't read `profiles.tier`, so access doesn't change. |
| `018_account_deletion_request_throttle_indexes` | Two indexes on `account_deletion_requests` plus a `NOT VALID` length check. | None (0 rows today). |
| `019_routine_proofs_bucket_limits` | `routine-proofs`: 5 MB per object; webp, jpeg, png, audio/wav, audio/x-wav. | Uploads with any other content type are rejected (HTTP 4xx). Confirm the voice-prompt upload sends `audio/wav` (or `audio/x-wav`) before applying. |

## Rollback SQL (if ever needed)

```sql
-- 019
update storage.buckets set file_size_limit = null, allowed_mime_types = null where id = 'routine-proofs';
-- 018
drop index if exists public.account_deletion_requests_ip_created_idx;
drop index if exists public.account_deletion_requests_created_idx;
alter table public.account_deletion_requests drop constraint if exists account_deletion_requests_length_check;
-- 017
select cron.unschedule('reconcile-profile-tiers-daily');
drop trigger if exists trg_personal_entitlements_refresh_profile_tier on public.personal_entitlements;
drop function if exists public.tg_personal_entitlements_refresh_profile_tier();
drop function if exists public.reconcile_profile_tiers();
drop function if exists public.refresh_profile_tier(uuid);
drop function if exists public.entitled_profile_tier(uuid);
-- then re-run the guard_profile_tier_client_write body from 007 (with set search_path = '')
-- 016 (would break shared alerts again)
revoke execute on function public.has_active_personal_entitlement(uuid) from service_role;
```

After a SQL rollback, record it with `supabase migration repair --status reverted <version> --linked`.
