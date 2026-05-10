create table if not exists public.cloud_backup_consents (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null,
  feature_enabled boolean not null default false,
  app_version text not null,
  privacy_version text not null,
  terms_version text not null,
  consent_text_hash text not null,
  consented_at timestamptz null,
  withdrawn_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cloud_backup_consents_feature_check check (
    feature in ('personal_cloud_backup')
  )
);

create unique index if not exists cloud_backup_consents_owner_feature_idx
  on public.cloud_backup_consents(owner_user_id, feature);

drop trigger if exists trg_cloud_backup_consents_set_updated_at
  on public.cloud_backup_consents;
create trigger trg_cloud_backup_consents_set_updated_at
before update on public.cloud_backup_consents
for each row execute function public.tg_set_updated_at();

alter table public.cloud_backup_consents enable row level security;

drop policy if exists cloud_backup_consents_select_own
  on public.cloud_backup_consents;
create policy cloud_backup_consents_select_own
on public.cloud_backup_consents
for select using (auth.uid() = owner_user_id);

drop policy if exists cloud_backup_consents_insert_own
  on public.cloud_backup_consents;
create policy cloud_backup_consents_insert_own
on public.cloud_backup_consents
for insert with check (auth.uid() = owner_user_id);

drop policy if exists cloud_backup_consents_update_own
  on public.cloud_backup_consents;
create policy cloud_backup_consents_update_own
on public.cloud_backup_consents
for update using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

create or replace function public.has_current_cloud_backup_consent(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cloud_backup_consents c
    where c.owner_user_id = user_id
      and c.feature = 'personal_cloud_backup'
      and c.feature_enabled = true
      and c.withdrawn_at is null
      and c.privacy_version = '2026-05-04'
      and c.terms_version = '2026-05-04'
      and c.consent_text_hash =
        '8dccbbc07131667df5c9c04f2659ffe957b60774636ef1885a3dd46a0940d5c0'
  );
$$;

create or replace function public.has_personal_cloud_write_access(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.has_current_cloud_backup_consent(user_id)
    and (
      public.has_active_personal_entitlement(user_id)
      or exists (
        select 1
        from public.profiles p
        where p.id = user_id
          and p.tier in ('personalPremium', 'pebbleHousehold')
      )
    );
$$;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  normalized_email text not null,
  message text null,
  confirmed_understanding boolean not null default false,
  status text not null default 'new',
  source text not null default 'web',
  request_ip_hash text null,
  user_agent text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_deletion_requests_status_check check (
    status in ('new', 'verified', 'completed', 'rejected')
  ),
  constraint account_deletion_requests_source_check check (
    source in ('web', 'support', 'in_app')
  )
);

create index if not exists account_deletion_requests_email_status_idx
  on public.account_deletion_requests(normalized_email, status, created_at desc);

drop trigger if exists trg_account_deletion_requests_set_updated_at
  on public.account_deletion_requests;
create trigger trg_account_deletion_requests_set_updated_at
before update on public.account_deletion_requests
for each row execute function public.tg_set_updated_at();

alter table public.account_deletion_requests enable row level security;
