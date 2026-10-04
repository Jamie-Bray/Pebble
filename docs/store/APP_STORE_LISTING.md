# App Store Listing: Pebble Routines (iOS)

Last updated: 3 October 2026

Ready-to-paste copy for App Store Connect. Limited fields are in fenced blocks
with a `limit` marker; run `python3 docs/store/check_limits.py` after any edit.
The same copy rules as `GOOGLE_PLAY_LISTING.md` apply: no medical claims, no
"OCD" or "anxiety", no "peace of mind" promise, and backup always comes with
"Premium, sign in, and turn it on".

> **iOS status at this commit (after merging `claude/sharp-keller-f6iiu2`):**
>
> - **Bundle ID:** `com.vix.pebbleroutines` (Android keeps
>   `com.vix.pebble_routines`). Use it for the App Store Connect record, the
>   RevenueCat iOS app, the Supabase Apple client ID and the Google iOS OAuth
>   client (`IOS_SETUP_CHECKLIST.md`).
> - **Sign in with Apple is offered on iOS** (`sign_in_screen.dart`,
>   `Runner.entitlements`), above Google and Email. It requests the email scope
>   only. The Supabase Apple provider still has to be enabled
>   (`SUPABASE_LIVE_AUDIT.md`, owner task 1).
> - **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are
>   needed.
> - **iOS builds** come from `codemagic.yaml`, which requires
>   `REVENUECAT_IOS_API_KEY` (`appl_...`) and passes `SENTRY_DSN` when it is
>   set.
> - **Privacy manifest:** `ios/Runner/PrivacyInfo.xcprivacy` declares no tracking,
>   the collected data types in `APP_PRIVACY_LABELS.md`, and the UserDefaults
>   (`CA92.1`) and file timestamp (`C617.1`) required-reason APIs.
> - **Review risk:** `VISUAL_WALKTHROUGH.md` item 4. The paywall stays on
>   "Loading" when sandbox products don't load, which is a common 2.1
>   rejection. Fix it before you submit.

---

## App name (max 30)

<!-- limit:30 id:ios-name -->
```text
Pebble Routines: Checklist
```

## Subtitle (max 30)

<!-- limit:30 id:ios-subtitle -->
```text
Leaving-home checks & photos
```

Alternative:

<!-- limit:30 id:ios-subtitle-alt -->
```text
Did I lock the door? Check it
```

If you use the alternative subtitle, rebuild the keyword field. "lock",
"door", and "did" would then repeat words that are already indexed.

## Promotional text (max 170)

You can change this at any time without a new build.

<!-- limit:170 id:ios-promo -->
```text
Did I lock the door? Unplug the straighteners? Go through your leaving-home checks step by step, add a photo, and see exactly when you did each one.
```

## Keywords (max 100)

Comma separated, no spaces. Apple already indexes the name and subtitle, so
none of these repeat: pebble, routines, checklist, leaving, home, checks,
photos. Plurals are matched automatically, so only one form of each word is
used.

<!-- limit:100 id:ios-keywords keywords exclude:ios-name,ios-subtitle -->
```text
door,lock,straightener,hair,stove,oven,unplug,iron,heater,house,reminder,did,leave,off,bedtime,trip
```

Deliberately left out: "ocd", "anxiety", "worry", "safety", "proof". The
first three would position Pebble as a health product and risk a medical
claims rejection. "Safety" suggests a safety system. "Proof" pulls in
evidence and legal searches.

## Description (max 4000)

The App Store does not index the description for search, so this is written
for people reading it. The Terms of Use and Privacy Policy links are needed
for auto-renewable subscriptions.

