# Apple App Privacy Answers

Last updated: 3 October 2026. Based on the code at this commit (build
1.0.0+31, iOS bundle ID `com.vix.pebbleroutines`).

App Store Connect > App Privacy. Apple asks, for each data type: is it
collected, is it linked to the user, is it used for tracking, and what is it
used for. This file gives the answer for each data type and the code it comes
from.

Ground rules used:

- **Collected** means sent off the device and kept for longer than it takes to
  handle the request. Data that only stays on the iPhone (local routines,
  local photos, voice prompt recordings) is not collected.
- **Linked to you** means it is connected to the user's account or identity.
  Anything stored against the Supabase account ID or the RevenueCat app user ID
  is linked.
- **Tracking** means linking Pebble's data with other companies' data for
  advertising, or sharing it with data brokers. Pebble does none of this, so
  every type is **Not used for tracking**, and the app does not need the App
  Tracking Transparency prompt.
- Apple's purpose names: Third-Party Advertising, Developer's Advertising or
  Marketing, Analytics, Product Personalisation, App Functionality, Other
  Purposes. Apple's own definition of **App Functionality** includes
  "minimise app crashes", so crash data goes there.
- If a released build can collect something for any user, it is declared,
  even if it only happens after sign-in or Premium.

## First question

**Do you or your third-party partners collect data from this app?** Yes.

## Data types to declare

| Apple category | Data type | Linked to you | Tracking | Purposes | Why and where in the code |
| --- | --- | --- | --- | --- | --- |
| Contact Info | **Name** | Yes | No | App Functionality | Pebble asks Google for the `email` scope only, but Google's ID token normally includes the name and profile picture link. Supabase Auth stores them in the account's identity data. Pebble does not use them. Sign in with Apple requests email only (`AppleIDAuthorizationScopes.email`), so Apple sends no name. If you confirm Google users have no `full_name` in Supabase, you can remove this. |
| Contact Info | **Email Address** | Yes | No | App Functionality | Sign-in email (Supabase Auth: Apple, Google or an email code). Also the one completion email contact address a Premium user types in (`shared_alert_contacts`), which is stored against the user's account and sent through Resend. |
| User Content | **Photos or Videos** | Yes | No | App Functionality | Proof photos, only when Premium cloud backup is on (Premium + signed in + backup consent). Stored in the private `routine-proofs` bucket for a rolling 21 days. Photos are re-encoded before upload, which strips EXIF and GPS data. |
| User Content | **Other User Content** | Yes | No | App Functionality | With backup on: routine titles and steps, reminder days and times, history runs, routine sessions, proof-photo records, voice prompt metadata (filename, duration, type, size), and the backup consent record. With completion emails on: the routine name, completion time and step counts sent in each email, and the sent-email log. |
| Identifiers | **User ID** | Yes | No | App Functionality | Supabase account UUID. After sign-in, RevenueCat uses the same ID as its app user ID (`Purchases.logIn`). |
| Identifiers | **Device ID** | Yes | No | App Functionality | RevenueCat is set up at launch for every user and creates a random anonymous app user ID for the install. That ID is merged with the account ID when the user signs in, so it counts as linked. Sentry's native iOS SDK also attaches a random installation ID to native crash reports. The advertising identifier (IDFA) is **not** used: `collectDeviceIdentifiers()` is never called and there is no ad SDK. |
| Purchases | **Purchase History** | Yes | No | App Functionality | RevenueCat customer info (product, purchase and expiry dates, status, store transaction IDs). Supabase `personal_entitlements` (product, store, status, period, and a one-way hash of the purchase identifier). |
| Diagnostics | **Crash Data** | **No** (see the note below) | No | App Functionality | Sentry, only in builds with `SENTRY_DSN` (`codemagic.yaml` passes it when set). Stack traces and error messages. `crash_reporting.dart`: `sendDefaultPii = false`, no screenshots, no view hierarchy, no tracing, no replay, `beforeSend` removes the user. |
| Diagnostics | **Other Diagnostic Data** | **No** (see the note below) | No | App Functionality | Device model, iOS version, app version and build, and up to 32 breadcrumbs attached to each crash report. |

> **Why Diagnostics is "Not linked".** `debugPrint` lines can contain the
> Supabase account ID and RevenueCat app user ID, so `crash_reporting.dart`
> sets `options.enablePrintBreadcrumbs = false` to keep them out of crash
> breadcrumbs, and `beforeSend` removes the user. Sentry's native
> installation ID is a random per-install value, not tied to the account, so
> it does not make crash data linked by itself. If print breadcrumbs are ever
> turned back on, change both Diagnostics rows to **Linked to you: Yes**.

## Data types to answer "Not collected"

| Apple category | Data type | Why |
| --- | --- | --- |
| Contact Info | Phone Number, Physical Address, Other User Contact Info | Not requested |
| Health & Fitness | Health, Fitness | No HealthKit and no health features. Users may type health-related words into a routine (for example "Take medication"). That text is declared as Other User Content. |
| Financial Info | Payment Info, Credit Info, Other Financial Info | Apple handles payment. Pebble never sees card details |
| Location | Precise Location, Coarse Location | No location permission. IP addresses reach providers as part of normal connections but are not used to work out location |
| Sensitive Info | Sensitive Info | Pebble does not ask for it. Free text a user chooses to type is Other User Content |
| Contacts | Contacts | No address book access. The single completion email address is declared under Email Address |
| User Content | Emails or Text Messages | Pebble sends completion emails but does not access the user's own emails or messages |
| User Content | Audio Data | Voice prompt recordings stay on the device. **If audio backup is ever added, declare Audio Data before release.** |
| User Content | Gameplay Content, Customer Support | No gameplay. Support is by email outside the app |
| Browsing History | Browsing History | |
| Search History | Search History | |
| Usage Data | Product Interaction, Advertising Data, Other Usage Data | No analytics SDK and no ads |
| Diagnostics | Performance Data | Sentry tracing is off |
| Other Data | Other Data Types | |

## What the label will show

**Data Linked to You:** Contact Info (Name, Email Address), User Content
(Photos or Videos, Other User Content), Identifiers (User ID, Device ID),
Purchases (Purchase History).

**Data Not Linked to You:** Diagnostics (Crash Data, Other Diagnostic Data),
once the breadcrumb fix is in.

**Data Used to Track You:** None.

## Related iOS privacy items

- **Privacy manifest:** `ios/Runner/PrivacyInfo.xcprivacy` is in the app
  target. It declares `NSPrivacyTracking = false`, no tracking domains, the
  collected data types above, and the UserDefaults (`CA92.1`) and file
  timestamp (`C617.1`) required-reason APIs. Keep it in step with this table.
  Check Xcode's privacy report
  (Product > Archive > Generate Privacy Report) after archiving.
- **Usage descriptions** are present in `Info.plist` for the camera,
  microphone, photo library and saving to Photos. They match the
  just-in-time prompts.
- **Account deletion in the app** (guideline 5.1.1(v)): Your account >
  Delete Account.
- **Encryption export:** `ITSAppUsesNonExemptEncryption = false` is set.

Keep this file in step with `DATA_SAFETY_ANSWERS.md`, `LEGAL_PROCESSOR_MAP.md`
and `web/privacy.html`.
