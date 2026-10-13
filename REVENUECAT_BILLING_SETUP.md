# RevenueCat Billing Setup

Last updated: 10 October 2026

## Agreed UK launch prices

Personal Premium is **£1.79 per month or £14.99 per year**, agreed on
10 October 2026. The annual plan is about £1.25 per month, paid yearly,
and saves 30% compared with twelve monthly payments (£21.48).

The app reads the store's localised price through RevenueCat for the plan
cards, purchase button and renewal disclosure. It calculates the annual
monthly equivalent from that price. There is no fixed discount percentage
in the app and no hard-coded GBP fallback when the store is unavailable.
Changing a screenshot example or this document does not change billing.

**Store setup remains pending.** Live prices were not verified in this sweep.
Earlier launch notes recorded £0.89 / £6.49; those are historical observations,
not confirmation of today's store configuration.

Before release:

1. In Google Play Console, set the UK prices for `personal_premium` base plans
   `monthly` and `yearly` to £1.79 and £14.99 respectively.
2. In App Store Connect, set the matching UK monthly and annual subscriptions
   to the same prices. Review existing subscriber treatment separately rather
   than automatically moving existing subscribers to a higher price.
3. Confirm RevenueCat's current offering maps to those products. Keep other
   regions' localised prices supplied by their stores; GBP is the UK price.
4. On Android and iOS, check both plan cards, the £1.25/month annual equivalent,
   the purchase button and renewal disclosure. Open each native purchase sheet
   and verify its price and billing period match, then cancel the test checkout.

The screenshot harness uses the agreed UK prices. Paywall tests cover both
these prices and other store-provided currencies.

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

Signed-out users can start checkout and restore purchases. RevenueCat may use an
anonymous App User ID for local Premium.

When a user signs in for backup or account recovery, the app calls
`Purchases.logIn(userId)` with the Supabase user ID so RevenueCat can connect
the anonymous customer to the Pebble account. Do not use email addresses as
RevenueCat IDs.

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
