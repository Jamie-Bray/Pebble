-- The 9 October privacy page names AI routine building and step notes in
-- completion emails. Accept the new backup-consent version while preserving
-- access for older installed builds that recorded the 5 or 8 October pages.
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
      and c.privacy_version in ('2026-10-05', '2026-10-08', '2026-10-09')
      and c.terms_version in ('2026-10-05', '2026-10-08')
      and c.consent_text_hash =
        '19e2a2c7f63deef9320b02fe2e5950245a1ff4c08259af5551f0a76058d27e4f'
  );
$$;
