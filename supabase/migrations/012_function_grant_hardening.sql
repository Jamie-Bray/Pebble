-- Harden function grants and pin trigger search paths.
--
-- Trigger and event-trigger functions are executed by the system, never by
-- API callers; PostgREST exposure of them is pure attack surface.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.guard_proof_asset_usage_quota() from public, anon, authenticated;
revoke execute on function public.tg_set_updated_at() from public, anon, authenticated;
revoke execute on function public.guard_profile_tier_client_write() from public, anon, authenticated;

-- Entitlement helpers are evaluated inside RLS policies, so the authenticated
-- role must keep EXECUTE on the two referenced there. anon can never pass the
-- auth.uid() checks and gets no EXECUTE at all. The consent helper is only
-- called from inside has_personal_cloud_write_access (SECURITY DEFINER, owner
-- context), so no API role needs it.
revoke execute on function public.has_active_personal_entitlement(uuid) from public, anon;
revoke execute on function public.has_personal_cloud_write_access(uuid) from public, anon;
revoke execute on function public.has_current_cloud_backup_consent(uuid) from public, anon, authenticated;

-- Pin search_path on the two triggers that still had it mutable. Both bodies
-- only use built-ins and schema-qualified references, so empty is safe
-- (pg_catalog is always searched implicitly).
alter function public.tg_set_updated_at() set search_path = '';
alter function public.guard_profile_tier_client_write() set search_path = '';
