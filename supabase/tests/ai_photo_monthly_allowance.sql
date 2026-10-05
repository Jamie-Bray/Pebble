-- Run after migrations 021 and 023 in a disposable PostgreSQL database.
-- Everything, including test users, is rolled back. Never run on production.
begin;
insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000101'),
  ('00000000-0000-0000-0000-000000000102');
do $$
declare
  u uuid := '00000000-0000-0000-0000-000000000101';
  other uuid := '00000000-0000-0000-0000-000000000102';
  a jsonb;
  n integer;
begin
  assert not has_function_privilege('authenticated', 'public.get_ai_photo_allowance(uuid)', 'execute');
  assert not has_function_privilege('anon', 'public.reserve_ai_photo_description(uuid,text,integer,integer)', 'execute');
  assert has_function_privilege('service_role', 'public.get_ai_photo_allowance(uuid)', 'execute');
  assert not has_table_privilege('authenticated', 'public.ai_photo_requests', 'select');
  assert public.get_ai_photo_allowance(u)->>'remaining' = '100';
  -- Seed earlier requests in this month, including ones outside the daily window.
  insert into public.ai_photo_requests(owner_user_id, idempotency_key, created_at)
    select u, 'monthly-' || lpad(i::text, 4, '0'),
      date_trunc('month', timezone('utc', now())) at time zone 'UTC'
      from generate_series(1, 99) i;
  -- An older month does not count; very old rows are pruned lazily.
  insert into public.ai_photo_requests values (u, 'old-month', now() - interval '40 days');
  assert public.reserve_ai_photo_description(u, 'last-one', 200, 5000) = 'ok';
  assert public.reserve_ai_photo_description(u, 'last-one', 200, 5000) = 'duplicate';
  assert public.reserve_ai_photo_description(u, 'over-cap', 200, 5000) = 'monthly_limit';
  assert not exists(select 1 from public.ai_photo_requests where idempotency_key = 'old-month');
  a := public.get_ai_photo_allowance(u);
  assert a->>'used' = '100' and a->>'remaining' = '0';
  assert (a->>'resetsAt')::timestamptz =
    (date_trunc('month', timezone('utc', now())) + interval '1 month') at time zone 'UTC';
  assert public.get_ai_photo_allowance(other)->>'remaining' = '100';
  select requests into n from public.ai_photo_budget
    where month = date_trunc('month', timezone('utc', now()))::date;
  assert n = 1; -- Duplicate/refusal did not spend global budget.
  assert public.reserve_ai_photo_description(other, 'other-one', 1, 5000) = 'ok';
  assert public.reserve_ai_photo_description(other, 'other-two', 1, 5000) = 'daily_limit';
  assert public.reserve_ai_photo_description(other, 'global-limit', 200, 2) = 'budget_exhausted';
  assert public.get_ai_photo_allowance(other)->>'remaining' = '99';
  -- Withdrawal/re-consent cannot reset an account's allowance.
  insert into public.ai_photo_consents(owner_user_id, consent_version, provider, consented_at)
    values (other, 'test', 'test', now());
  update public.ai_photo_consents set withdrawn_at = now() where owner_user_id = other;
  assert public.get_ai_photo_allowance(other)->>'remaining' = '99';
end $$;
rollback;
