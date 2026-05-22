# Retrospective PRD: Google Play Premium Readiness

**Product:** Pebble Routines  
**Date:** 10 May 2026  
**Status:** Implemented for internal testing readiness, pending external Play Console and Supabase secret configuration

## 1. Summary

Pebble was prepared for a production-safe Google Play internal testing build by removing local Premium bypass paths, making entitlement depend on real Google Play purchase verification, and renaming the paid personal tier to **Personal Premium**.

The final product rule is:

Google Play purchase -> Supabase `verify-purchase` Edge Function -> verified entitlement record -> app reads entitlement.

Anything else behaves as Free.

## 2. Problem

Before this work, Pebble had development-era entitlement behavior that made Premium access too easy to grant locally. That was useful during early development, but unsafe for a Play Console internal testing build because a release candidate could accidentally include:

- local purchase repositories
- debug Premium switches
- staging-only entitlement bypasses
- hardcoded Premium defaults
- fake purchase success
- app-side entitlement grants

The naming also drifted: parts of the code and documentation used an older paid-tier label, while the intended product name is **Personal Premium**.

Separately, the Home hero had become too compact after accessibility-related layout work. The intended design is a confident, spacious hero that still behaves correctly with large device text settings.

## 3. Goals

- Premium exists only after server-verified Google Play purchase.
- Failed billing, failed verification, cancellation, missing product IDs, unknown entitlement, and offline-without-cache all behave as Free.
- Auth, entitlement, and cloud access remain separate concepts.
- The app uses the final user-facing name **Personal Premium** everywhere.
- Google Play product IDs are explicit and match the entitlement backend.
- The Home hero remains visually confident while avoiding overflow with large accessibility text.
- Release readiness is easy to audit after the fact.

## 4. Non-Goals

- This work did not complete Play Console setup.
- This work did not create or activate Play Console subscription products.
- This work did not deploy Supabase Edge Function secrets.
- This work did not run a real-device purchase smoke test.
- This work did not alter the core pricing model beyond renaming the personal paid tier.

## 5. Product Decisions

### 5.1 Entitlement Authority

The Flutter app cannot award Premium locally. It can only:

- start the Google Play purchase flow
- restore/query Google Play purchases
- send purchase details to Supabase for verification
- read the resulting entitlement state
- cache previously verified entitlement safely

The server is the authority for Premium.

### 5.2 Tier Naming

The personal paid tier is **Personal Premium**.

Canonical naming:

- `UserTier.personalPremium`
- `EntitlementStatus.personalPremium`
- `PebbleProductIds.personalPremium`
- Google Play product ID: `personal_premium`
- Google Play base plan IDs: `monthly`, `yearly`

### 5.3 Cloud Access Separation

Signing in does not mean Premium.

Premium does not automatically mean cloud backup.

Cloud backup requires:

- signed in
- verified paid entitlement
- cloud-backup consent

Local Free usage remains available without sign-in.

### 5.4 Accessibility Hero Behavior

The Home hero should keep its spacious default layout on normal devices. Compact hero behavior is reserved for large text settings or genuinely short available height.

Large accessibility text is handled inside the hero with bounded scaling and layout fallback, rather than shrinking the whole experience by default.

## 6. Implementation Summary

### 6.1 Premium Entitlement

Implemented and verified:

- Removed app-side Premium bypass paths.
- Google Play purchase and restore paths route through the purchase repository.
- Purchase success triggers Supabase `verify-purchase`.
- Failed verification does not unlock Premium.
- Unknown entitlement does not unlock Premium.
- Expired/cancelled entitlement maps back away from paid access.
- Store unavailable and missing product IDs show recoverable unavailable states.
- Product loading does not silently grant Premium.

Primary files:

- `lib/features/subscription/data/purchase_repository.dart`
- `lib/features/subscription/data/google_play_purchase_repository.dart`
- `lib/features/subscription/providers/subscription_provider.dart`
- `lib/features/subscription/providers/cloud_access_provider.dart`
- `lib/features/subscription/data/models/cloud_access_state.dart`
- `lib/features/subscription/domain/user_tier.dart`
- `lib/features/subscription/ui/pebble_paywall.dart`
- `supabase/functions/verify-purchase/index.ts`

### 6.2 Personal Premium Rename

Renamed the paid personal tier to Premium in app code, tests, Supabase function code, and documentation.

Important final product ID:

```text
personal_premium
```

Play Console must use this exact subscription product ID with base plans `monthly` and `yearly` unless the app and backend are intentionally changed together.

### 6.3 Runtime Environment

The runtime environment is explicit through `APP_ENV`.

Expected values:

```text
APP_ENV=staging
APP_ENV=production
```

Production builds require production Supabase configuration and real billing entitlement behavior.

Primary file:

- `lib/core/config/app_runtime_config.dart`

### 6.4 Supabase Verification

