-- Keep production access explicit when "automatically expose new tables" is off.
-- RLS policies still decide which rows each user can read or write.

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on table public.profiles to authenticated;

grant select, insert, update, delete on table public.routines to authenticated;
grant select, insert, update, delete on table public.routine_reminders to authenticated;
grant select, insert, update, delete on table public.routine_runs to authenticated;
grant select, insert, update, delete on table public.routine_sessions to authenticated;

grant select on table public.personal_entitlements to authenticated;
grant select, insert, update, delete on table public.proof_asset_usage to authenticated;
grant select, insert, update, delete on table public.sync_tombstones to authenticated;

grant select, insert, update on table public.cloud_backup_consents to authenticated;

grant select, insert, update, delete on table public.shared_alert_contacts to authenticated;
grant select, insert, update, delete on table public.shared_alert_invites to authenticated;
grant select on table public.shared_alert_blocks to authenticated;
grant select on table public.shared_alert_events to authenticated;

grant all privileges on table public.profiles to service_role;
grant all privileges on table public.routines to service_role;
grant all privileges on table public.routine_reminders to service_role;
grant all privileges on table public.routine_runs to service_role;
grant all privileges on table public.routine_sessions to service_role;
grant all privileges on table public.personal_entitlements to service_role;
grant all privileges on table public.proof_asset_usage to service_role;
grant all privileges on table public.sync_tombstones to service_role;
grant all privileges on table public.cloud_backup_consents to service_role;
grant all privileges on table public.account_deletion_requests to service_role;
grant all privileges on table public.shared_alert_contacts to service_role;
grant all privileges on table public.shared_alert_invites to service_role;
grant all privileges on table public.shared_alert_blocks to service_role;
grant all privileges on table public.shared_alert_events to service_role;
