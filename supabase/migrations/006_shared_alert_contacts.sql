create extension if not exists pgcrypto;

create table if not exists public.shared_alert_contacts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  routine_key text not null,
  recipient_email text not null,
  normalized_email text not null,
  recipient_email_hash text not null,
  status text not null default 'pending',
  notify_when_finished boolean not null default false,
  include_routine_name boolean not null default true,
  include_step_count boolean not null default true,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz null,
  declined_at timestamptz null,
  blocked_at timestamptz null,
  disabled_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_alert_contacts_status_check check (
    status in ('pending', 'accepted', 'declined', 'blocked', 'disabled')
  )
);

create unique index if not exists shared_alert_contacts_owner_routine_unique
  on public.shared_alert_contacts(owner_user_id, routine_key);
create index if not exists shared_alert_contacts_owner_status_idx
  on public.shared_alert_contacts(owner_user_id, status, updated_at desc);
create index if not exists shared_alert_contacts_recipient_hash_idx
  on public.shared_alert_contacts(recipient_email_hash);

drop trigger if exists trg_shared_alert_contacts_set_updated_at
  on public.shared_alert_contacts;
create trigger trg_shared_alert_contacts_set_updated_at
before update on public.shared_alert_contacts
for each row execute function public.tg_set_updated_at();

alter table public.shared_alert_contacts enable row level security;

drop policy if exists shared_alert_contacts_select_own
  on public.shared_alert_contacts;
create policy shared_alert_contacts_select_own
on public.shared_alert_contacts
for select using (auth.uid() = owner_user_id);

drop policy if exists shared_alert_contacts_insert_with_entitlement
  on public.shared_alert_contacts;
create policy shared_alert_contacts_insert_with_entitlement
on public.shared_alert_contacts
for insert with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);

drop policy if exists shared_alert_contacts_update_with_entitlement
  on public.shared_alert_contacts;
create policy shared_alert_contacts_update_with_entitlement
on public.shared_alert_contacts
for update using (auth.uid() = owner_user_id) with check (
  auth.uid() = owner_user_id
  and public.has_active_personal_entitlement(auth.uid())
);

drop policy if exists shared_alert_contacts_delete_own
  on public.shared_alert_contacts;
create policy shared_alert_contacts_delete_own
on public.shared_alert_contacts
for delete using (auth.uid() = owner_user_id);

create table if not exists public.shared_alert_invites (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references public.shared_alert_contacts(id)
    on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz null,
  declined_at timestamptz null,
  blocked_at timestamptz null,
  created_at timestamptz not null default now()
);

create index if not exists shared_alert_invites_contact_idx
  on public.shared_alert_invites(contact_id, created_at desc);
create index if not exists shared_alert_invites_token_active_idx
  on public.shared_alert_invites(token_hash, expires_at);

alter table public.shared_alert_invites enable row level security;

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

create table if not exists public.shared_alert_blocks (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  normalized_email text not null,
  recipient_email_hash text not null,
  reason text not null default 'recipient_blocked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists shared_alert_blocks_sender_email_unique
  on public.shared_alert_blocks(sender_user_id, recipient_email_hash);

drop trigger if exists trg_shared_alert_blocks_set_updated_at
  on public.shared_alert_blocks;
create trigger trg_shared_alert_blocks_set_updated_at
before update on public.shared_alert_blocks
for each row execute function public.tg_set_updated_at();

alter table public.shared_alert_blocks enable row level security;

drop policy if exists shared_alert_blocks_select_own
  on public.shared_alert_blocks;
create policy shared_alert_blocks_select_own
on public.shared_alert_blocks
for select using (auth.uid() = sender_user_id);

create table if not exists public.shared_alert_events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid not null references public.shared_alert_contacts(id)
    on delete cascade,
  routine_key text not null,
  run_id text not null,
  session_id text null,
  routine_title text not null,
  completed_at timestamptz not null,
  completed_steps integer not null check (completed_steps >= 0),
  total_steps integer not null check (total_steps >= 0),
  status text not null default 'pending',
  provider text null,
  provider_message_id text null,
  provider_response jsonb null,
  error_summary text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_alert_events_status_check check (
    status in ('pending', 'sent', 'failed', 'skipped')
  )
);

create unique index if not exists shared_alert_events_contact_run_unique
  on public.shared_alert_events(contact_id, run_id);
create index if not exists shared_alert_events_owner_created_idx
  on public.shared_alert_events(owner_user_id, created_at desc);

drop trigger if exists trg_shared_alert_events_set_updated_at
  on public.shared_alert_events;
create trigger trg_shared_alert_events_set_updated_at
before update on public.shared_alert_events
for each row execute function public.tg_set_updated_at();

alter table public.shared_alert_events enable row level security;

drop policy if exists shared_alert_events_select_own
  on public.shared_alert_events;
create policy shared_alert_events_select_own
on public.shared_alert_events
for select using (auth.uid() = owner_user_id);
