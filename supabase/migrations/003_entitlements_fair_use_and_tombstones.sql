alter table public.profiles
  alter column tier set default 'personalFree';

create or replace function public.guard_profile_tier_client_write()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.tier = 'personalFree';
    return new;
  end if;

  if new.tier is distinct from old.tier then
    raise exception 'Profile tier is controlled by verified entitlements.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_profiles_guard_tier_client_write
  on public.profiles;
create trigger trg_profiles_guard_tier_client_write
before insert or update on public.profiles
for each row execute function public.guard_profile_tier_client_write();

create table if not exists public.personal_entitlements (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  store text not null,
  purchase_token_hash text not null,
  entitlement_tier text not null default 'personalPremium',
  status text not null,
  period_started_at timestamptz null,
  period_ends_at timestamptz null,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint personal_entitlements_status_check check (
    status in (
      'active',
      'grace',
      'account_hold',
      'paused',
      'cancelled_active',
      'expired'
    )
  ),
  constraint personal_entitlements_tier_check check (
    entitlement_tier in ('personalPremium', 'pebbleHousehold')
  )
);

create unique index if not exists personal_entitlements_unique_purchase
  on public.personal_entitlements(
    owner_user_id,
    store,
    product_id,
    purchase_token_hash
  );

create index if not exists personal_entitlements_owner_status_idx
  on public.personal_entitlements(owner_user_id, status, period_ends_at desc);

drop trigger if exists trg_personal_entitlements_set_updated_at
  on public.personal_entitlements;
create trigger trg_personal_entitlements_set_updated_at
before update on public.personal_entitlements
for each row execute function public.tg_set_updated_at();

alter table public.personal_entitlements enable row level security;

drop policy if exists personal_entitlements_select_own
  on public.personal_entitlements;
create policy personal_entitlements_select_own
on public.personal_entitlements
for select using (auth.uid() = owner_user_id);

create or replace function public.has_active_personal_entitlement(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.personal_entitlements e
    where e.owner_user_id = user_id
      and e.entitlement_tier in ('personalPremium', 'pebbleHousehold')
      and e.status in ('active', 'grace', 'cancelled_active')
      and (e.period_ends_at is null or e.period_ends_at > now())
  );
$$;

create table if not exists public.proof_asset_usage (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  object_key text not null,
  byte_size integer not null check (byte_size >= 0),
  content_type text not null,
  captured_at timestamptz null,
  expires_at timestamptz not null default (now() + interval '30 days'),
  deleted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists proof_asset_usage_object_key_idx
  on public.proof_asset_usage(object_key);
create index if not exists proof_asset_usage_owner_active_idx
  on public.proof_asset_usage(owner_user_id, deleted_at, expires_at);
create index if not exists proof_asset_usage_owner_created_idx
  on public.proof_asset_usage(owner_user_id, created_at desc);

drop trigger if exists trg_proof_asset_usage_set_updated_at
  on public.proof_asset_usage;
create trigger trg_proof_asset_usage_set_updated_at
before update on public.proof_asset_usage
for each row execute function public.tg_set_updated_at();

alter table public.proof_asset_usage enable row level security;

drop policy if exists proof_asset_usage_select_own
  on public.proof_asset_usage;
create policy proof_asset_usage_select_own
on public.proof_asset_usage
for select using (auth.uid() = owner_user_id);

drop policy if exists proof_asset_usage_insert_with_entitlement
  on public.proof_asset_usage;
create policy proof_asset_usage_insert_with_entitlement
on public.proof_asset_usage
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);

drop policy if exists proof_asset_usage_update_with_entitlement
  on public.proof_asset_usage;
create policy proof_asset_usage_update_with_entitlement
on public.proof_asset_usage
for update using (
  auth.uid() = owner_user_id
) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);

drop policy if exists proof_asset_usage_delete_own
  on public.proof_asset_usage;
create policy proof_asset_usage_delete_own
on public.proof_asset_usage
for delete using (auth.uid() = owner_user_id);

create table if not exists public.sync_tombstones (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  deleted_at timestamptz not null default now(),
  source_updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint sync_tombstones_entity_type_check check (
    entity_type in ('routine', 'reminder', 'run', 'session', 'proof_asset')
  )
);

create unique index if not exists sync_tombstones_unique_entity
  on public.sync_tombstones(owner_user_id, entity_type, entity_id);
create index if not exists sync_tombstones_owner_deleted_idx
  on public.sync_tombstones(owner_user_id, deleted_at desc);

alter table public.sync_tombstones enable row level security;

drop policy if exists sync_tombstones_select_own on public.sync_tombstones;
create policy sync_tombstones_select_own
on public.sync_tombstones
for select using (auth.uid() = owner_user_id);

drop policy if exists sync_tombstones_write_with_entitlement
  on public.sync_tombstones;
create policy sync_tombstones_write_with_entitlement
on public.sync_tombstones
for all using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);

alter table public.routines
  add column if not exists deleted_at timestamptz null;
alter table public.routine_reminders
  add column if not exists deleted_at timestamptz null;
alter table public.routine_runs
  add column if not exists deleted_at timestamptz null;
alter table public.routine_sessions
  add column if not exists deleted_at timestamptz null;

create index if not exists routines_owner_deleted_updated_idx
  on public.routines(owner_user_id, deleted_at, updated_at desc);
create index if not exists routine_reminders_owner_deleted_updated_idx
  on public.routine_reminders(owner_user_id, deleted_at, updated_at desc);
create index if not exists routine_runs_owner_deleted_finished_idx
  on public.routine_runs(owner_user_id, deleted_at, finished_at desc);
create index if not exists routine_sessions_owner_deleted_updated_idx
  on public.routine_sessions(owner_user_id, deleted_at, updated_at desc);

drop policy if exists routines_own on public.routines;
drop policy if exists routine_reminders_own on public.routine_reminders;
drop policy if exists routine_runs_own on public.routine_runs;
drop policy if exists routine_sessions_own on public.routine_sessions;

create policy routines_select_own on public.routines
for select using (auth.uid() = owner_user_id);
create policy routines_insert_with_entitlement on public.routines
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routines_update_with_entitlement on public.routines
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routines_delete_own on public.routines
for delete using (auth.uid() = owner_user_id);

create policy routine_reminders_select_own on public.routine_reminders
for select using (auth.uid() = owner_user_id);
create policy routine_reminders_insert_with_entitlement
on public.routine_reminders
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_reminders_update_with_entitlement
on public.routine_reminders
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_reminders_delete_own on public.routine_reminders
for delete using (auth.uid() = owner_user_id);

create policy routine_runs_select_own on public.routine_runs
for select using (auth.uid() = owner_user_id);
create policy routine_runs_insert_with_entitlement on public.routine_runs
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_runs_update_with_entitlement on public.routine_runs
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_runs_delete_own on public.routine_runs
for delete using (auth.uid() = owner_user_id);

create policy routine_sessions_select_own on public.routine_sessions
for select using (auth.uid() = owner_user_id);
create policy routine_sessions_insert_with_entitlement
on public.routine_sessions
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_sessions_update_with_entitlement
on public.routine_sessions
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);
create policy routine_sessions_delete_own on public.routine_sessions
for delete using (auth.uid() = owner_user_id);

drop policy if exists "routine proofs own write" on storage.objects;
create policy "routine proofs own write" on storage.objects
for insert with check (
  bucket_id = 'routine-proofs'
  and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = auth.uid()::text
  and public.has_active_personal_entitlement(auth.uid())
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
  and public.has_active_personal_entitlement(auth.uid())
);
