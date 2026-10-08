-- Prepared only; not applied. Follow supabase/DEPLOY_PLAN.md before deployment.
-- The privacy policy and terms were updated on 8 October 2026: every plan now
-- keeps 21 days of history on the device and Free shows the last 48 hours.
-- The app records the new dates with each backup consent. The gate accepts
-- consents given under the 5 October pages too, so builds made before this
-- change keep backing up while they are still installed.

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
      and c.privacy_version in ('2026-10-05', '2026-10-08')
      and c.terms_version in ('2026-10-05', '2026-10-08')
      and c.consent_text_hash =
        '19e2a2c7f63deef9320b02fe2e5950245a1ff4c08259af5551f0a76058d27e4f'
  );
$$;
