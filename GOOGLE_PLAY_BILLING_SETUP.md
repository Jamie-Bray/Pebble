# Google Play Billing Setup

Last updated: May 22, 2026

Pebble now uses RevenueCat as the app billing SDK and entitlement bridge. Keep
this file for the Google Play product setup details, but use
`REVENUECAT_BILLING_SETUP.md` for the current end-to-end billing checklist.

## Product IDs

The app currently expects one subscription product:

- Product ID: `personal_premium`

Create these base plans under that subscription:

- Base plan ID: `monthly`
- Base plan ID: `yearly`

The app will show a plan as unavailable until Google Play returns that base
plan with a valid offer token.

## Production Package Name

The Android application id is:

```text
com.vix.pebble_routines
```

This has already been set in Supabase as `GOOGLE_PLAY_PACKAGE_NAME`.

## Legacy Server Verification

The old direct Google Play verification function remains in:

```text
supabase/functions/verify-purchase/index.ts
```

RevenueCat webhooks now provide the primary entitlement path. The legacy
function uses Google Play Developer API `purchases.subscriptionsv2.get`, so it
still requires a Google service account JSON if you keep or test the old direct
verification route.

Required Supabase secret still missing:

```text
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
```

## Play Console Steps

1. In Play Console, finish app setup enough that monetization/subscriptions are available.
2. Create the subscription product `personal_premium`.
3. Add base plans `monthly` and `yearly`, then make them available for the testing countries you need.
4. Set up Play Console API access and a Google Cloud service account for purchase verification.
5. Grant the service account access to this app with permission to manage or view orders/subscriptions.
6. Download the service account JSON key to your local machine.
7. Do not paste the JSON into chat or commit it.

## Set The Supabase Secret

After downloading the JSON key locally, run:

```powershell
.\supabase\scripts\set-prod-google-play-secret.ps1 `
  -ServiceAccountJsonPath "C:\path\to\google-play-service-account.json"
```

The script:

- reads the JSON locally
- checks it contains `client_email` and `private_key`
- sets `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` in production Supabase
- redeploys `verify-purchase`
- deletes its temporary env file

## Current Supabase State

Already set:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `CLEANUP_PROOF_RETENTION_SECRET`

Still needed:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

## Verification After Setup

After Play products and the service account secret are configured:

1. Upload the signed production AAB to an internal/closed testing track.
2. Add a license tester.
3. Install from Play, not `flutter run`.
4. Open Premium.
5. Confirm Google Play returns `personal_premium` with base plans `monthly` and `yearly`.
6. Start a test purchase.
7. Confirm Supabase writes a row in `personal_entitlements`.
8. Confirm Account shows Premium active and backup setup can continue.

Official references:

- Google Play Developer API getting started: `https://developers.google.com/android-publisher/getting_started`
- Subscriptions purchase verification API: `https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2`
- Play subscriptions setup: `https://support.google.com/googleplay/android-developer/answer/140504`
