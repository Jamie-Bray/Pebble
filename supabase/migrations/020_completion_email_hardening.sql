-- Completion emails ("shared alerts"): close direct-write holes, support the
-- new link and abuse rules in the Edge Functions, and add retention.
-- See COMPLETION_EMAIL_REVIEW.md. Additive and safe to run before or after the
-- function deploy: the currently deployed functions keep working.

-- ---------------------------------------------------------------------------
-- 1. The app must not write these tables directly.
--
-- Migration 006/008 let a signed-in Premium user INSERT/UPDATE their own
-- shared_alert_contacts and shared_alert_invites rows through the REST API.
-- That allowed setting status = 'accepted' (or swapping recipient_email on an
-- accepted contact) without the recipient's consent, then calling
-- send-routine-completion-alert to email anyone. All writes now go through
-- the Edge Functions, which use the service role.
--
-- Only privileges are revoked; the old policies stay so that migration 014
-- (which alters them) still applies in either order. Without the privilege a
-- policy grants nothing.
-- ---------------------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger
  on table public.shared_alert_contacts from anon, authenticated;
revoke all on table public.shared_alert_invites from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on table public.shared_alert_blocks from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on table public.shared_alert_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Link tokens know what they are for and who they were sent to.
--    purpose 'invite' = Allow / Decline / Block in an invitation (14 days)
--    purpose 'manage' = Stop / Block in a completion email (90 days)
-- An Allow link only works if it was sent to the contact's current address.
-- ---------------------------------------------------------------------------
alter table public.shared_alert_invites
  add column if not exists purpose text not null default 'invite',
  add column if not exists recipient_email_hash text null,
  add column if not exists owner_user_id uuid null references auth.users(id) on delete cascade;

alter table public.shared_alert_invites
  drop constraint if exists shared_alert_invites_purpose_check;
alter table public.shared_alert_invites
  add constraint shared_alert_invites_purpose_check check (purpose in ('invite', 'manage'));

-- Backfill: completion-email tokens were the ones issued for 90 days.
update public.shared_alert_invites i
set
  purpose = case when i.expires_at - i.created_at > interval '30 days' then 'manage' else 'invite' end,
  recipient_email_hash = coalesce(i.recipient_email_hash, c.recipient_email_hash),
  owner_user_id = coalesce(i.owner_user_id, c.owner_user_id)
from public.shared_alert_contacts c
where c.id = i.contact_id
  and (i.recipient_email_hash is null or i.owner_user_id is null);

create index if not exists shared_alert_invites_owner_purpose_created_idx
  on public.shared_alert_invites (owner_user_id, purpose, created_at desc);
create index if not exists shared_alert_invites_recipient_purpose_created_idx
  on public.shared_alert_invites (recipient_email_hash, purpose, created_at desc);
create index if not exists shared_alert_invites_expires_idx
  on public.shared_alert_invites (expires_at);

-- ---------------------------------------------------------------------------
-- 3. Declines: a time-limited row in shared_alert_blocks stops the same
--    sender re-inviting for 30 days. Permanent blocks keep expires_at null.
-- ---------------------------------------------------------------------------
alter table public.shared_alert_blocks
  add column if not exists expires_at timestamptz null;

alter table public.shared_alert_blocks
  drop constraint if exists shared_alert_blocks_reason_check;
alter table public.shared_alert_blocks
  add constraint shared_alert_blocks_reason_check
  check (reason in ('recipient_blocked', 'recipient_declined')) not valid;

-- ---------------------------------------------------------------------------
-- 4. Global opt-out: "Block all Pebble invitations to this address".
--    Not linked to any account, so it survives a sender deleting theirs.
--    Stores only the SHA-256 of the normalised address.
-- ---------------------------------------------------------------------------
create table if not exists public.shared_alert_suppressions (
  recipient_email_hash text primary key,
  source text not null default 'recipient_link',
  created_at timestamptz not null default now()
);

alter table public.shared_alert_suppressions enable row level security;
revoke all on table public.shared_alert_suppressions from anon, authenticated;
grant all privileges on table public.shared_alert_suppressions to service_role;

-- ---------------------------------------------------------------------------
-- 5. Events: retry counter and an index for the per-contact send cap.
-- ---------------------------------------------------------------------------
alter table public.shared_alert_events
  add column if not exists attempts integer not null default 1;

create index if not exists shared_alert_events_contact_status_created_idx
  on public.shared_alert_events (contact_id, status, created_at desc);

-- Defence in depth for the limits the functions enforce.
alter table public.shared_alert_events
  drop constraint if exists shared_alert_events_size_check;
alter table public.shared_alert_events
  add constraint shared_alert_events_size_check check (
    char_length(routine_title) <= 200
    and char_length(run_id) <= 100
    and completed_steps <= total_steps
    and total_steps <= 1000
  ) not valid;

-- ---------------------------------------------------------------------------
-- 6. Retention (privacy policy: sent-email log kept 90 days).
--    - link tokens: deleted 7 days after they expire
--    - completion-email log: deleted after 90 days
--    - expired decline cooldowns: deleted
--    - removed / declined / blocked contacts: deleted after 90 days without
--      change (a block itself lives on in shared_alert_blocks)
-- ---------------------------------------------------------------------------
create or replace function public.prune_shared_alert_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  tokens_deleted integer;
  events_deleted integer;
  declines_deleted integer;
  contacts_deleted integer;
begin
  delete from public.shared_alert_invites
  where expires_at < now() - interval '7 days';
  get diagnostics tokens_deleted = row_count;

  delete from public.shared_alert_events
  where created_at < now() - interval '90 days';
  get diagnostics events_deleted = row_count;

  delete from public.shared_alert_blocks
  where expires_at is not null and expires_at < now();
  get diagnostics declines_deleted = row_count;

  delete from public.shared_alert_contacts
  where status in ('disabled', 'declined', 'blocked')
    and updated_at < now() - interval '90 days';
  get diagnostics contacts_deleted = row_count;

  return jsonb_build_object(
    'tokens', tokens_deleted,
    'events', events_deleted,
    'declines', declines_deleted,
    'contacts', contacts_deleted
  );
end;
$$;

revoke all on function public.prune_shared_alert_data() from public, anon, authenticated;
grant execute on function public.prune_shared_alert_data() to service_role;

-- Daily at 02:40 UTC (after cleanup-proof-retention 02:00 and the tier
-- reconcile 02:20). cron.schedule upserts by job name. Skipped where pg_cron
-- is not installed (local stacks).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'prune-shared-alert-data-daily',
      '40 2 * * *',
      'select public.prune_shared_alert_data();'
    );
  end if;
end;
$$;
