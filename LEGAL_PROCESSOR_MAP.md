# Pebble Processor and Data-Flow Map

Last scanned: July 14, 2026

This map is generated from the current codebase and should be used when filling
Google Play Data safety, Apple privacy declarations, and the public Privacy
Policy.

## App Permissions

- Android declares camera, microphone, notifications, boot completed, vibrate,
  and wake lock permissions.
- Android declares `WRITE_EXTERNAL_STORAGE` capped at `maxSdkVersion="29"` so
  "Save a copy to Photos" works on Android 9 and below; Android 10+ saves via
  MediaStore with no permission. No read, manage-storage, or delete
  permissions are declared.
- Android does not currently declare location, contacts, SMS, or phone
  permissions.
- iOS declares microphone, camera, and photo-library usage descriptions.

## Third-Party Services Present In Code

- Supabase: authentication, profiles, database tables, private proof-photo
  storage, Edge Functions, account deletion, cloud-backup consent records, and
  deletion request tickets.
- Google: Google sign-in and Google Play purchase processing through
  RevenueCat.
- Apple: Sign in with Apple and App Store purchase processing through
  RevenueCat.
- RevenueCat: subscription product loading, purchase/restore state, customer
  entitlement state, and purchase webhooks to Supabase.
- Email/support provider: not hard-coded in the app, but used when users email
  support or privacy inboxes from the legal pages.
- Sentry: crash reporting only, and only in builds where a `SENTRY_DSN`
  dart-define is supplied. Configured with PII sending off, no screenshots, no
  view hierarchy, no user identity, no tracing, and no session replay. Crash
  events carry stack traces, device model, OS version, and app version/build.
  `beforeSend` strips the user object as a defensive measure. Routine content,
  photos, audio, and account identity are never attached.

## Third-Party SDKs Not Found

- No Firebase, Crashlytics, PostHog, OneSignal, Cloudflare, ad SDK, or
  behavioural analytics SDK was found in `pubspec.yaml` or the app code scan.
  Sentry is present for crash reporting only (see above).

## Outbound Network Calls Found

- `Supabase.initialize` using `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Supabase Auth for email OTP, Google sign-in, and Apple sign-in.
- Supabase database tables: profiles, routines, routine reminders, routine
  runs, routine sessions, proof asset usage, entitlements, cloud backup
  consents, and deletion request tickets.
- Supabase Storage bucket: `routine-proofs`.
- Supabase Edge Functions: `delete-account`, `verify-purchase`,
  `revenuecat-webhook`, and `request-account-deletion`.
- Google Play subscription management URL:
  `https://play.google.com/store/account/subscriptions`.
- App Store subscription management URL:
  `https://apps.apple.com/account/subscriptions`.
- RevenueCat SDK calls for offerings, purchases, restores, and customer
  entitlement info.
- Sentry ingest endpoint (from the build's `SENTRY_DSN`) for crash events, only
  in builds where crash reporting is enabled.
- Supabase Edge Functions import Deno and Supabase client libraries from
  `deno.land` and `esm.sh` at deploy/build time.

## Store Privacy Data Categories To Declare If Enabled

- Email address and account/user ID for sign-in.
- Purchase history, product ID, subscription status, and protected purchase
  verification records.
- User content: routines, steps, reminders, history, proof-photo records, and
  proof photos when cloud backup is enabled.
- Audio details when routines containing guidance-audio details are backed up.
  Guidance-audio files currently stay local unless a future build explicitly
  adds audio-file cloud backup.
- Photos/media library access because users can choose existing proof photos.
- Camera and microphone permission usage.
- Diagnostics: crash logs (stack traces, device model, OS version, app
  version/build) sent to Sentry when crash reporting is enabled in the build.
  Declare under Play Data safety as "App activity / Diagnostics → Crash logs",
  collected, not shared for advertising, not linked to user identity. Update
  `web/privacy.html` to name Sentry as a processor before shipping a
  crash-reporting build.

## Launch Checks

- Keep this map aligned with `web/privacy.html` before every store submission.
- Re-run the scan whenever adding analytics, crash reporting, push messaging,
  purchase SDKs, storage providers, AI services, or new outbound endpoints.
