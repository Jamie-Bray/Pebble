# Google Play Data Safety Answers

Last updated: 3 October 2026. Based on the code at this commit, build
1.0.0+31.

Play Console > Policy > App content > Data safety. Answers are listed in the
order the form asks them. Each answer says where in the code it comes from, so
you can re-check it whenever the app changes.

Ground rules used:

- **Collected** means sent off the device to Pebble or to a provider working
  for Pebble. Data that only stays on the phone (local-only routines, local
  photos, voice prompt recordings) is **not** collected.
- **Shared** means given to a third party. Google does not count service
  providers acting for you (Supabase, RevenueCat, Sentry, Resend) as sharing.
  It also does not count transfers the user starts and would expect, such as
  a completion email the user set up. So nothing here is shared.
- If a released build can collect something for any user, it is declared,
  even if it only happens after sign-in or Premium (`LEGAL_PUBLICATION_CHECKS.md`).
- Production builds include Sentry when `PEBBLE_PROD_SENTRY_DSN` is set
  (`build_production_aab.ps1`). The answers assume crash reporting is **on**.
  If you ship a build without it, you may remove the "App info and
  performance" entries, but leaving them in is harmless.

> **Fix before you rely on "crash logs are not linked to the user".**
> Sentry's print breadcrumbs are on by default in `sentry_flutter`, and
> release builds `debugPrint` lines that contain the Supabase account ID and
> RevenueCat app user ID (`revenuecat_purchase_repository.dart`,
> `subscription_provider.dart`). These lines can end up in crash reports.
> Set `options.enablePrintBreadcrumbs = false` (or scrub breadcrumbs in
> `beforeSend`) in `lib/core/monitoring/crash_reporting.dart`. The Play form
> does not ask about linking, but Apple's does (see `APP_PRIVACY_LABELS.md`),
> and the privacy policy wording depends on it.

---

## Section 1: Data collection and security

| Question | Answer | Source |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** | Sign-in, subscriptions, backup, completion emails, crash reports |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | All calls are HTTPS: Supabase (`supabase_flutter`), RevenueCat SDK, Sentry ingest, and Resend (`api.resend.com`, server side) |
| Which of the following methods of account creation does your app support? | **Username and other authentication** (email address plus a one-time code) and **OAuth** (Google; Sign in with Apple on iOS) | `auth_repository.dart`: `signInWithOtp`, Google `signInWithIdToken`, Apple `signInWithIdToken` |
| Add a link that users can use to request that their account and associated data is deleted | `https://pebbleroutines.com/delete-account` | `web/delete-account.html` posts to the `request-account-deletion` Edge Function |
| Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account? | **Yes** | Users can delete routines, history runs and proof photos in the app. Deleted cloud-backed photos are removed from Supabase Storage. Other requests go to privacy@ |
| Has your app successfully completed an independent security review (MASA)? | **No** | |
| Is your app's data collection and sharing in line with Google Play's Families Policy? | Not applicable (target audience is 18+) | |

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
| Purchase history | **Yes** | No | No | Optional | App functionality, Fraud prevention / security / compliance | RevenueCat customer info (product, store, purchase and expiry dates, status). Supabase `personal_entitlements` (product ID, store, status, period, SHA-256 hash of the purchase token) written by `revenuecat-webhook` / `verify-purchase`. Only users who buy Premium create this. |
| User payment info | No | | | | | Google Play handles payment. Pebble never sees card details. |
| Credit score | No | | | | | |
| Other financial info | No | | | | | |

### Health and fitness

| Type | Collected | Notes |
| --- | --- | --- |
| Health info | No | Pebble does not ask for health information and uses no health APIs. A user may type health-related text into a routine (for example "Take medication"). That free text is declared under "Other user-generated content". Do not declare Health info unless you add a health feature. |
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
| Photos | **Yes** | No | No | Optional | App functionality | Only when Premium cloud backup is on (Premium + signed in + backup consent). Uploaded to the private `routine-proofs` Supabase Storage bucket, kept for a rolling 21 days. Photos that stay on the device are not collected. |
| Videos | No | | | | | Pebble does not capture or upload video |

### Audio files

| Type | Collected | Notes |
| --- | --- | --- |
| Voice or sound recordings | **No** | Voice prompt recordings stay on the device (`guidance_audio_storage.dart`; `CURRENT_PRODUCT_OVERVIEW_PRD.md`). Backed-up routine steps can include the recording's filename, duration, MIME type and size, which counts as user-generated content metadata, not audio. **If audio backup is ever added, change this to Yes before release.** |
| Music files | No | |
| Other audio files | No | |

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
| Other user-generated content | **Yes** | No | No | Optional | App functionality | With Premium cloud backup on: routine titles, steps (`steps_json`), icons and colours, reminder days and times, routine runs (title, finish time, step results), routine sessions, proof-photo records, voice prompt metadata, and the backup consent record. With completion emails on: the routine name, completion time and step counts in each email, and the sent-email log (`shared_alert_events`). |
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
Photos, Other user-generated content, Crash logs, Diagnostics, Device or
other IDs.

**Data shared:** None.

**Security practices shown on the listing:** Data is encrypted in transit.
You can request that data be deleted.

## Things that would change these answers

| Change | Update |
| --- | --- |
| Voice prompt audio is backed up | Audio > Voice or sound recordings: Yes |
| Analytics SDK added (Firebase, PostHog and so on) | App interactions, Device IDs, and probably Shared |
| Push notifications through FCM or APNs tokens | Device or other IDs purposes |
| Location reminders | Approximate or precise location |
| Sentry removed from the build | Crash logs and Diagnostics can be removed. Device IDs stay (RevenueCat) |
| Google sign-in changed to drop profile scope (and Supabase no longer stores the name) | Name: No |
| Health or medication-management features | Health info, plus Play's Health apps declaration |

Keep `LEGAL_PROCESSOR_MAP.md`, `web/privacy.html`, `APP_PRIVACY_LABELS.md`
and this file in step.
