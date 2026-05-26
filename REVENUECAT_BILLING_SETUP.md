# RevenueCat Billing Setup

Last updated: May 22, 2026

Pebble now uses RevenueCat for store purchases on Android and iOS. Supabase
remains the backend source of truth for cloud-backup permissions, retention, and
account recovery.

## Ownership Boundary

RevenueCat is the billing and store-entitlement authority. The Flutter app may
unlock local Premium features immediately from RevenueCat `CustomerInfo`.

Supabase is the cloud-access mirror. Cloud backup, restore, proof-photo upload,
retention, and any server-protected feature must require a
`personal_entitlements` row written by the RevenueCat webhook. The app should
show local Premium while cloud backup says verification is finishing if the
webhook has not arrived yet.

Do not reintroduce client-submitted store receipt verification for new
RevenueCat purchases. Keep `verify-purchase` only as a legacy/fallback path
unless the RevenueCat migration is deliberately rolled back.

## RevenueCat Products

Create one RevenueCat entitlement:

- Entitlement ID: `personal_premium`

Attach packages for the current offering:

- Monthly package mapped to the store subscription/base plan for monthly Premium.
- Annual package mapped to the store subscription/base plan for yearly Premium.

The app recognizes RevenueCat monthly and annual package types, and also falls
back to product/package identifiers containing `monthly`, `yearly`, `p1m`, or
`p1y`.

## Store Products

Google Play:

- Product ID: `personal_premium`
- Base plan ID: `monthly`
- Base plan ID: `yearly`

App Store Connect:

- Create a subscription group for Pebble Premium.
- Add matching monthly and yearly auto-renewable subscriptions.
- Connect the App Store products to the RevenueCat entitlement/packages.
- Add the App Store Connect API key in the RevenueCat dashboard.

The iOS project now has a Podfile, a minimum iOS target of 13.0, and the
In-App Purchase capability enabled in the Xcode project.

## Flutter Defines

Provide RevenueCat SDK keys at build/run time:

```powershell
flutter run `
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_... `
  --dart-define=REVENUECAT_IOS_API_KEY=appl_... `
  --dart-define=REVENUECAT_ENTITLEMENT_ID=personal_premium
```

`REVENUECAT_ENTITLEMENT_ID` defaults to `personal_premium` if omitted. Production
builds require at least one platform API key.

## Supabase Webhook

Deploy:

```powershell
supabase functions deploy revenuecat-webhook
```

Set a shared webhook secret:

```powershell
supabase secrets set REVENUECAT_WEBHOOK_SECRET="your-long-random-token"
```

In RevenueCat, configure the webhook URL to the deployed Supabase Edge Function
and set its Authorization header value to the same token. The function accepts
either a raw token or `Bearer your-long-random-token`, validates the app user ID
as a Supabase UUID, upserts `personal_entitlements`, and updates
`profiles.tier`.

## App Identity

RevenueCat is configured with the Supabase user ID as the RevenueCat App User
ID. Do not use email addresses as RevenueCat IDs.

Signed-out users cannot start checkout. Restore/sync runs after sign-in so the
RevenueCat customer can be linked to the active Supabase account.

Set RevenueCat restore behavior to match Pebble's account policy. If a store
purchase must belong to only one Pebble account, RevenueCat should keep
purchases with the original App User ID instead of silently transferring them.
Supabase also enforces one active store purchase claim per account mirror.

## Validation Checklist

1. Run `flutter analyze`.
2. Run the subscription tests:

   ```powershell
   flutter test test\features\subscription\revenuecat_purchase_repository_test.dart test\features\subscription\pebble_paywall_test.dart test\features\subscription\subscription_lifecycle_test.dart
   ```

3. Android sandbox: load monthly/yearly products, purchase, restore, cancel, and
   confirm Supabase receives the webhook.
4. iOS sandbox: repeat product load, purchase, restore, cancellation, and
   expiration checks from an App Store sandbox account.
5. Confirm cloud backup remains blocked until Supabase has a server-verified
   active entitlement, even if the local RevenueCat entitlement unlocks Premium
   UI immediately.
