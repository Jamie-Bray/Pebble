-- Keep a free AI build available until a draft exists, while reserving its
-- place during questions and provider calls. Apply before deploying the new
-- build-routine function. Existing content and build counts are untouched.

alter table public.routine_ai_builds
  add column if not exists reserved_until timestamptz;

update public.routine_ai_builds
set reserved_until = updated_at + interval '15 minutes'
where not used and reserved_until is null
  and updated_at > now() - interval '15 minutes';

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
  v_existing boolean;
  v_used integer;
  v_counted integer;
begin
  if p_build_key is null or p_install_id is null or p_premium is null
     or p_calls_per_build is null or p_premium_daily_limit is null
     or p_free_daily_cap is null or p_monthly_limit is null then
    return 'budget_exhausted';
  end if;

  -- Both locks are needed: one account may be signed in on two phones.
  perform pg_advisory_xact_lock(hashtextextended('routine-ai-install:' || p_install_id::text, 25));
  if p_user_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('routine-ai-account:' || p_user_id::text, 25));
  end if;

  select * into v_build from public.routine_ai_builds where build_key = p_build_key;
  v_existing := found;
  if v_existing then
    if v_build.install_id <> p_install_id then
      return 'too_many_tries';
    end if;
    if v_build.calls >= p_calls_per_build then
      if not v_build.used then
        update public.routine_ai_builds
        set reserved_until = null
        where build_key = p_build_key;
      end if;
      return 'too_many_tries';
    end if;
    if not p_premium and v_build.premium then
      return 'free_used';
    end if;
  end if;

  if not p_premium and (not v_existing or not v_build.used) then
    if exists (
      select 1 from public.routine_ai_builds
      where build_key <> p_build_key and used
        and (install_id = p_install_id
             or (p_user_id is not null and owner_user_id = p_user_id))
    ) then
      return 'free_used';
    end if;
    if exists (
      select 1 from public.routine_ai_builds
      where build_key <> p_build_key and not used
        and reserved_until > now()
        and (install_id = p_install_id
             or (p_user_id is not null and owner_user_id = p_user_id))
    ) then
      return 'pending';
    end if;
  end if;

  if not v_existing then
    if not p_premium then
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
  update public.routine_ai_budget
  set calls = calls + 1, updated_at = now()
  where month = v_month and calls < p_monthly_limit;
  get diagnostics v_counted = row_count;
  if v_counted = 0 then
    return 'budget_exhausted';
  end if;

  insert into public.routine_ai_builds
    (build_key, install_id, owner_user_id, premium, calls, reserved_until)
  values
    (p_build_key, p_install_id, p_user_id, p_premium, 1, now() + interval '15 minutes')
  on conflict (build_key) do update
    set calls = public.routine_ai_builds.calls + 1,
        owner_user_id = coalesce(public.routine_ai_builds.owner_user_id, excluded.owner_user_id),
        reserved_until = excluded.reserved_until,
        updated_at = now();
  return 'ok';
end;
$$;

revoke all on function public.reserve_routine_ai_call(text, uuid, uuid, boolean, integer, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_routine_ai_call(text, uuid, uuid, boolean, integer, integer, integer, integer)
  to service_role;

-- Finish under the same locks as reserve. If a timed-out request and a newer
-- one both produce drafts, only one can consume the free build.
create or replace function public.finish_routine_ai_call(
  p_build_key text,
  p_outcome text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_build public.routine_ai_builds%rowtype;
begin
  if p_outcome not in ('draft', 'questions', 'failed') then
    return 'invalid';
  end if;

  select * into v_build from public.routine_ai_builds where build_key = p_build_key;
  if not found then
    return 'missing';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('routine-ai-install:' || v_build.install_id::text, 25));
  select * into v_build from public.routine_ai_builds where build_key = p_build_key;
  if v_build.owner_user_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('routine-ai-account:' || v_build.owner_user_id::text, 25));
  end if;
  select * into v_build from public.routine_ai_builds
  where build_key = p_build_key for update;

  if p_outcome = 'draft' then
    if not v_build.premium and exists (
      select 1 from public.routine_ai_builds
      where build_key <> p_build_key and used
        and (install_id = v_build.install_id
             or (v_build.owner_user_id is not null and owner_user_id = v_build.owner_user_id))
    ) then
      update public.routine_ai_builds
      set reserved_until = null, updated_at = now()
      where build_key = p_build_key;
      return 'free_used';
    end if;
    update public.routine_ai_builds
    set used = true, reserved_until = null, updated_at = now()
    where build_key = p_build_key;
  else
    update public.routine_ai_builds
    set reserved_until = now() + interval '15 minutes',
        updated_at = now()
    where build_key = p_build_key;
  end if;
  return 'ok';
end;
$$;

revoke all on function public.finish_routine_ai_call(text, text)
  from public, anon, authenticated;
grant execute on function public.finish_routine_ai_call(text, text)
  to service_role;
