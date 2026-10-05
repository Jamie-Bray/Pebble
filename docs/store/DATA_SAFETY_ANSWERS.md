# Google Play Data Safety Answers

Last updated: 5 October 2026. Based on the code at this commit, build
1.0.0+34, including the iOS sign-in changes merged from
`claude/sharp-keller-f6iiu2`.

Play Console > Policy > App content > Data safety. Answers are listed in the
order the form asks them. Each answer says where in the code it comes from, so
you can re-check it whenever the app changes.

Ground rules used:

- **Collected** means sent off the device to Pebble or to a provider working
  for Pebble. Data that only stays on the phone (local-only routines, local
  photos, and voice prompt recordings while backup is off) is **not**
  collected. Voice prompt recordings **are** collected when Premium cloud
  backup is on.
- **Shared** means given to a third party. Google does not count service
  providers acting for you (Supabase, RevenueCat, Sentry, Resend, and Anthropic
  for AI photo descriptions) as sharing.
  It also does not count transfers the user starts and would expect, such as
  a completion email the user set up. So nothing here is shared.
- If a released build can collect something for any user, it is declared,
  even if it only happens after sign-in or Premium (`LEGAL_PUBLICATION_CHECKS.md`).
- Production builds include Sentry when `PEBBLE_PROD_SENTRY_DSN` is set
  (`build_production_aab.ps1`). The answers assume crash reporting is **on**.
  If you ship a build without it, you may remove the "App info and
  performance" entries, but leaving them in is harmless.

> Crash logs are not linked to the user: `debugPrint` lines can contain the
> account ID, so `lib/core/monitoring/crash_reporting.dart` sets
> `options.enablePrintBreadcrumbs = false` and `beforeSend` removes the user.
> The Play form does not ask about linking, but Apple's does (see
> `APP_PRIVACY_LABELS.md`).

---

## Section 1: Data collection and security

| Question | Answer | Source |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** | Sign-in, subscriptions, backup, completion emails, AI photo descriptions, crash reports |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | All calls are HTTPS: Supabase (`supabase_flutter`), RevenueCat SDK, Sentry ingest, and, server side, Resend (`api.resend.com`) and Anthropic (`api.anthropic.com`) |
| Which of the following methods of account creation does your app support? | **Username and other authentication** (email address plus a one-time code) and **OAuth** (Google; Sign in with Apple on iOS) | `auth_repository.dart`: `signInWithOtp`, Google `signInWithIdToken`, Apple `signInWithIdToken` |
| Add a link that users can use to request that their account and associated data is deleted | `https://pebbleroutines.com/delete-account` | `web/delete-account.html` posts to the `request-account-deletion` Edge Function |
| Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account? | **Yes** | Users can delete routines, history runs and proof photos in the app. Deleted cloud-backed photos are removed from Supabase Storage. Other requests go to privacy@ |
| Has your app successfully completed an independent security review (MASA)? | **No** | |
| Is your app's data collection and sharing in line with Google Play's Families Policy? | Confirm against the agreed target age; do not assume 18+ | |

## Section 2: Data types

For each type the form asks: collected? shared? processed ephemerally?
required or optional? purposes?

Purpose names are Google's: App functionality, Analytics, Developer
communications, Advertising or marketing, Fraud prevention / security /
compliance, Personalisation, Account management.

### Location

| Type | Collected | Notes |
| --- | --- | --- |
| Approximate location | No | No location permission. IP addresses reach providers as part of normal connections but are not used to work out location |
| Precise location | No | |

