-- Keep the database write-access gate aligned with the current in-app
-- cloud-backup consent text.

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
      and c.privacy_version = '2026-05-04'
      and c.terms_version = '2026-05-04'
      and c.consent_text_hash =
        '447b66766fb90e5225c8eec970f296939ecd3568ebdb7287b0b62af8d7796744'
  );
$$;
