# Launch Readiness Audit

**Date:** 3 October 2026
**Build audited:** `1.0.0+31` (branch head `1c2116c`)
**Question this answers:** Is Pebble ready for Google Play and the App Store?

## Verdict

- **Android: close.** The code is in good shape. What remains is mostly store paperwork, a few should-fix items, and the 14-day closed test.
- **iOS: not yet.** There are 5 concrete blockers. Most are small config or UI changes, but each one would get the app rejected or break a core flow on iPhone.

## How this audit was run

- `flutter analyze` on current stable Flutter: **2 infos, 0 warnings, 0 errors.** Both infos are deprecations of `onReorder`.
- `flutter test`: **234 passed, 1 failed.** The failure is a 46px overflow inside the test-only preview `Row` in `test/features/theme/sandstone_theme_golden_test.dart:192`. It is not app code.
- Read-through of startup, routing, purchases and entitlement, auth, backup, sync and restore, notifications, account deletion, the RevenueCat edge functions, migrations, the iOS and Android project config, and the legal pages.
- **Not covered yet:** a visual UX walkthrough, line-by-line reads of the large UI screens, and the live Supabase, RevenueCat and Play Console dashboards. The Supabase connector timed out during this session.

## Answers to open questions

- **Which purchase path is live?** RevenueCat. `purchaseRepositoryProvider` returns `RevenueCatPurchaseRepository`, and the app calls the `revenuecat-sync-entitlement` function. The webhook is `revenuecat-webhook`.
  - `supabase/functions/verify-purchase` is no longer called by the app.
  - `GOOGLE_PLAY_RELEASE_CHECKLIST.md` still lists `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` for it. That item is stale.

---

## 🔴 iOS blockers

### 1. There is no Sign in with Apple button
- **Where:** `lib/features/auth/ui/sign_in_screen.dart` offers only Google and Email.
- **What's wrong:** `AuthController.signInWithApple()` and `SupabaseAuthRepository.signInWithApple()` exist, but no screen calls them. Apple guideline 4.8 rejects apps that offer Google sign-in without an equivalent privacy-focused option.
- **Also missing:** a `Runner.entitlements` file with the `com.apple.developer.applesignin` capability, and the Apple provider in Supabase Auth.
- **Fix:** show an Apple button on iOS, add the capability, and configure the Supabase Apple provider.

### 2. The bundle ID is not valid for Apple
- **Where:** `ios/Runner.xcodeproj` uses `com.vix.pebble_routines`.
- **What's wrong:** Apple bundle IDs allow only letters, numbers, hyphens and periods. App Store Connect will not register an underscore.
- **Fix:** use something like `com.vix.pebbleroutines` for iOS only. Android keeps its ID.
- **Knock-on changes:** the RevenueCat iOS app, the Supabase Apple client ID and the Google iOS OAuth client must all use the new ID.

### 3. Google Sign-In is not configured for iOS
- **Where:** `ios/Runner/Info.plist`.
- **What's wrong:** there is no `GIDClientID` and no reversed-client-ID URL scheme, so tapping "Continue with Google" on iPhone fails.
- **Fix:** create an iOS OAuth client in Google Cloud, add it to the plist, and add it to the Supabase Google provider's authorised client IDs.

### 4. iOS notification permission always reads as "denied"
- **Where:** `ios/Podfile`.
- **What's wrong:** `permission_handler` needs `PERMISSION_NOTIFICATIONS=1` set in `GCC_PREPROCESSOR_DEFINITIONS` in `post_install`. Without it, `Permission.notification.status` never reports granted on iOS.
- **Effect:** `_resyncEnabledReminderNotifications` in `lib/main.dart` returns early, so reminders are never re-synced at launch. Any "notifications are off" UI will show permanently.
- **Also needed:** `ios/Runner/AppDelegate.swift` needs the `UNUserNotificationCenter` delegate line from the `flutter_local_notifications` setup guide, so foreground notifications and taps work.

### 5. Store restore runs silently on every launch and sign-in
- **Where:** `RevenueCatPurchaseRepository.syncPurchasesSilently()`.
- **What's wrong:** it calls `Purchases.restorePurchases()` automatically for any signed-in user without Premium. This runs from `_initialise`, sign-in, account deletion and the resume path. On iOS, a restore can bring up the Apple ID sign-in sheet unprompted, which App Review flags.
- **Fix:** on iOS, use `getCustomerInfo` (or `syncPurchases`) for silent checks. Only call `restorePurchases()` from the Restore button, which already exists on the paywall and in the account hub.

---

## 🟠 Should fix before launch (both platforms)

### 6. Tapping a reminder when the app is closed doesn't open the routine
- **Where:** `lib/core/notifications/notification_service.dart`.
- **What's wrong:** `getNotificationAppLaunchDetails()` is never called, so a tap that launches a killed app goes to Home instead of the routine.
- **Fix:** the home widget already handles this case with `initiallyLaunchedFromHomeWidget`. Do the same for notifications.

