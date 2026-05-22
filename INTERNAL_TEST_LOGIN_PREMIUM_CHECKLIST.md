# Internal Test Login + Premium Checklist

Use this checklist before uploading an AAB for Google Play internal testing.

## App Build

- Build with `APP_ENV=production`.
- Provide production Supabase dart defines:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_GOOGLE_WEB_CLIENT_ID`
- The local build helper reads these from:
  - `PEBBLE_PROD_SUPABASE_URL`
  - `PEBBLE_PROD_SUPABASE_ANON_KEY`
  - `PEBBLE_PROD_GOOGLE_WEB_CLIENT_ID`
- If `PEBBLE_PROD_GOOGLE_WEB_CLIENT_ID` is missing, Google sign-in will be hidden/unavailable in the AAB.

## Google Play Console

- Internal tester Gmail is added to the internal testing track.
- The same Gmail is added under Settings > License testing.
- Subscription product exists and is active:
  - Product ID: `personal_premium`
  - Base plan ID: `monthly`
  - Base plan ID: `yearly`
- The AAB is installed from the Play internal testing link, not a sideloaded random build.

## Supabase

- Google provider is enabled for Auth.
- OAuth config includes the release/Play App Signing certificate fingerprints required by Google sign-in.
- Migrations are deployed to the target Supabase project.
- `verify-purchase` is deployed with:
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
  - `SUPABASE_SERVICE_ROLE_KEY`

## Smoke Test

- Google sign-in appears and completes.
- Premium product loads from Google Play with the monthly and yearly base-plan prices.
- License tester can complete checkout with a test payment method.
- Supabase `verify-purchase` verifies the token and writes entitlement.
- Personal Premium unlocks routine limits, premium themes, guidance audio, and extra proof photos.
- Backup still requires signed-in + paid entitlement + cloud backup consent.

## Known Follow-Up

For this internal-test pass, checkout requires sign-in first because purchase verification stores the entitlement against a Supabase user. Later, decouple non-cloud Premium from account backup so users can buy Premium first and sign in only when they want backup/restore.
