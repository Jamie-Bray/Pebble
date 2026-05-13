-- Run before release if the deployed database was created from older
-- migrations where proof_asset_usage.expires_at defaulted to 30 days.
alter table public.proof_asset_usage
  alter column expires_at set default (now() + interval '21 days');
