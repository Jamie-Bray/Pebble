# Pebble Processor and Data-Flow Map

Last scanned: May 4, 2026

This map is generated from the current codebase and should be used when filling
Google Play Data safety, Apple privacy declarations, and the public Privacy
Policy.

## App Permissions

- Android declares camera, microphone, notifications, boot completed, vibrate,
  and wake lock permissions.
- Android does not currently declare location, contacts, SMS, phone, or legacy
  storage permissions.
- iOS declares microphone, camera, and photo-library usage descriptions.

## Third-Party Services Present In Code

- Supabase: authentication, profiles, database tables, private proof-photo
  storage, Edge Functions, account deletion, cloud-backup consent records, and
  deletion request tickets.
- Google: Google sign-in and Google Play Billing through `in_app_purchase`.
- Apple: Sign in with Apple and future App Store billing support.
- Email/support provider: not hard-coded in the app, but used when users email
  support or privacy inboxes from the legal pages.

## Third-Party SDKs Not Found

- No Firebase, Crashlytics, Sentry, PostHog, RevenueCat, OneSignal, Cloudflare,
  ad SDK, or analytics SDK was found in `pubspec.yaml` or the app code scan.

## Outbound Network Calls Found

- `Supabase.initialize` using `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Supabase Auth for email OTP, Google sign-in, and Apple sign-in.
- Supabase database tables: profiles, routines, routine reminders, routine
  runs, routine sessions, proof asset usage, entitlements, cloud backup
  consents, and deletion request tickets.
- Supabase Storage bucket: `routine-proofs`.
- Supabase Edge Functions: `delete-account`, `verify-purchase`, and
  `request-account-deletion`.
- Google Play subscription management URL:
  `https://play.google.com/store/account/subscriptions`.
- Supabase Edge Functions import Deno and Supabase client libraries from
  `deno.land` and `esm.sh` at deploy/build time.

## Store Privacy Data Categories To Declare If Enabled

- Email address and account/user ID for sign-in.
- Purchase history, product ID, subscription status, and protected purchase
  verification records.
- User content: routines, steps, reminders, history, proof-photo metadata, and
  proof photos when cloud backup is enabled.
- Audio metadata when routines containing guidance-audio metadata are backed up.
  Guidance-audio files currently stay local unless a future build explicitly
  adds audio-file cloud backup.
- Photos/media library access because users can choose existing proof photos.
- Camera and microphone permission usage.
- Diagnostics only to the extent app stores or operating systems provide them;
  this codebase does not include a dedicated crash/analytics SDK.

## Launch Checks

- Keep this map aligned with `web/privacy.html` before every store submission.
- Re-run the scan whenever adding analytics, crash reporting, push messaging,
  purchase SDKs, storage providers, AI services, or new outbound endpoints.