### Personal info

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Name | **Yes** | No | No | Optional | Account management | Pebble only asks Google for `email`, but `google_sign_in` uses the default sign-in options, so Google's ID token normally includes the name and profile picture link. Supabase Auth stores them in the user's identity data. Pebble never shows or uses them. To stop declaring this, check a Google test user in Supabase > Authentication > Users. If `full_name` and `name` are absent, you can answer No. Apple sign-in requests email only. |
| Email address | **Yes** | No | No | Optional | App functionality, Account management | Sign-in email (Supabase Auth). Also the **completion email contact's** address that the user types in (`shared_alert_contacts.recipient_email`), sent through Resend. The web deletion form also collects an email address. |
| User IDs | **Yes** | No | No | Optional | App functionality, Account management, Fraud prevention / security / compliance | Supabase account UUID. The same ID is used as the RevenueCat app user ID after sign-in (`Purchases.logIn`). Used to link purchases to accounts and stop one purchase being claimed by several accounts. |
| Address | No | | | | | |
| Phone number | No | | | | | |
| Race and ethnicity, political or religious beliefs, sexual orientation | No | | | | | |
| Other info | No | | | | | |

### Financial info

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Purchase history | **Yes** | No | No | Optional | App functionality, Fraud prevention / security / compliance | RevenueCat customer info (product, store, purchase and expiry dates, status). Supabase `personal_entitlements` (product ID, store, status, period, SHA-256 hash of the purchase token) written by `revenuecat-webhook` and `revenuecat-sync-entitlement`. (`verify-purchase` is still deployed but the app no longer calls it.) Only users who buy Premium create this. |
| User payment info | No | | | | | Google Play handles payment. Pebble never sees card details. |
| Credit score | No | | | | | |
| Other financial info | No | | | | | |

### Health and fitness

| Type | Collected | Notes |
| --- | --- | --- |
| Health info | No | Pebble does not ask for health information and uses no health APIs. A user may type health-related text into a routine (for example "Take medication"). That free text is declared under "Other user-generated content". Do not declare Health info unless you add a health feature. **Owner decision needed before AI photo descriptions are switched on:** a photo of medication sent to be described, and the sentence that comes back, may count as health info. The cautious answer is then **Yes, Optional, App functionality** (see docs/research/AI_PRIVACY_LEGAL_BRIEFING.md on branch esearch/ai-photo-description, section 4, and question 12 for a solicitor). |
| Fitness info | No | |

### Messages

| Type | Collected | Notes |
| --- | --- | --- |
| Emails | No | Pebble sends completion emails but does not read the user's emails. The content of those emails (routine name, time, step count) is declared under "Other user-generated content" and the recipient address under "Email address". |
| SMS or MMS | No | |
| Other in-app messages | No | No chat or messaging |

### Photos and videos

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Photos | **Yes** | No | No | Optional | App functionality | Only when Premium cloud backup is on (Premium + signed in + backup consent). Uploaded to the private `routine-proofs` Supabase Storage bucket, kept for a rolling 21 days. Photos that stay on the device are not collected. **Also, when AI photo descriptions are on** (optional, off by default: Premium + signed in + the AI consent, for one routine): a JPEG copy of each photo from that routine's photo steps (the first five) is sent through the `describe-proof-photo` Edge Function to Anthropic to be described. Pebble's server holds it in memory only and stores nothing; Anthropic keeps it for up to 30 days, so it is **not** ephemeral. Anthropic is a service provider, so this is not sharing. |
| Videos | No | | | | | Pebble does not capture or upload video |

### Audio files

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Voice or sound recordings | **Yes** | No | No | Optional | App functionality | Only when Premium cloud backup is on (Premium + signed in + backup consent). Voice prompt recordings the user makes for routine steps are uploaded to `users/<uid>/guidance_audio/` in the private `routine-proofs` Supabase Storage bucket (`lib/features/sync/guidance_audio_cloud_backup.dart`, called from `cloud_sync_coordinator.dart`). They are kept until the user replaces or removes the recording, deletes the routine or deletes the account; the 21-day clean-up skips them (`supabase/functions/cleanup-proof-retention/plan.ts`). Recordings that stay on the device are not collected. |
| Music files | No | | | | | |
| Other audio files | No | | | | | |

### Files and docs

| Type | Collected | Notes |
| --- | --- | --- |
| Files and docs | No | |

### Calendar

| Type | Collected | Notes |
| --- | --- | --- |
| Calendar events | No | Reminders are scheduled locally with `flutter_local_notifications`. Reminder times are backed up as part of routine data (see below), not as calendar events. |

### Contacts

