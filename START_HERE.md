# Start Here: Pebble Launch Status

**Last updated:** 3 October 2026
All of this work is on the branch `claude/sharp-keller-f6iiu2`.

## Where things stand

| Area | State |
|---|---|
| **App code** | `flutter analyze` finds no issues, and all 291 tests pass. All 180 screens were rendered and checked: no layout errors at normal or double text size, or on a small phone. |
| **Android** | Ready for the closed test, once the store listing and forms are filled in. |
| **iOS** | The code is ready. It now needs the Apple account and dashboard steps below. |
| **Backend** | Security is solid. Fixes are written but **not deployed**, except one live permission fix (see below). |
| **Store and legal** | Listings, privacy-form answers, the privacy policy and the terms are drafted. A few facts only you know are marked TODO. |
| **Builds** | GitHub checks every push. Codemagic builds the iOS app (to TestFlight) and the Android app bundle in the cloud. |

## What changed on 3 October

- **iOS blockers fixed:**
  - Sign in with Apple, offered first on iPhone.
  - A valid bundle ID: `com.vix.pebbleroutines`.
  - Google sign-in support for iOS.
  - Notification permissions and delivery on iOS.
  - No surprise Apple ID prompts.
  - iPhone-only for v1.
  - A privacy manifest.
- **App reliability:**
  - Reminder taps open the routine even when the app was closed.
  - One damaged backup record no longer stops a restore.
  - Startup can no longer freeze on the splash screen.
  - The proof-photo re-download loop is fixed.
  - Voice prompts are now backed up and restored.
  - Crash reports no longer contain account IDs.
- **Screens and the user journey:**
  - Small phones and large text no longer clip anything.
  - Run counts are honest about skipped steps.
  - Low-contrast grey text is now readable.
  - When the store doesn't respond, the paywall says so and offers **Try again**.
  - Signed-out users always see a Sign in option.
  - Premium users get a proper account screen.
  - About links to the Privacy Policy and Terms.
  - The Settings title no longer sits behind the back button.
- **Backend code (not deployed yet):**
  - The RevenueCat transfer and claim-conflict bug is fixed.
  - The Premium tier now stays in step with the subscription.
  - The cleanup job won't run without its secret, and it keeps voice prompts.
  - The deletion form has abuse limits.
  - The photo storage bucket has size and file-type limits.
  - Anonymous sign-in is off.
- **Live production fix:** the server could not check Premium status, so completion emails and contact invites had failed for every Premium user since migration 012. A single permission grant fixed it (see `supabase/DEPLOY_PLAN.md`).

## Your to-do list, in order

### Now (no money needed)
1. **Pick your email domain.** The site is `.com` but every inbox is `@pebbleroutines.app`. See `docs/store/OWNER_NOTES.md` §1, then tell Claude which one, and it will update everything.
2. **Fill in the legal details** (`docs/store/OWNER_NOTES.md` §2): a postal address if one is needed, ICO registration, and the providers' data processing terms.
3. **Confirm one Supabase secret.** `CLEANUP_PROOF_RETENTION_SECRET` must exist (Dashboard → Edge Functions → Secrets) before Claude deploys the backend fixes.
4. **Turn off anonymous sign-ins** in Supabase (Authentication → Sign In / Providers).

### Android launch
5. **Fill in the Play Console** using `docs/store/GOOGLE_PLAY_LISTING.md` and `docs/store/DATA_SAFETY_ANSWERS.md`.
6. **Start the 12-tester, 14-day closed test.** The £20 tester service goes here. It's the slowest step, so start it early.
7. **Connect Codemagic** (`docs/BUILD_AND_RELEASE.md`, steps 1, 4 and 5) and upload the keystore. Codemagic then builds the signed app bundle for you.

### iOS launch
8. **Join the Apple Developer Program** (about £79 a year), then follow `IOS_SETUP_CHECKLIST.md`: the App ID, subscriptions, RevenueCat, Sign in with Apple in Supabase, and optionally a Google iOS client.
9. **Finish the Codemagic iOS steps** (`docs/BUILD_AND_RELEASE.md`, steps 2 and 3), then build to TestFlight.
10. **Test on a borrowed iPhone** through TestFlight.
11. **Submit using `docs/store/APP_STORE_LISTING.md`** (the App Review notes are included) and `docs/store/APP_PRIVACY_LABELS.md`.

### Before launch day
12. **Upgrade Supabase to Pro** (about $25 a month). Free projects pause after a week with no activity, and you get no backups.
13. **Let Claude deploy the backend fixes** in the order in `supabase/DEPLOY_PLAN.md`. This must happen before any app build that backs up voice prompts. Then do one real buy-and-restore test.

## Where to find things

| You want | Open |
|---|---|
| Code audit | `LAUNCH_READINESS_AUDIT.md` |
| Live backend audit | `SUPABASE_LIVE_AUDIT.md` |
| Screen-by-screen review | `VISUAL_WALKTHROUGH.md` |
| iOS account steps | `IOS_SETUP_CHECKLIST.md` |
| Cloud builds | `docs/BUILD_AND_RELEASE.md` |
| Store listings and forms | `docs/store/` |
| Backend deploy and migration steps | `supabase/DEPLOY_PLAN.md`, `supabase/MIGRATION_REPAIR_PLAN.md` |
| TikTok video ideas | `docs/store/LAUNCH_MARKETING_HOOKS.md` |
