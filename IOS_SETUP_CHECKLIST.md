# iOS Setup Checklist

The code side of the five iOS blockers in `LAUNCH_READINESS_AUDIT.md` is done. These are the account and dashboard steps that need the owner's logins. Do them in order. Each one depends on the Apple Developer account from step 1.

**iOS bundle ID:** `com.vix.pebbleroutines`. Android keeps `com.vix.pebble_routines`. Apple does not allow underscores.

## 1. Apple Developer Program (about £79 a year)
1. Enrol at developer.apple.com/programs as an individual.
2. Go to **Certificates, Identifiers & Profiles → Identifiers → +**. Register the App ID `com.vix.pebbleroutines`, and tick **Sign in with Apple**.
3. Go to **App Store Connect → Apps → +**. Create "Pebble Routines" with that bundle ID.

## 2. Subscriptions in App Store Connect
1. Go to **App → Subscriptions**. Create a group called "Personal Premium" with two subscriptions: monthly and yearly.
2. Prices should match Google Play.
3. Fill in each subscription's display name and description. Apple reviews these.

## 3. RevenueCat
1. Go to **Project → Apps → + App Store app**. Use the bundle ID `com.vix.pebbleroutines`.
2. Upload the App Store Connect in-app purchase key that RevenueCat asks for.
3. Attach both App Store products to the existing `personal_premium` entitlement, and to the current offering as the monthly and annual packages.
4. Copy the **Apple public SDK key**, which starts with `appl_`. It becomes the `REVENUECAT_IOS_API_KEY` build setting.

## 4. Sign in with Apple in Supabase
1. In Apple Developer, create a **Services ID** and a **Sign in with Apple key**.
2. In **Supabase → Authentication → Sign In / Providers → Apple**: enable it, and add `com.vix.pebbleroutines` to the client IDs.
   - The app signs in natively with an ID token, so the bundle ID is the client ID that matters.

## 5. Google sign-in on iOS
1. Go to **Google Cloud Console → APIs & Services → Credentials → Create OAuth client ID → iOS**. Use the bundle ID `com.vix.pebbleroutines`.
2. Add that new iOS client ID to **Supabase → Authentication → Providers → Google → Client IDs**. Keep it comma-separated with the existing web client ID.
3. Give both values to Claude. Neither is secret, because both ship inside the app.
   - The client ID becomes the `SUPABASE_GOOGLE_IOS_CLIENT_ID` build setting.
   - The reversed form (`com.googleusercontent.apps.…`) goes into `ios/Flutter/GoogleSignIn.xcconfig`. Copy it from `GoogleSignIn.xcconfig.example`.
- **Until this is done:** the Google button stays hidden on iPhone, and Apple and Email sign-in still work.

## 6. Cloud builds (Codemagic, free tier)
- Claude sets up `codemagic.yaml` once steps 1–3 exist.
- It builds on a cloud Mac with the same settings as `build_production_aab.ps1`, plus `REVENUECAT_IOS_API_KEY` and `SUPABASE_GOOGLE_IOS_CLIENT_ID`.
- Then it uploads to TestFlight.

## What changed in code
- **Sign in with Apple:** the button is shown first on iPhone, uses Apple's own button style, and handles cancelling cleanly. The capability is added in `ios/Runner/Runner.entitlements`.
- **Bundle ID:** changed to `com.vix.pebbleroutines`, and the test target now uses a matching ID.
- **iPhone-only for v1:** `TARGETED_DEVICE_FAMILY = 1`, so no iPad screenshots or iPad review.
- **Google on iOS:** it uses an iOS client ID, the redirect URL scheme is in `Info.plist`, and the button is hidden until that's configured.
- **Notifications on iOS:** the `permission_handler` notification flag is on in the `Podfile`, and `AppDelegate` sets the notification delegate so reminders show while the app is open and taps work.
- **Silent purchase restore:** now Android-only. On iOS, restore runs only when someone taps Restore.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = false` stops the question on every upload.