### 7. The privacy policy is missing processors, and the email domains don't match
- **Where:** `web/privacy.html`.
- **What's wrong:** RevenueCat (which receives the user ID and purchase data) and Sentry (crash reports, when `SENTRY_DSN` is set) are not named. Both matter for the Play Data safety form and Apple's privacy labels.
- **Also:** the website is `pebbleroutines.com`, but every contact email is `@pebbleroutines.app`. Confirm you own and monitor those inboxes.

### 8. Voice prompts are not backed up
- **What's wrong:** guidance audio lives only in the local `routine_guidance_audio/` folder. Sync never uploads it.
- **Effect:** after a restore on a new phone, steps point to clips that don't exist. The player handles this without crashing, but the clip is gone. The paywall says backup is "safe if you reinstall or change phone".
- **Fix:** either upload the audio or change the copy.

### 9. One bad cloud record can block a whole restore
- **Where:** `CloudRestoreCoordinator._mergeSessions`.
- **What's wrong:** it calls `RoutineSession.fromJson` without guarding against malformed data. One bad remote session throws, so `bootstrapAndMerge` never completes for that account.
- **Fix:** skip and log bad records instead of aborting.

### 10. A failure during startup leaves the splash screen stuck
- **Where:** `lib/main.dart`.
- **What's wrong:** `NotificationService().init()` and the reminder resync are awaited before `runApp` with no guard. If either throws (a DB migration failure, a plugin error), the user is stuck on the splash screen.
- **Fix:** wrap them in a guard and run the resync after the first frame.

### 11. iPad support and landscape need a decision
- **iPad:** `TARGETED_DEVICE_FAMILY = "1,2"` means the app ships on iPad, needs iPad screenshots, and may be reviewed on an iPad. **Recommendation:** iPhone-only for v1.
- **Landscape:** `Info.plist` also allows landscape on iPhone, and Android has no orientation lock. Confirm the layouts work in landscape, or lock to portrait.

### 12. Free users without an account lose data on Android reinstall
- **Where:** `android:allowBackup="false"`.
- **What's wrong:** on Android, a free user with no account loses everything on reinstall or a new phone. On iOS, the documents folder is included in normal iCloud device backups.
- **Fix:** this is a product decision. If you keep it, make sure onboarding is honest about it.

---

## 🟡 Housekeeping

- `GOOGLE_PLAY_RELEASE_CHECKLIST.md` and `RETROSPECTIVE_PRD_GOOGLE_PLAY_PREMIUM_READINESS.md` still describe the `verify-purchase` flow. Update them to the RevenueCat flow, and decide whether to delete the dead function.
- Add `ITSAppUsesNonExemptEncryption = false` to `Info.plist` to skip the export-compliance question on every upload.
- Add an app-level `PrivacyInfo.xcprivacy` privacy manifest.
- The `RunnerTests` bundle ID is still `com.example.pebbleRoutinesFresh.RunnerTests`.
- Fix the golden-test overflow and the two `onReorder` deprecations.
- `build_production_aab.ps1` is Windows-only. iOS builds will need a Codemagic (or similar) config with the same dart-defines, plus `REVENUECAT_IOS_API_KEY` starting `appl_`. `main.dart` already enforces that prefix in production.
- `manageSubscriptionsUrl` always points at the current platform's store. A user who bought on Android and opens the app on iPhone gets sent to the wrong store.
- Re-run the live Supabase checks (security advisors, deployed functions, secrets) once the connector responds.

---

## ✅ What's solid

- **Clean code checks:** zero analyzer warnings, and 234 of 235 tests pass.
- **Defensive code:** every `firstWhere` and `.first` call checked has a fallback or guard.
- **Premium is controlled by the server:** RevenueCat sets it, it's mirrored to Supabase, unverified stored Premium is reset to Free in production, and production builds refuse staging URLs or wrong-prefix keys.
- **The RevenueCat webhook checks its authorisation secret.** The sync function checks the user's sign-in token.
- **The backend already understands App Store purchases** (`APP_STORE` and `app_store`).
- **Account deletion is complete:** it removes proof files from storage, deletes the user, and every user table cascades from `auth.users`.
- **Proof photos are safe to keep:** they are re-encoded to strip EXIF and GPS data, and stored as relative paths (which matters on iOS, where the app container path changes on update).
- **Sentry is locked down:** no PII, no screenshots, and the user is removed from events.
- **The paywall meets Apple's subscription rules:** it has auto-renew wording, a Restore button, and Terms and Privacy links.
- **iOS permission texts are present** for camera, microphone, photos and photo saving.

## Suggested next sessions

1. **iOS blockers 1–5.** Code and config only. I can do all of it from here, apart from the dashboard steps (Apple, Google Cloud, Supabase, RevenueCat), which come back to you as a checklist.
2. **Should-fix items 6, 9, 10**, plus decisions on 8, 11 and 12.
3. **Visual UX walkthrough.** Run the app here, take screenshots of every screen, and review flow and polish.
4. **Store paperwork:** privacy policy update, Data safety form and privacy labels, listing copy, screenshots.
