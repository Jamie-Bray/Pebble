-- URGENT FOLLOW-UP TO 012: migration 012 revoked EXECUTE from public on the
-- entitlement helpers, which also removed the implicit grant the
-- authenticated role relied on inside RLS policies
-- (routines_*_with_entitlement etc.). Until this runs, every authenticated
-- INSERT/UPDATE gated by those policies fails with permission denied.
-- Restore the two grants the policies require; anon stays revoked.
grant execute on function public.has_active_personal_entitlement(uuid) to authenticated;
grant execute on function public.has_personal_cloud_write_access(uuid) to authenticated;
