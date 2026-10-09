# Pebble Processor and Data-Flow Map

Last scanned: 5 October 2026

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

- Supabase: authentication, profiles, database tables, private storage for
  proof photos and voice tip recordings (guidance audio), Edge Functions,
  account deletion, cloud-backup consent records, and deletion request
  tickets.
- Google: Google sign-in and Google Play purchase processing through
  RevenueCat.
- Apple: Sign in with Apple and App Store purchase processing through
  RevenueCat.
- RevenueCat: subscription product loading, purchase/restore state, customer
  entitlement state, and purchase webhooks to Supabase.
- Email/support provider: not hard-coded in the app, but used when users email
  support or privacy inboxes from the legal pages.
- Resend: delivers completion-email invitations and completion emails from the
  `request-shared-alert-contact` and `send-routine-completion-alert` Edge
  Functions (`api.resend.com`, `RESEND_API_KEY`). Receives the contact's email
  address, the sender's account email (shown in the email so the contact knows
  who it is from), the routine name unless the sender hides it, completion
  time, step counts, and step notes when the sender includes the steps.
- Anthropic: when someone chooses Build with AI, `build-routine` sends the
  sentence they type and any answers to `api.anthropic.com` to return questions
  or a draft. This works before sign-in. The function stores no prompt, answer
  or draft; `routine_ai_builds` keeps a random installation ID, an account ID
  when signed in, and usage counts to enforce limits. The provider retention
  described below also applies to this text and its response.
- Anthropic: AI photo descriptions, called only from the
  `describe-proof-photo` Edge Function (`api.anthropic.com`,
  `ANTHROPIC_API_KEY`, model `claude-sonnet-5-5`). Off unless the
  `AI_PHOTO_ENABLED` secret is `true`. Runs only for a signed-in Personal
  Premium account with a current row in `ai_photo_consents`. Receives a
  re-encoded JPEG of the photo (no EXIF or GPS, longest side 600 px, or 1,000 px when a step description supplies a visible detail)
  and the step title, plus any optional step description, with a fixed prompt. Pebble does not add account details,
  routine name, user IP address or device identifiers. A user-written title
  can itself contain personal details. Returns one short caption.
  Pebble's function holds the photo in memory for the one request
  and never stores or logs the photo, step title, step description or AI description. Provider retention:
  the API default, deleted within 30 days (longer only for content flagged
  for misuse investigations or legal duties); no model training on inputs;
  no zero-retention agreement. Retention checked on 5 October 2026 against
  https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data.
  Processor under Anthropic's Commercial Terms and Data Processing Addendum
  (https://www.anthropic.com/legal/data-processing-addendum). **Owner to do
  before switching on:** accept the terms on the account that owns the key,
  save a dated copy of the DPA, and confirm which transfer safeguard applies.
  The photo may show health details (medication), so this processing relies
  on consent given on the in-app sheet.
- Resend also receives AI photo descriptions in completion emails, only where
  the sender chose to add them for that routine.
- Sentry: crash reporting only, and only in builds where a `SENTRY_DSN`
  dart-define is supplied. Configured with PII sending off, no screenshots, no
  view hierarchy, no user identity, no tracing, and no session replay. Crash
  events carry stack traces, device model, OS version, and app version/build.
  `beforeSend` strips the user object from Dart crash events; it does not run
  for native crashes, which carry Sentry's random installation ID. Print
  breadcrumbs are off (`enablePrintBreadcrumbs = false`), because `debugPrint`
  lines can contain the account ID. Crash reporting is set up so that routine
  content, photos, audio, and account identity are not attached.

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
- Supabase Storage bucket: `routine-proofs` (proof photos, and voice tip
  recordings under `users/<uid>/guidance_audio/`).
- Supabase Edge Functions called by the app: `delete-account`,
  `revenuecat-sync-entitlement`, `request-shared-alert-contact`,
  `send-routine-completion-alert`, and `describe-proof-photo` (which calls
  `api.anthropic.com`).
- Supabase Edge Functions called by the website: `request-account-deletion`
  (`web/delete-account.html`), and `shared-alert-accept`,
  `shared-alert-decline`, and `shared-alert-block`
  (`web/shared-alert/confirm/`, reached from links in completion emails).
- Supabase Edge Functions called by other services: `revenuecat-webhook`
  (RevenueCat) and `cleanup-proof-retention` (the daily database cron job).
- `verify-purchase` still exists under `supabase/functions/` but the app no
  longer calls it.
- Supabase database tables written through Edge Functions only: the
  `shared_alert_*` tables for completion emails, and the `ai_photo_*` tables
  (consent record: account ID, consent wording version, provider, routine key,
  app version, consented and withdrawn times; a per-account request count; a
  monthly total; the off switch). None of them holds a photo or a description.
  Migration 023 retains request IDs/timestamps for the current UTC calendar
  month and at least the last two days; older rows are removed on the account's
  next new request or account deletion. Inactive accounts can retain older rows.
  This enforces 100 monthly attempts shared across phones. The app reads its own
  remaining count through an authenticated function; direct usage-table/RPC
  access is reserved for the service role.
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
- Audio: voice tip recordings (guidance-audio files) are uploaded when cloud
  backup is on (`lib/features/sync/guidance_audio_cloud_backup.dart`,
  called from `cloud_sync_coordinator.dart`), along with
  their filename, duration, MIME type, and size. They are kept until the user
  replaces or removes the recording, deletes the routine or deletes the
  account; `cleanup-proof-retention` skips them.
- Photos sent to Anthropic for AI descriptions when the user turns the
  feature on. Not shared (processor). Not ephemeral, because the provider
  keeps them for up to 30 days.
- AI description text, as user content: in history, in backup and, if the
  user chose it, in completion emails.
- Health info: **not decided**. Record the decision here, with the date and
  the reason, before the feature is switched on.
- Photos/media library access because users can choose existing proof photos.
- Camera and microphone permission usage.
- Diagnostics: crash logs (stack traces, device model, OS version, app
  version/build) sent to Sentry when crash reporting is enabled in the build.
  Declare under Play Data safety as "App activity / Diagnostics → Crash logs",
  collected, not shared for advertising, not linked to user identity.
  `web/privacy.html` names Sentry, RevenueCat and Resend as of 5 October 2026.
  Field-by-field store answers: `docs/store/DATA_SAFETY_ANSWERS.md` and
  `docs/store/APP_PRIVACY_LABELS.md`.

## Launch Checks

- Keep this map aligned with `web/privacy.html` before every store submission.
- Before changing the AI provider, model, prompt contents or retention
  settings, change the consent version
  (`lib/features/ai_photo/ai_photo_constants.dart` and
  `supabase/functions/_shared/ai_photo.ts`), this map, `web/privacy.html` and
  both store forms. Everyone is then asked again.
- Re-run the scan whenever adding analytics, crash reporting, push messaging,
  purchase SDKs, storage providers, AI services, or new outbound endpoints.
