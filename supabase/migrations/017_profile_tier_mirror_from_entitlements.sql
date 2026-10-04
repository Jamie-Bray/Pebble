-- profiles.tier is a mirror of personal_entitlements, never a source of truth.
--
-- RLS (has_active_personal_entitlement) and the app both read
-- personal_entitlements directly. profiles.tier was only written by edge
-- functions after a successful webhook/sync, so it went stale whenever an
-- EXPIRATION webhook failed (two production profiles still read
-- personalPremium after their periods ended on 2026-08-12) and it can never
-- notice a period simply running out.
--
-- This migration derives the tier inside the database:
--   1. entitled_profile_tier(uuid): the tier the entitlement rows grant now.
--      Mirrors profileTierForEntitlements() in
--      supabase/functions/_shared/revenuecat.ts.
--   2. A trigger on personal_entitlements refreshes the owner's tier on every
--      insert/update/delete (old and new owner).
--   3. reconcile_profile_tiers() fixes every drifted profile; it runs once
--      here (backfill) and daily via pg_cron, which catches periods that end
--      without any webhook.
--   4. The tier guard also lets the database owner (definer functions, cron)
--      change tier. API callers still cannot: authenticated requests run as
--      'authenticated', and only service_role requests were already allowed.

create or replace function public.entitled_profile_tier(target_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when bool_or(e.entitlement_tier = 'pebbleHousehold') then 'pebbleHousehold'
    when bool_or(e.entitlement_tier = 'personalPremium') then 'personalPremium'
    else 'personalFree'
  end
  from public.personal_entitlements e
  where e.owner_user_id = target_user_id
    and e.status in ('active', 'grace', 'cancelled_active')
    and (e.period_ends_at is null or e.period_ends_at > now());
$$;

create or replace function public.refresh_profile_tier(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_tier text := public.entitled_profile_tier(target_user_id);
begin
  update public.profiles p
  set tier = next_tier,
      updated_at = now()
  where p.id = target_user_id
    and p.tier is distinct from next_tier;
end;
$$;

create or replace function public.reconcile_profile_tiers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed integer;
begin
  update public.profiles p
  set tier = public.entitled_profile_tier(p.id),
      updated_at = now()
  where p.tier is distinct from public.entitled_profile_tier(p.id);
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create or replace function public.tg_personal_entitlements_refresh_profile_tier()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_profile_tier(old.owner_user_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op = 'INSERT' or new.owner_user_id is distinct from old.owner_user_id
          or new.status is distinct from old.status
          or new.period_ends_at is distinct from old.period_ends_at
          or new.entitlement_tier is distinct from old.entitlement_tier) then
    perform public.refresh_profile_tier(new.owner_user_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_personal_entitlements_refresh_profile_tier
  on public.personal_entitlements;
create trigger trg_personal_entitlements_refresh_profile_tier
after insert or update or delete on public.personal_entitlements
for each row execute function public.tg_personal_entitlements_refresh_profile_tier();

-- Guard: allow tier changes from service_role requests (edge functions, as
-- before) and from the database owner (the definer functions above, pg_cron).
-- Client requests run as 'authenticated' and are still blocked.
create or replace function public.guard_profile_tier_client_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or current_user = 'postgres' then
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

-- None of these are API surface.
revoke execute on function public.entitled_profile_tier(uuid) from public, anon, authenticated;
revoke execute on function public.refresh_profile_tier(uuid) from public, anon, authenticated;
revoke execute on function public.reconcile_profile_tiers() from public, anon, authenticated;
revoke execute on function public.tg_personal_entitlements_refresh_profile_tier() from public, anon, authenticated;
grant execute on function public.refresh_profile_tier(uuid) to service_role;
grant execute on function public.reconcile_profile_tiers() to service_role;

-- One-off backfill: fixes profiles already stuck on a lapsed tier.
select public.reconcile_profile_tiers();

-- Daily reconcile at 02:20 UTC (after cleanup-proof-retention at 02:00).
-- cron.schedule upserts by job name, so re-running is safe. Skipped where
-- pg_cron is not installed (local stacks).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'reconcile-profile-tiers-daily',
      '20 2 * * *',
      'select public.reconcile_profile_tiers();'
    );
  end if;
end;
$$;
