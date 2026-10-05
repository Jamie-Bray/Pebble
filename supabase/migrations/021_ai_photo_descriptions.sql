-- AI photo descriptions (docs/AI_PHOTO_STEPS.md). NOT APPLIED: see the
-- "Proposed (AI photo descriptions)" section of supabase/DEPLOY_PLAN.md.
--
-- Additive only. Nothing here stores a photo or a description: the tables
-- hold a consent record, one row per request (for the idempotency key and
-- the daily allowance) and a monthly counter.
--
-- Every write goes through the describe-proof-photo Edge Function, which
-- uses the service role. The app can read its own consent row and nothing
-- else.

-- ---------------------------------------------------------------------------
-- 1. Off switch. One row. `update public.ai_photo_settings set paused = true;`
--    stops every description on the next request, without a deploy.
--    The AI_PHOTO_ENABLED function secret must also be "true" for the
--    feature to run, so it stays off until both say so.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_photo_settings (
  id boolean primary key default true,
  paused boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint ai_photo_settings_single_row check (id)
);

insert into public.ai_photo_settings (id) values (true)
on conflict (id) do nothing;

alter table public.ai_photo_settings enable row level security;
revoke all on table public.ai_photo_settings from anon, authenticated;
grant all privileges on table public.ai_photo_settings to service_role;

-- ---------------------------------------------------------------------------
-- 2. Consent: one row per account (one routine at a time has AI switched on).
--    A consent counts while withdrawn_at is null and consent_version equals
--    the version the function expects (AI_PHOTO_CONSENT_VERSION).
-- ---------------------------------------------------------------------------
create table if not exists public.ai_photo_consents (
  owner_user_id uuid primary key references auth.users(id) on delete cascade,
  consent_version text not null,
  provider text not null,
  routine_key text null,
  app_version text null,
  consented_at timestamptz not null,
  withdrawn_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_photo_consents_size_check check (
    char_length(consent_version) <= 40
    and char_length(provider) <= 40
    and (routine_key is null or char_length(routine_key) <= 100)
    and (app_version is null or char_length(app_version) <= 40)
  )
);

alter table public.ai_photo_consents enable row level security;

drop policy if exists ai_photo_consents_select_own on public.ai_photo_consents;
create policy ai_photo_consents_select_own
on public.ai_photo_consents
for select using ((select auth.uid()) = owner_user_id);

revoke all on table public.ai_photo_consents from anon, authenticated;
grant select on table public.ai_photo_consents to authenticated;
grant all privileges on table public.ai_photo_consents to service_role;

-- ---------------------------------------------------------------------------
-- 3. Requests: the idempotency key (so a double tap or a retry is counted
--    once) and the rows the daily allowance is counted from. Rows older than
--    two days are deleted as the account makes new requests.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_photo_requests (
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  primary key (owner_user_id, idempotency_key),
  constraint ai_photo_requests_key_check check (char_length(idempotency_key) between 8 and 80)
);

create index if not exists ai_photo_requests_owner_created_idx
  on public.ai_photo_requests (owner_user_id, created_at desc);

alter table public.ai_photo_requests enable row level security;
revoke all on table public.ai_photo_requests from anon, authenticated;
grant all privileges on table public.ai_photo_requests to service_role;

-- ---------------------------------------------------------------------------
-- 4. Monthly budget: provider calls across all accounts, per UTC month.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_photo_budget (
  month date primary key,
  requests integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.ai_photo_budget enable row level security;
revoke all on table public.ai_photo_budget from anon, authenticated;
grant all privileges on table public.ai_photo_budget to service_role;

-- ---------------------------------------------------------------------------
-- 5. Reserve one description. One transaction, so two requests arriving
--    together cannot both take the last place:
--      'duplicate'         this idempotency key was already counted
--      'daily_limit'       the account has used its allowance (rolling 24 h)
--      'budget_exhausted'  the month's budget is used up
--      'ok'                counted; the function may call the provider
--    A reservation is never given back, including when the provider call
--    fails or times out.
-- ---------------------------------------------------------------------------
create or replace function public.reserve_ai_photo_description(
  p_user_id uuid,
  p_idempotency_key text,
  p_daily_limit integer,
  p_monthly_limit integer
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_used integer;
  v_counted integer;
begin
  if p_user_id is null or p_idempotency_key is null
     or p_daily_limit is null or p_monthly_limit is null then
    return 'budget_exhausted';
  end if;

  -- One request at a time per account.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 21));

  if exists (
    select 1 from public.ai_photo_requests
    where owner_user_id = p_user_id and idempotency_key = p_idempotency_key
  ) then
    return 'duplicate';
  end if;

  delete from public.ai_photo_requests
  where owner_user_id = p_user_id and created_at < now() - interval '2 days';

  select count(*) into v_used
  from public.ai_photo_requests
  where owner_user_id = p_user_id and created_at > now() - interval '24 hours';
  if v_used >= p_daily_limit then
    return 'daily_limit';
  end if;

  insert into public.ai_photo_budget (month) values (v_month)
  on conflict (month) do nothing;

  -- The row lock makes this the single place the month's count can pass the limit.
  update public.ai_photo_budget
  set requests = requests + 1, updated_at = now()
  where month = v_month and requests < p_monthly_limit;
  get diagnostics v_counted = row_count;
  if v_counted = 0 then
    return 'budget_exhausted';
  end if;

  insert into public.ai_photo_requests (owner_user_id, idempotency_key)
  values (p_user_id, p_idempotency_key);

  return 'ok';
end;
$$;

revoke all on function public.reserve_ai_photo_description(uuid, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_ai_photo_description(uuid, text, integer, integer)
  to service_role;
