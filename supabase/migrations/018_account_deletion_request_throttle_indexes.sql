-- Indexes for the request-account-deletion throttle (per IP hash per hour,
-- global per hour). The per-email lookup already uses
-- account_deletion_requests_email_status_idx (normalized_email, status,
-- created_at desc). The function works without these indexes; they only keep
-- the throttle cheap if the public form is flooded.

create index if not exists account_deletion_requests_ip_created_idx
  on public.account_deletion_requests (request_ip_hash, created_at desc)
  where request_ip_hash is not null;

create index if not exists account_deletion_requests_created_idx
  on public.account_deletion_requests (created_at desc);

-- Defence in depth for the limits the function enforces.
alter table public.account_deletion_requests
  drop constraint if exists account_deletion_requests_length_check;
alter table public.account_deletion_requests
  add constraint account_deletion_requests_length_check check (
    char_length(email) <= 254
    and char_length(normalized_email) <= 254
    and (message is null or char_length(message) <= 2000)
    and (user_agent is null or char_length(user_agent) <= 512)
  ) not valid;
