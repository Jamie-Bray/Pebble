## Supabase Ops (Personal Premium)

This folder is the scripted source of truth for Pebble cloud setup.

### Naming conventions
- Projects: `pebble-staging`, `pebble-prod`
- Bucket: `routine-proofs` (private)
- Storage path: `users/{userId}/{entityType}/{entityId}/{proofId}.{ext}`
- Cloud ownership column: `owner_user_id`
- Sync key on local rows: `cloud_id`

### Required environment variables
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_STAGING_PROJECT_REF`
- `SUPABASE_STAGING_DB_PASSWORD`
- `SUPABASE_PROD_PROJECT_REF`
- `SUPABASE_PROD_DB_PASSWORD`

### One-time machine setup
```powershell
npm i -g supabase
supabase --version
```

### Push migrations to staging
```powershell
powershell -ExecutionPolicy Bypass -File .\supabase\scripts\push-staging.ps1
```

### Push migrations to production
```powershell
powershell -ExecutionPolicy Bypass -File .\supabase\scripts\push-prod.ps1
```

### Notes
- Scripts are idempotent and safe to re-run.
- Use staging first for every schema/policy change.
- Do not hand-edit schema in Dashboard unless immediately codified as a migration.
- Personal Premium entitlement truth lives in `personal_entitlements`, written by the `verify-purchase` Edge Function after Google Play verification.
- The active Google Play subscription product ids are `personal_premium_monthly` and `household_monthly`.
- Routine metadata remains readable by the account owner after cancellation, but cloud inserts/updates and proof-photo uploads require an active/grace/cancelled-active entitlement.
- Migration `005_cloud_backup_consent_and_deletion_requests.sql` adds the cloud-backup consent record and makes cloud writes require current consent as well as entitlement.
- Migration `007_remove_pre_store_entitlement_bridge.sql` removes the old profile-tier bridge, so cloud writes can no longer be unlocked by `profiles.tier`.
- Deploy `request-account-deletion` with the same Supabase env vars as `delete-account`; the public deletion page form depends on it.
- Fair use is proof-media only: no camera-roll scanning, no video backup at launch, 1 GB active proof-photo storage, 500 proof-photo uploads per rolling 30 days, and 21-day cloud photo retention.
- Google Play launch wiring needs `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, and `SUPABASE_SERVICE_ROLE_KEY` set on the Edge Function.
