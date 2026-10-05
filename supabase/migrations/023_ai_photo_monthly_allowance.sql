-- Personal Premium: 200 AI requests per UTC calendar month per account.
-- NOT APPLIED. Apply after 021, before enabling AI. No photos/descriptions
-- are stored here. Preserve the existing four-argument RPC for older workers.

create or replace function public.reserve_ai_photo_description(
  p_user_id uuid, p_idempotency_key text,
  p_daily_limit integer, p_monthly_limit integer
)
returns text language plpgsql security definer set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_start timestamptz := v_month::timestamp at time zone 'UTC';
  v_used integer;
  v_counted integer;
begin
  if p_user_id is null or p_idempotency_key is null
     or p_daily_limit is null or p_monthly_limit is null then
    return 'budget_exhausted';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 21));
  if exists (select 1 from public.ai_photo_requests
             where owner_user_id = p_user_id and idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  -- Keep this month's rows for the monthly allowance and the last two days
  -- across month boundaries for daily allowance/idempotency. Prune lazily.
  delete from public.ai_photo_requests where owner_user_id = p_user_id
    and created_at < least(v_start, now() - interval '2 days');

  select count(*) into v_used from public.ai_photo_requests
    where owner_user_id = p_user_id and created_at >= v_start;
  if v_used >= 200 then return 'monthly_limit'; end if;

  select count(*) into v_used from public.ai_photo_requests
    where owner_user_id = p_user_id and created_at > now() - interval '24 hours';
  if v_used >= p_daily_limit then return 'daily_limit'; end if;

  insert into public.ai_photo_budget (month) values (v_month) on conflict (month) do nothing;
  update public.ai_photo_budget set requests = requests + 1, updated_at = now()
    where month = v_month and requests < p_monthly_limit;
  get diagnostics v_counted = row_count;
  if v_counted = 0 then return 'budget_exhausted'; end if;

  insert into public.ai_photo_requests (owner_user_id, idempotency_key)
    values (p_user_id, p_idempotency_key);
  return 'ok';
end;
$$;

revoke all on function public.reserve_ai_photo_description(uuid, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_ai_photo_description(uuid, text, integer, integer)
  to service_role;

-- Only the authenticated Edge Function reads the caller's own allowance.
create or replace function public.get_ai_photo_allowance(p_user_id uuid)
returns jsonb language sql security definer set search_path = public
as $$
  with period as (
    select date_trunc('month', timezone('utc', now())) at time zone 'UTC' as start
  ), usage as (
    select count(*)::integer as used from public.ai_photo_requests, period
    where owner_user_id = p_user_id and created_at >= period.start
  )
  select jsonb_build_object(
    'limit', 200, 'used', used, 'remaining', greatest(0, 200 - used),
    'resetsAt', (period.start at time zone 'UTC' + interval '1 month') at time zone 'UTC'
  ) from usage, period;
$$;
revoke all on function public.get_ai_photo_allowance(uuid) from public, anon, authenticated;
grant execute on function public.get_ai_photo_allowance(uuid) to service_role;
