-- Remove the pre-store entitlement bridge before Play testing.
-- Premium/cloud write access must come only from verified Google Play
-- entitlement records written by the verify-purchase Edge Function.

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

create or replace function public.has_personal_cloud_write_access(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.has_current_cloud_backup_consent(user_id)
    and public.has_active_personal_entitlement(user_id);
$$;
