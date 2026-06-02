drop policy if exists shared_alert_invites_select_own
  on public.shared_alert_invites;
create policy shared_alert_invites_select_own
on public.shared_alert_invites
for select using (
  exists (
    select 1
    from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = auth.uid()
  )
);

drop policy if exists shared_alert_invites_insert_own
  on public.shared_alert_invites;
create policy shared_alert_invites_insert_own
on public.shared_alert_invites
for insert with check (
  exists (
    select 1
    from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = auth.uid()
  )
);

drop policy if exists shared_alert_invites_update_own
  on public.shared_alert_invites;
create policy shared_alert_invites_update_own
on public.shared_alert_invites
for update using (
  exists (
    select 1
    from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = auth.uid()
  )
) with check (
  exists (
    select 1
    from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = auth.uid()
  )
);

drop policy if exists shared_alert_invites_delete_own
  on public.shared_alert_invites;
create policy shared_alert_invites_delete_own
on public.shared_alert_invites
for delete using (
  exists (
    select 1
    from public.shared_alert_contacts c
    where c.id = shared_alert_invites.contact_id
      and c.owner_user_id = auth.uid()
  )
);

drop policy if exists shared_alert_blocks_select_own
  on public.shared_alert_blocks;
create policy shared_alert_blocks_select_own
on public.shared_alert_blocks
for select using (auth.uid() = sender_user_id);

create or replace function public.guard_proof_asset_usage_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_bytes bigint;
  rolling_uploads integer;
  excluded_id uuid := null;
  storage_limit_bytes constant bigint := 1073741824;
  rolling_upload_limit constant integer := 500;
begin
  if new.owner_user_id is null then
    raise exception 'Proof asset owner is required.';
  end if;

  if split_part(new.object_key, '/', 1) <> 'users'
     or split_part(new.object_key, '/', 2) <> new.owner_user_id::text then
    raise exception 'Proof asset object key must be scoped to its owner.';
  end if;

  if tg_op = 'UPDATE' then
    excluded_id := old.id;
  end if;

  select coalesce(sum(byte_size), 0)
  into active_bytes
  from public.proof_asset_usage
  where owner_user_id = new.owner_user_id
    and deleted_at is null
    and expires_at > now()
    and (excluded_id is null or id <> excluded_id);

  if new.deleted_at is null and new.expires_at > now() then
    active_bytes := active_bytes + new.byte_size;
  end if;

  if active_bytes > storage_limit_bytes then
    raise exception 'Proof media storage quota exceeded.';
  end if;

  if tg_op = 'INSERT'
     or (tg_op = 'UPDATE' and old.deleted_at is not null and new.deleted_at is null) then
    select count(*)
    into rolling_uploads
    from public.proof_asset_usage
    where owner_user_id = new.owner_user_id
      and created_at >= now() - interval '30 days'
      and (excluded_id is null or id <> excluded_id);

    if rolling_uploads + 1 > rolling_upload_limit then
      raise exception 'Proof media rolling upload quota exceeded.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_proof_asset_usage_guard_quota
  on public.proof_asset_usage;
create trigger trg_proof_asset_usage_guard_quota
before insert or update on public.proof_asset_usage
for each row execute function public.guard_proof_asset_usage_quota();

drop policy if exists proof_asset_usage_delete_own
  on public.proof_asset_usage;

drop policy if exists "routine proofs own write" on storage.objects;
create policy "routine proofs own write" on storage.objects
for insert with check (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and public.has_personal_cloud_write_access(auth.uid())
  and exists (
    select 1
    from public.proof_asset_usage usage
    where usage.owner_user_id = auth.uid()
      and usage.object_key = name
      and usage.deleted_at is null
      and usage.expires_at > now()
  )
);

drop policy if exists "routine proofs own update" on storage.objects;
