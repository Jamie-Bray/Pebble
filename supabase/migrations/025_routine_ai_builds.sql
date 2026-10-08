-- AI routine builder (/mnt/project-files/ai-routine-builder/PLAN.md).
-- NOT APPLIED: see the "Proposed (AI routine builder)" section of
-- supabase/DEPLOY_PLAN.md.
--
-- Additive only. Nothing here stores what the person typed or the routine
-- that came back: the tables hold one row per build (to count the free build
-- and the Personal Premium daily allowance) and a monthly counter.
--
-- Onboarding runs before sign-in and anonymous sign-in is off, so a build is
-- keyed by the random install ID the app keeps on the phone, plus the account
-- when the person is signed in. Free: one build per install and per account.
--
-- Every read and write goes through the build-routine Edge Function, which
-- uses the service role. The app cannot read or write these tables.

-- ---------------------------------------------------------------------------
-- 1. Off switch. One row. `update public.routine_ai_settings set paused = true;`
--    stops every build on the next request, without a deploy. Setting the
--    ROUTINE_AI_ENABLED function secret to "false" also turns it off.
-- ---------------------------------------------------------------------------
create table if not exists public.routine_ai_settings (
  id boolean primary key default true,
  paused boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint routine_ai_settings_single_row check (id)
);

insert into public.routine_ai_settings (id) values (true)
on conflict (id) do nothing;

alter table public.routine_ai_settings enable row level security;
revoke all on table public.routine_ai_settings from anon, authenticated;
grant all privileges on table public.routine_ai_settings to service_role;

-- ---------------------------------------------------------------------------
-- 2. Builds. One row per build: a "Try again" or the follow-up after the
--    questions reuses the same build_key and only adds to `calls`.
--    `used` turns true once the provider has answered, so a build that
--    failed every time does not use up the free build.
-- ---------------------------------------------------------------------------
create table if not exists public.routine_ai_builds (
  build_key text primary key,
  install_id uuid not null,
  owner_user_id uuid null references auth.users(id) on delete set null,
  premium boolean not null default false,
  calls integer not null default 0,
  used boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint routine_ai_builds_key_check check (char_length(build_key) between 8 and 80)
);

create index if not exists routine_ai_builds_install_idx
  on public.routine_ai_builds (install_id);
create index if not exists routine_ai_builds_owner_created_idx
  on public.routine_ai_builds (owner_user_id, created_at desc);
create index if not exists routine_ai_builds_created_idx
  on public.routine_ai_builds (created_at desc);

alter table public.routine_ai_builds enable row level security;
revoke all on table public.routine_ai_builds from anon, authenticated;
grant all privileges on table public.routine_ai_builds to service_role;

-- ---------------------------------------------------------------------------
-- 3. Monthly budget: provider calls across everyone, per UTC month.
-- ---------------------------------------------------------------------------
create table if not exists public.routine_ai_budget (
  month date primary key,
  calls integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.routine_ai_budget enable row level security;
revoke all on table public.routine_ai_budget from anon, authenticated;
grant all privileges on table public.routine_ai_budget to service_role;

-- ---------------------------------------------------------------------------
-- 4. Reserve one provider call. One transaction, so two requests arriving
--    together cannot both take the last place:
--      'too_many_tries'    this build has had its calls
--      'free_used'         a free install or account already used its build
--      'daily_limit'       Personal Premium: the account's builds in 24 h
--      'free_daily_cap'    free builds across everyone in 24 h (abuse guard)
--      'budget_exhausted'  the month's calls are used up
--      'ok'                counted; the function may call the provider
--    A reserved call is never given back.
-- ---------------------------------------------------------------------------
create or replace function public.reserve_routine_ai_call(
  p_build_key text,
  p_install_id uuid,
  p_user_id uuid,
  p_premium boolean,
  p_calls_per_build integer,
  p_premium_daily_limit integer,
  p_free_daily_cap integer,
  p_monthly_limit integer
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_build public.routine_ai_builds%rowtype;
  v_used integer;
  v_counted integer;
begin
  if p_build_key is null or p_install_id is null or p_premium is null
     or p_calls_per_build is null or p_premium_daily_limit is null
     or p_free_daily_cap is null or p_monthly_limit is null then
    return 'budget_exhausted';
  end if;

  -- One request at a time per install.
  perform pg_advisory_xact_lock(hashtextextended(p_install_id::text, 25));

  select * into v_build from public.routine_ai_builds where build_key = p_build_key;

  if found then
    -- A build key belongs to the install that started it.
    if v_build.install_id <> p_install_id then
      return 'too_many_tries';
    end if;
    if v_build.calls >= p_calls_per_build then
      return 'too_many_tries';
    end if;
  else
    if not p_premium then
      if exists (
        select 1 from public.routine_ai_builds
        where used
          and (install_id = p_install_id
               or (p_user_id is not null and owner_user_id = p_user_id))
      ) then
        return 'free_used';
      end if;
      select count(*) into v_used from public.routine_ai_builds
      where not premium and used and created_at > now() - interval '24 hours';
      if v_used >= p_free_daily_cap then
        return 'free_daily_cap';
      end if;
    else
      select count(*) into v_used from public.routine_ai_builds
      where owner_user_id = p_user_id and premium
        and created_at > now() - interval '24 hours';
      if v_used >= p_premium_daily_limit then
        return 'daily_limit';
      end if;
    end if;
  end if;

  insert into public.routine_ai_budget (month) values (v_month)
  on conflict (month) do nothing;

  -- The row lock makes this the single place the month's count can pass the limit.
  update public.routine_ai_budget
  set calls = calls + 1, updated_at = now()
  where month = v_month and calls < p_monthly_limit;
  get diagnostics v_counted = row_count;
  if v_counted = 0 then
    return 'budget_exhausted';
  end if;

  insert into public.routine_ai_builds (build_key, install_id, owner_user_id, premium, calls)
  values (p_build_key, p_install_id, p_user_id, p_premium, 1)
  on conflict (build_key) do update
    set calls = public.routine_ai_builds.calls + 1,
        owner_user_id = coalesce(public.routine_ai_builds.owner_user_id, excluded.owner_user_id),
        updated_at = now();

  return 'ok';
end;
$$;

revoke all on function public.reserve_routine_ai_call(text, uuid, uuid, boolean, integer, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_routine_ai_call(text, uuid, uuid, boolean, integer, integer, integer, integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- 5. What the app shows before a build: is the free build still there?
-- ---------------------------------------------------------------------------
create or replace function public.routine_ai_free_build_used(
  p_install_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.routine_ai_builds
    where used
      and (install_id = p_install_id
           or (p_user_id is not null and owner_user_id = p_user_id))
  );
$$;

revoke all on function public.routine_ai_free_build_used(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.routine_ai_free_build_used(uuid, uuid)
  to service_role;