The `verify-purchase` function verifies purchase tokens server-side and writes entitlement records.

Required Supabase secrets before live Play testing:

```text
GOOGLE_PLAY_PACKAGE_NAME
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
SUPABASE_SERVICE_ROLE_KEY
```

Primary files:

- `supabase/functions/verify-purchase/index.ts`
- `supabase/README.md`

### 6.5 Home Hero Accessibility Repair

Updated the Home hero to:

- stay spacious by default
- enter compact mode only for large text or very short height
- cap local hero text scaling
- use a scale-down fallback to prevent overflow
- hide secondary hero actions only when layout pressure requires it

Primary file:

- `lib/features/routines/list/ui/routine_list_screen.dart`

Test coverage:

- `test/features/routines/list/home_spotlight_test.dart`

## 7. User Experience Requirements

### Free User

- Can use local routines.
- Sees Free limits.
- Can view Premium upsells.
- Cannot unlock Premium locally.
- Billing unavailable does not unlock Premium.

### Personal Premium User

- Purchases through Google Play.
- Unlocks Premium only after Supabase verification succeeds.
- Can restore an active Google Play purchase.
- Keeps cached verified access where appropriate.
- Sees clear recoverable messaging when billing or verification fails.

### Signed-Out User

- Is not assumed to be Free because of sign-out alone.
- Cannot use cloud backup while signed out.
- Can continue local usage.
- Is prompted to sign in before purchase verification/account-tied cloud use where needed.

### Cloud Backup User

Cloud backup requires signed in + paid + consent.

If any requirement is missing, backup should be paused or unavailable with clear explanatory copy.

## 8. Edge Case Behavior

| Case | Expected Result |
|---|---|
| Google Play product missing | No Premium unlock; show store unavailable state |
| Billing unavailable | No Premium unlock; show recoverable unavailable state |
| Purchase cancelled | No Premium unlock; show cancellation feedback |
| Purchase pending | No Premium unlock until approved and verified |
| Verification fails | No Premium unlock; record/show verification failure |
| Server returns unknown tier | No Premium unlock |
| Subscription expired/cancelled | Return to non-paid entitlement behavior |
| Offline with valid cached entitlement | Use cached verified state according to entitlement rules |
| Offline without valid cached entitlement | Behave as Free |

## 9. Acceptance Criteria

- No legacy paid-tier naming remains in app, tests, Supabase code, web pages, or release docs.
- No legacy paid-tier product or tier symbols remain.
- Product ID constant is `personal_premium`.
- Monthly and yearly are Google Play base plans, not separate product IDs.
- Paywall shows **Personal Premium**.
- Google Play verification function accepts `personal_premium`.
- App-side code cannot grant Premium without server-verified entitlement.
- Full Flutter test suite passes.
- Flutter analyzer passes with no issues.
- Home hero supports large accessibility text without overflow.

## 10. Verification Performed

Commands run:

```powershell
flutter analyze
flutter test
rg -n "<legacy paid-tier naming patterns>" .
```

Results:

- `flutter analyze`: passed.
- `flutter test`: passed.
- Legacy paid-tier naming search: no remaining matches.

Note: the full test suite emits a Drift multiple-database warning in debug tests. It did not fail the suite and is not introduced by this Premium rename.

## 11. Remaining Work Before First Internal Test Upload

- Create/confirm Play Console subscription product:
  - Product ID: `personal_premium`
  - Base plans: `monthly`, `yearly`
- Confirm base plans are active and available for internal testing.
- Configure Play license testers.
- Configure Supabase `verify-purchase` secrets:
  - `GOOGLE_PLAY_PACKAGE_NAME`
  - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Deploy `verify-purchase` to the production Supabase project.
- Build a production release AAB with `APP_ENV=production`.
- Upload AAB to Play Console internal testing.
- Install from Google Play and run real purchase/restore/cancel smoke tests.
- Confirm account deletion web form/function deployment if still pending.
- Complete Play Data Safety and permission disclosures.

## 12. Release Build Command

Expected release build command:

```powershell
flutter build appbundle --release --dart-define=APP_ENV=production
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Production release builds must use production Supabase values and real Google Play Billing.

## 13. Risks and Follow-Ups

- If Play Console already has a subscription under an older paid-tier product ID, the app will not find it. Create `personal_premium` in Play Console or intentionally change the app and backend to the existing Play product ID.
- Google Play subscription expiration and cancellation behavior should be manually verified through Play Console testing after upload.
- Supabase verification depends on correct Google Play Developer API access and service account permissions.
- The Home hero accessibility fix is covered by widget tests, but should still be checked on a physical Android device with large display and font settings.

## 14. Final Product Contract

Premium is not a local flag.

Premium is not a sign-in state.

Premium is not a debug switch.

Premium is a verified entitlement produced by Google Play purchase verification and read by the app.
