-- Performance + lint hardening for RLS:
-- 1. Wrap auth.uid() as (select auth.uid()) so Postgres evaluates it once per
--    statement instead of once per row (advisor: auth_rls_initplan).
-- 2. Scope every policy to the authenticated role instead of public
--    (advisor: auth_allow_anonymous_sign_ins). anon could never pass the
--    auth.uid() checks, so this changes no behaviour, only lint surface.
-- 3. Add the missing covering index for routine_reminders.routine_id
--    (advisor: unindexed_foreign_keys).

-- cloud_backup_consents
alter policy cloud_backup_consents_insert_own on public.cloud_backup_consents
  to authenticated
  with check ((select auth.uid()) = owner_user_id);
alter policy cloud_backup_consents_select_own on public.cloud_backup_consents
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy cloud_backup_consents_update_own on public.cloud_backup_consents
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check ((select auth.uid()) = owner_user_id);

-- personal_entitlements
alter policy personal_entitlements_select_own on public.personal_entitlements
  to authenticated
  using ((select auth.uid()) = owner_user_id);

-- profiles
alter policy profiles_select_own on public.profiles
  to authenticated
  using ((select auth.uid()) = id);
alter policy profiles_upsert_own on public.profiles
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- proof_asset_usage
alter policy proof_asset_usage_insert_with_entitlement on public.proof_asset_usage
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));
alter policy proof_asset_usage_select_own on public.proof_asset_usage
  to authenticated
  using ((select auth.uid()) = owner_user_id);
-- Kept in sync with 015: owners may always soft-delete their own rows even
-- without an active entitlement, so re-applying this migration never
-- reintroduces the lapsed-premium history crash.
alter policy proof_asset_usage_update_with_entitlement on public.proof_asset_usage
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and (public.has_personal_cloud_write_access((select auth.uid()))
      or deleted_at is not null));

-- routine_reminders
alter policy routine_reminders_delete_own on public.routine_reminders
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_reminders_insert_with_entitlement on public.routine_reminders
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));
alter policy routine_reminders_select_own on public.routine_reminders
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_reminders_update_with_entitlement on public.routine_reminders
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));

-- routine_runs
alter policy routine_runs_delete_own on public.routine_runs
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_runs_insert_with_entitlement on public.routine_runs
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));
alter policy routine_runs_select_own on public.routine_runs
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_runs_update_with_entitlement on public.routine_runs
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));

-- routine_sessions
alter policy routine_sessions_delete_own on public.routine_sessions
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_sessions_insert_with_entitlement on public.routine_sessions
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));
alter policy routine_sessions_select_own on public.routine_sessions
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routine_sessions_update_with_entitlement on public.routine_sessions
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));

-- routines
alter policy routines_delete_own on public.routines
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routines_insert_with_entitlement on public.routines
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));
alter policy routines_select_own on public.routines
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy routines_update_with_entitlement on public.routines
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));

-- shared_alert_blocks
alter policy shared_alert_blocks_select_own on public.shared_alert_blocks
  to authenticated
  using ((select auth.uid()) = sender_user_id);

-- shared_alert_contacts
alter policy shared_alert_contacts_delete_own on public.shared_alert_contacts
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy shared_alert_contacts_insert_with_entitlement on public.shared_alert_contacts
  to authenticated
  with check (((select auth.uid()) = owner_user_id)
    and public.has_active_personal_entitlement((select auth.uid())));
alter policy shared_alert_contacts_select_own on public.shared_alert_contacts
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy shared_alert_contacts_update_with_entitlement on public.shared_alert_contacts
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_active_personal_entitlement((select auth.uid())));

-- shared_alert_events
alter policy shared_alert_events_select_own on public.shared_alert_events
  to authenticated
  using ((select auth.uid()) = owner_user_id);

-- shared_alert_invites
alter policy shared_alert_invites_delete_own on public.shared_alert_invites
  to authenticated
  using (exists (
    select 1 from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = (select auth.uid())));
alter policy shared_alert_invites_insert_own on public.shared_alert_invites
  to authenticated
  with check (exists (
    select 1 from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = (select auth.uid())));
alter policy shared_alert_invites_select_own on public.shared_alert_invites
  to authenticated
  using (exists (
    select 1 from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = (select auth.uid())));
alter policy shared_alert_invites_update_own on public.shared_alert_invites
  to authenticated
  using (exists (
    select 1 from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = (select auth.uid())));

-- sync_tombstones
alter policy sync_tombstones_select_own on public.sync_tombstones
  to authenticated
  using ((select auth.uid()) = owner_user_id);
alter policy sync_tombstones_write_with_entitlement on public.sync_tombstones
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check (((select auth.uid()) = owner_user_id)
    and public.has_personal_cloud_write_access((select auth.uid())));

-- Missing FK covering index.
create index if not exists idx_routine_reminders_routine_id
  on public.routine_reminders (routine_id);
