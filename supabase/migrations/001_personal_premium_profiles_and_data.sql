create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'personalPremium',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.routines (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  steps_json jsonb not null default '[]'::jsonb,
  icon_key text null,
  color_hex integer null,
  is_pinned boolean not null default false,
  pinned_at timestamptz null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.routine_reminders (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  routine_id uuid not null references public.routines(id) on delete cascade,
  day_of_week integer not null,
  time text not null,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.routine_runs (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  routine_id text null,
  routine_title text not null,
  finished_at timestamptz not null,
  step_completion_data jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.routine_sessions (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  payload_json jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_routines_owner_updated_at
  on public.routines(owner_user_id, updated_at desc);
create index if not exists idx_routine_reminders_owner_updated_at
  on public.routine_reminders(owner_user_id, updated_at desc);
create index if not exists idx_routine_runs_owner_finished_at
  on public.routine_runs(owner_user_id, finished_at desc);
create index if not exists idx_routine_sessions_owner_updated_at
  on public.routine_sessions(owner_user_id, updated_at desc);

create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_routines_set_updated_at on public.routines;
create trigger trg_routines_set_updated_at
before update on public.routines
for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_routine_reminders_set_updated_at on public.routine_reminders;
create trigger trg_routine_reminders_set_updated_at
before update on public.routine_reminders
for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_routine_runs_set_updated_at on public.routine_runs;
create trigger trg_routine_runs_set_updated_at
before update on public.routine_runs
for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_routine_sessions_set_updated_at on public.routine_sessions;
create trigger trg_routine_sessions_set_updated_at
before update on public.routine_sessions
for each row execute function public.tg_set_updated_at();

alter table public.profiles enable row level security;
alter table public.routines enable row level security;
alter table public.routine_reminders enable row level security;
alter table public.routine_runs enable row level security;
alter table public.routine_sessions enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select using (auth.uid() = id);

drop policy if exists profiles_upsert_own on public.profiles;
create policy profiles_upsert_own on public.profiles
for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists routines_own on public.routines;
create policy routines_own on public.routines
for all using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);

drop policy if exists routine_reminders_own on public.routine_reminders;
create policy routine_reminders_own on public.routine_reminders
for all using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);

drop policy if exists routine_runs_own on public.routine_runs;
create policy routine_runs_own on public.routine_runs
for all using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);

drop policy if exists routine_sessions_own on public.routine_sessions;
create policy routine_sessions_own on public.routine_sessions
for all using (auth.uid() = owner_user_id) with check (auth.uid() = owner_user_id);