<!-- limit:4000 id:ios-description -->
```text
Did I lock the door? Did I unplug the hair straighteners? Is the stove off?

Pebble Routines turns the checks you do before leaving the house into a simple, step-by-step checklist. Go through each step, mark it done, and add a photo when you want something to look back on later. Every completed check is saved with the time you did it.

Pebble is for anyone who has turned back at the front door to check it again, or taken a photo of the straighteners just in case.

HOW IT WORKS
• Create a routine. For example "Leaving the house": straighteners or curling iron unplugged, stove and oven off, windows shut, back door locked, front door locked.
• Run it step by step. One clear screen per step, so the next check is always obvious.
• Add a photo on any step. Take it in the moment, or choose one you already have.
• Look back. Recent history shows what you checked and when.

READY-MADE ROUTINES YOU CAN EDIT
• Everyday departure check: hair tools, stove and oven, toaster, sink, heaters, windows and doors
• Bedtime house check
• Car lock and parking check
• Hotel checkout sweep
• Big trip home shutdown
• School morning run, gym bag, morning pet routine, office switch-off and more

USEFUL EXTRAS
• Reminders: a notification at the time you usually leave
• Voice prompts: record a short note in your own voice for any step (Premium)
• Save a copy to Photos: keep a photo from Pebble in your own library
• Themes, including accessibility themes

PRIVATE BY DEFAULT
• Works without an account. No sign-up needed to start.
• Your routines, history and photos are stored on this device.
• No ads. No tracking. Pebble does not sell your data.
• On the free plan, photos and history are kept for 48 hours, then Pebble deletes its own copies. Pebble never deletes anything from your photo library.
• Cloud backup only starts if you have Premium, sign in, and choose to turn it on.

FREE
• 2 routines, up to 10 steps each
• 1 photo per step
• 48 hours of recent history
• Reminders and ready-made routines

PERSONAL PREMIUM (MONTHLY OR YEARLY)
• Unlimited routines and steps
• Up to 4 photos per step
• 21 days of recent history
• Voice prompts on any step
• Extra themes
• Optional cloud backup and account recovery (needs sign-in and your consent)
• Completion emails: Pebble can email one contact when a routine is done. They accept first, and can stop the emails at any time. Photos and checklist details are not included.

Payment is charged to your Apple Account when you confirm the purchase. Premium renews automatically unless you turn off auto-renew at least 24 hours before the end of the current period. You can manage or cancel it in your App Store account settings. Pebble keeps working on the free plan without Premium.

WHAT PEBBLE IS, AND IS NOT
Pebble is a routine and checklist app. It is not a medical app or treatment, a home security system, or an emergency service, and photos in Pebble are not legal evidence. If checking is taking up a lot of your day, a doctor or other qualified professional can help.

Terms of Use: https://pebbleroutines.com/terms
Privacy Policy: https://pebbleroutines.com/privacy
```

The home-screen widget is Android only, so it is not in the iOS description.

## URLs and categories

| Field | Value |
| --- | --- |
| Primary category | Productivity |
| Secondary category | Lifestyle |
| Support URL | `https://pebbleroutines.com/support` |
| Marketing URL | `https://pebbleroutines.com` |
| Privacy Policy URL | `https://pebbleroutines.com/privacy` |
| License Agreement | Apple's standard EULA. Terms of Use are linked in the description |
| Copyright | `2026 Jamie Bray` (confirm the legal name; see `OWNER_NOTES.md`) |
| Price | Free, with in-app subscriptions |

## Age rating answers

App Store Connect > App Information > Age Rating. Wording follows the 2025
questionnaire; the labels in App Store Connect may differ slightly.

