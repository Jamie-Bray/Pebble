-- Pre-store bridge:
-- Google Play verification will write personal_entitlements as the launch
-- source of truth. Until Play credentials/product setup is available, the app's
-- local/dev purchase path mirrors the tier onto profiles so real-device sync
-- can be tested without blocking routine backup writes.

drop trigger if exists trg_profiles_guard_tier_client_write
  on public.profiles;

create or replace function public.has_personal_cloud_write_access(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.has_active_personal_entitlement(user_id)
    or exists (
      select 1
      from public.profiles p
      where p.id = user_id
        and p.tier in ('personalPremium', 'pebbleHousehold')
    );
$$;

drop policy if exists routines_insert_with_entitlement on public.routines;
drop policy if exists routines_update_with_entitlement on public.routines;
drop policy if exists routine_reminders_insert_with_entitlement
  on public.routine_reminders;
drop policy if exists routine_reminders_update_with_entitlement
  on public.routine_reminders;
drop policy if exists routine_runs_insert_with_entitlement
  on public.routine_runs;
drop policy if exists routine_runs_update_with_entitlement
  on public.routine_runs;
drop policy if exists routine_sessions_insert_with_entitlement
  on public.routine_sessions;
drop policy if exists routine_sessions_update_with_entitlement
  on public.routine_sessions;
drop policy if exists proof_asset_usage_insert_with_entitlement
  on public.proof_asset_usage;
drop policy if exists proof_asset_usage_update_with_entitlement
  on public.proof_asset_usage;
drop policy if exists sync_tombstones_write_with_entitlement
  on public.sync_tombstones;

create policy routines_insert_with_entitlement on public.routines
for insert with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);
create policy routines_update_with_entitlement on public.routines
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

create policy routine_reminders_insert_with_entitlement
on public.routine_reminders
for insert with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);
create policy routine_reminders_update_with_entitlement
on public.routine_reminders
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

create policy routine_runs_insert_with_entitlement on public.routine_runs
for insert with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);
create policy routine_runs_update_with_entitlement on public.routine_runs
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

create policy routine_sessions_insert_with_entitlement
on public.routine_sessions
for insert with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);
create policy routine_sessions_update_with_entitlement
on public.routine_sessions
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

create policy proof_asset_usage_insert_with_entitlement
on public.proof_asset_usage
for insert with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);
create policy proof_asset_usage_update_with_entitlement
on public.proof_asset_usage
for update using (
  auth.uid() = owner_user_id
) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

create policy sync_tombstones_write_with_entitlement
on public.sync_tombstones
for all using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_personal_cloud_write_access(auth.uid())
);

drop policy if exists "routine proofs own write" on storage.objects;
create policy "routine proofs own write" on storage.objects
for insert with check (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and public.has_personal_cloud_write_access(auth.uid())
);

drop policy if exists "routine proofs own update" on storage.objects;
create policy "routine proofs own update" on storage.objects
for update using (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
) with check (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and public.has_personal_cloud_write_access(auth.uid())
);
