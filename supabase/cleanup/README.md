# Proof Retention Cleanup

Pebble proof photos are retained in cloud storage for a rolling 21-day window.
The deployable cleanup job is:

- `supabase/functions/cleanup-proof-retention/index.ts`

It is intentionally idempotent. It can be retried safely because it:

- removes expired `routine-proofs` storage objects
- deletes matching `proof_asset_usage` metadata rows
- deletes orphaned storage objects older than 21 days that have no metadata row
- deletes metadata rows whose storage object is already missing

## Deploy

```bash
supabase functions deploy cleanup-proof-retention
```

The scheduler secret is **required**. The function is deployed with
`verify_jwt = false`, so it refuses to run (HTTP 503) when
`CLEANUP_PROOF_RETENTION_SECRET` is unset or blank, and returns 401 unless the
`x-cleanup-secret` header matches (constant-time compare). The value must equal
the Vault secret `cleanup-proof-retention-header` that the
`cleanup-proof-retention-daily` cron job sends:

```bash
supabase secrets set CLEANUP_PROOF_RETENTION_SECRET=replace-with-secret
```

Step voice prompts (`users/<uid>/guidance_audio/...`, `proof_asset_usage`
rows with `entity_type = 'guidance_audio'`) share the bucket but are never
touched by this job.

## Schedule

Run once per day from Supabase Scheduled Functions, Supabase Cron, or an
external scheduler:

```bash
curl -X POST \
  -H "x-cleanup-secret: replace-with-secret" \
  https://<project-ref>.functions.supabase.co/cleanup-proof-retention
```

## Retention Metadata

New proof metadata should use a 21-day `expires_at`. If an older migration or
database default still says 30 days, run:

```sql
alter table public.proof_asset_usage
  alter column expires_at set default (now() + interval '21 days');
```

The cleanup function also enforces 21 days from `created_at`, so stale 30-day
metadata is still cleaned before release.