| Section | Question | Answer |
| --- | --- | --- |
| In-app controls | Parental controls | No |
| In-app controls | Age assurance | No |
| Capabilities | Unrestricted web access | No (links open legal pages and Apple's subscription settings in Safari) |
| Capabilities | User-generated content shared with other users | No. Routines, photos and history are private to the user. Completion emails send only a routine name, time and step count to one contact who accepted, with stop and block links. There is no public content, feed or profile. |
| Capabilities | Messaging and chat | No |
| Capabilities | Advertising | No |
| Mature themes | Profanity or crude humour | None |
| Mature themes | Horror or fear themes | None |
| Mature themes | Alcohol, tobacco, or drug use or references | None |
| Medical or wellness | Medical or treatment information | None. The "Medication Check" template is an ordinary checklist ("Take medication") with no dosing or treatment content |
| Medical or wellness | Health or wellness topics | No |
| Sexuality or nudity | All questions | None |
| Violence | All questions (cartoon, realistic, graphic, weapons) | None |
| Chance-based activities | Simulated gambling, gambling, contests, loot boxes | None / No |
| Made for Kids | Is this app made for kids? | No |

Expected rating: **4+**.

## App Review notes

App Store Connect > App Review Information > Notes. No demo account is needed,
so leave "Sign-in required" unticked.

<!-- limit:4000 id:ios-review-notes -->
```text
Thank you for reviewing Pebble Routines.

WHAT THE APP DOES
Pebble is a local-first checklist app for everyday routines such as "Leaving the house" (straighteners unplugged, stove off, front door locked). Users run a routine step by step, can add a photo to a step, and see recent history with completion times. It is not a medical, safety, or emergency app.

NO ACCOUNT NEEDED
Every core feature works without signing in. Sign-in is optional and is only used for Premium cloud backup, account recovery, and completion emails. Options: Sign in with Apple, Google, or an email one-time code (any email address works).

FREE VS PREMIUM
Free: 2 routines, 10 steps per routine, 1 photo per step, 48 hours of history.
Personal Premium (auto-renewable, monthly or yearly, subscription group "Pebble Premium"): unlimited routines and steps, up to 4 photos per step, 21 days of history, recorded voice prompts, extra themes, and optional cloud backup and completion emails after sign-in.

HOW TO REACH THE SUBSCRIPTION SCREEN
Any of these:
1. Tap "Your account" (top of the home screen), then "Get Premium".
2. Create a third routine. The routine limit opens the Premium screen.
3. In a routine, add a second photo to one step.
4. While editing a step, tap the voice prompt option.

TESTING THE SUBSCRIPTION IN SANDBOX
1. Sign in with a Sandbox Apple Account (Settings > Developer > Sandbox Apple Account, or when prompted at purchase).
2. Open the Premium screen and choose Monthly or Yearly.
3. Confirm the sandbox purchase. Premium unlocks straight away; signing in is not required.
4. To test restore: delete and reinstall the app, open the Premium screen, and tap "Restore purchase".
Purchases are processed by StoreKit through RevenueCat. Cloud backup additionally needs sign-in and the user turning backup on; backup may take a few seconds to confirm the subscription with our server.

SUGGESTED DEMO (2 MINUTES)
1. Open the app. Skip sign-in.
2. Choose the "Everyday Departure Check" starter routine.
3. Tap Start. Mark the first step done. On a photo step, take or choose a photo (camera and photo permissions are requested only at this moment, with an explanation first).
4. Finish the routine and open History to see the completion time and photo.
5. Optional: open the routine's reminders and set a reminder (notification permission is requested at this moment).

COMPLETION EMAILS (PREMIUM, SIGNED IN)
In a routine's reminders screen, "Notify someone when you finish" lets the user enter one email address. Pebble sends an invitation first; completion emails start only after the recipient accepts. Each email has links to stop the emails or block the sender. Emails contain the routine name, time and step count only.

PERMISSIONS
Camera: proof photos. Photo library: choosing an existing photo and "Save a copy to Photos". Microphone: recording a voice prompt (Premium). Notifications: reminders. No tracking, no ads, no location.

ACCOUNT DELETION
Your account > Delete Account. A web request form is also at https://pebbleroutines.com/delete-account.

Contact: support@pebbleroutines.com
```

Before submitting, check every path in these notes on a TestFlight build.
In particular, confirm the voice prompt entry point and the "Your account"
label are what iOS users see.

## Subscription group and products

App Store Connect > Monetization > Subscriptions.

| Item | Value |
| --- | --- |
| Subscription group reference name | Pebble Premium |
| Group display name (localisation) | see below |
| Level | Both products at level 1 (same features, different durations). Apple then treats a switch between them as a crossgrade. |
| Product IDs | TODO (owner): choose IDs, for example `personal_premium_monthly` and `personal_premium_yearly`. Keep "monthly" / "yearly" in the IDs: the app falls back to matching those words if a RevenueCat package type is missing. |
| RevenueCat | Attach both products to entitlement `personal_premium` and to the Monthly and Annual packages of the current offering |
| Prices | TODO (owner) |
| Free trial / intro offer | None in the current code or paywall copy. If you add one, update the paywall, description and review notes. |
| Review screenshot | A screenshot of the Premium screen showing price and "Restore purchase" |

Group display name (shown in Apple's subscription settings):

<!-- limit:30 id:ios-sub-group-name -->
```text
Pebble Premium
```

Monthly display name:

<!-- limit:30 id:ios-sub-monthly-name -->
```text
Personal Premium Monthly
```

Monthly description:

<!-- limit:45 id:ios-sub-monthly-desc -->
```text
Unlimited routines, 21-day history, backup
```

Yearly display name:

<!-- limit:30 id:ios-sub-yearly-name -->
```text
Personal Premium Yearly
```

Yearly description:

<!-- limit:45 id:ios-sub-yearly-desc -->
```text
A year of unlimited routines and backup
```

## Screenshots

Use the eight captions from `GOOGLE_PLAY_LISTING.md`, except caption 7 (the
widget is Android only). For caption 7 on iOS, use:

<!-- limit:40 id:ios-shot-7 -->
```text
Record a voice prompt for any step
```

Screen: step editor with the voice prompt recorder open.

Required size: 6.9" (1320 x 2868) or 6.7" iPhone. The app is iPhone only
(`TARGETED_DEVICE_FAMILY = 1`), so iPad screenshots are not needed.