| Type | Collected | Notes |
| --- | --- | --- |
| Contacts | No | Pebble does not read the device address book and has no contacts permission. The one email address a user types for completion emails is declared under "Email address". |

### App activity

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| App interactions | No | | | | | No analytics SDK. Sentry breadcrumbs are covered under Diagnostics. |
| In-app search history | No | | | | | |
| Installed apps | No | | | | | |
| Other user-generated content | **Yes** | No | No | Optional | App functionality | With Premium cloud backup on: routine titles, steps (`steps_json`), icons and colours, reminder days and times, routine runs (title, finish time, step results), routine sessions, proof-photo records, voice prompt metadata, and the backup consent record. With completion emails on: the routine name, completion time and step counts in each email, and the sent-email log (`shared_alert_events`). With AI photo descriptions on: the step title sent to Anthropic as context, the one- or two-sentence description of each photo (kept in history on the phone, backed up with the run when backup is on, and included in the completion email only if the user chose that), the AI consent record (`ai_photo_consents`) and a per-account request count (`ai_photo_requests`, no content). |
| Other actions | No | | | | | |

### Web browsing

| Type | Collected | Notes |
| --- | --- | --- |
| Web browsing history | No | |

### App info and performance

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Crash logs | **Yes** | No | No | **Required** (no in-app opt-out) | Analytics | Sentry, only in builds with `SENTRY_DSN`. Stack traces, error messages. `crash_reporting.dart`: `sendDefaultPii = false`, no screenshots, no view hierarchy, no tracing, no replay. Google's "Analytics" purpose includes diagnosing crashes. |
| Diagnostics | **Yes** | No | No | Required | Analytics | Device model, OS version, app version and build, and up to 32 breadcrumbs attached to each crash report. |
| Other app performance data | No | | | | | Tracing is off |

### Device or other IDs

| Type | Collected | Shared | Ephemeral | Required? | Purposes | Source and notes |
| --- | --- | --- | --- | --- | --- | --- |
| Device or other IDs | **Yes** | No | No | Required | App functionality, Analytics | (1) RevenueCat is configured at app start for every user (`main.dart` reads `purchaseRepositoryProvider`), so it creates a random anonymous app user ID for the install even before sign-in. (2) Sentry's native Android and iOS SDKs attach a random installation ID to native crash reports. Pebble's Dart `beforeSend` removes the user field from Dart crash reports, but it does not run for native crashes. No advertising ID is used: `collectDeviceIdentifiers()` is never called, and there is no ad SDK. |

## Section 3: Data usage and handling, summary

Use this to check what the form generates on the preview screen.

**Data collected:** Name, Email address, User IDs, Purchase history,
Photos, Voice or sound recordings, Other user-generated content, Crash logs,
Diagnostics, Device or other IDs.

**Data shared:** None.

**Security practices shown on the listing:** Data is encrypted in transit.
You can request that data be deleted.

## Things that would change these answers

| Change | Update |
| --- | --- |
| Voice prompt audio backup is removed from the app | Audio > Voice or sound recordings: No |
| Analytics SDK added (Firebase, PostHog and so on) | App interactions, Device IDs, and probably Shared |
| Push notifications through FCM or APNs tokens | Device or other IDs purposes |
| Location reminders | Approximate or precise location |
| Sentry removed from the build | Crash logs and Diagnostics can be removed. Device IDs stay (RevenueCat) |
| Google sign-in changed to drop profile scope (and Supabase no longer stores the name) | Name: No |
| Health or medication-management features | Health info, plus Play's Health apps declaration |
| AI photo descriptions switched on for users (`AI_PHOTO_ENABLED`) | Confirm the Photos and Other user-generated content rows above, decide the Health info answer, and check Play's AI-generated content policy (a description of the user's own photo is probably out of scope) |
| AI provider, model region or retention changes | Photos row, `web/privacy.html`, and a new consent version (`lib/features/ai_photo/ai_photo_constants.dart`) |

Keep `LEGAL_PROCESSOR_MAP.md`, `web/privacy.html`, `APP_PRIVACY_LABELS.md`
and this file in step.
