-- Prepared only; not applied. Follow supabase/DEPLOY_PLAN.md before deployment.
-- Keep the database write-access gate aligned with the in-app cloud-backup
-- consent text, which now names voice tip recordings, and with the privacy
-- and terms dates recorded with each consent.

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
      and c.privacy_version = '2026-10-05'
      and c.terms_version = '2026-10-05'
      and c.consent_text_hash =
        '19e2a2c7f63deef9320b02fe2e5950245a1ff4c08259af5551f0a76058d27e4f'
  );
$$;
