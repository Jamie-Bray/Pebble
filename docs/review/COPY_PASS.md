# Copy pass (work in progress)

Branch: `fix/copy-pass`. This pass was stopped early, so it is **not finished
and not fully checked**. Read "Status" first.

## Status

- All 235 screens were rendered and every string in `lib/` was read before
  editing. The screenshots were taken before the edits, so the new wording has
  not been checked on screen.
- `flutter analyze` currently reports 5 style notes ("add const") in
  `styled_history_screen.dart` (lines 76, 83, 84) and `routine_list_screen.dart`
  (line 274). They need the word `const` added; nothing is broken.
- `flutter test`: 5 tests still expect the old wording and fail (plus the known
  local-only golden). They need their expected text updated:
  - `account_backup_state_test.dart:2611` (old "Supabase rejected the backup write" message)
  - `routine_composer_screen_test.dart` ("Add step creates the next one")
  - `routine_player_guidance_audio_test.dart` ("Camera access is turned off")
  - `premium_lapse_test.dart:78` ("this phone" is now "this device")
  - `pebble_paywall_test.dart:329` (sign-in prompt after purchase)
- The walkthrough has not been re-run after the edits. It taps text such as
  "Your Routines", which was left unchanged on purpose.
- The full before/after table with file and line numbers has not been written.
  Until it is, the exact list is the diff of this branch against
  `review/gemini-handover-assessment`.

## What changed (grouped)

| Area | Before | After |
|---|---|---|
| Whole app (about 50 places) | "this phone" | "this device" (matches the guidelines and works on tablets) |
| Whole app (about 35 places) | "... Please try again." | "... Try again." |
| Style picker, routine menu | colors, personalize, recognizable, "Accent color" | colours, personalise, recognise, "Accent colour" |
| Sign-in | "Finalizing your setup..." | "Finishing setup..." |
| Sign-in | "Back up up to 21 days of completed routines." | "Back up the last 21 days of completed routines." |
| Sign-in, paywall | "Your Account" | "Your account" |
| Error messages | "not available in this build" | "not available in this version" |
| Backup error | "Supabase rejected the backup write. Check cloud consent and the server entitlement for this account." | "Backup could not save your changes. Check that backup is turned on for this account, then try again." |
| Backup | "Your routines are kept safe for restore." | "Your routines are backed up for restore." |
| Backup | "One tap and Pebble starts keeping a safe copy of your routines." | "One tap and Pebble starts backing up your routines." |
| Backup | "What backup keeps safe for 21 days" | "What backup keeps for 21 days" |
| Backup | "If you lose or change your phone, they come back with you." | "... you can restore them." |
| Backup | "Pebble needs your explicit consent before uploading routines, proof photos, history, or metadata..." | "Backup can include private details, so Pebble asks you to confirm before it starts." |
| Backup | "Pebble could not check your cloud backup consent yet." | "Pebble could not check your backup setting yet." |
| Account | "Local Premium is unlocked on this device." | "Premium is unlocked on this device." |
| Account | "Pebble is double-checking your purchase with Google Play." (also shown on iPhone) | "Pebble is checking your purchase with the store." |
| Account | "Your longer history is still available during grace." | "... still available for now." |
| Account | "You have not done anything wrong. This build is waiting for store setup." | "Nothing is wrong on your side. Premium is not available in this version yet." |
| Sign out | "Everything already backed up stays safe" | "Everything already backed up is kept" |
| Store errors | "Purchases are not configured for this platform yet." / "Premium is not configured correctly yet." | "Purchases are not available on this device yet." / "Premium is not available right now." |
| Paywall headline | "Never wonder twice." | "Keep more, for longer." |
| Paywall | "Three weeks of answers, safe if you reinstall or change phone." | "Three weeks of history, with a backup to restore if you reinstall or change phone." |
| Paywall | "Four angles when one picture cannot prove the whole check." | "Up to four photos when one picture cannot show the whole check." |
| Paywall | "Premium gives you more proof when..." | "Premium lets you add up to four when..." |
| Paywall | "voice prompt", "future-you" | "voice tip", plain wording |
| Paywall (after purchase) | "...keep them ready across devices. Totally optional; Premium works right now without it." | "...so you can restore them on another device. This is optional; Premium works now without it." |
| Limit sheets | "free to use with no login and no ads" | "... no account and no ads" |
| Keep-routines sheet | "Untick one to swap." | "Uncheck one to swap." |
| Onboarding | "Step out the door with total confidence." | "Step out the door knowing what you checked." |
| Onboarding | "you ticked it off" (twice), "photo to be sure" | "you checked it off", "photo taken" |
| Reminders | "Stay on track." / "Reminder rhythm." | "Set a reminder." / "Your reminders." |
| Reminders | "Set up local, secure nudges to ensure your essential routines never slip your mind." | "Pebble can remind you when it is time to run a routine. Reminders are set on this device." |
| Reminders | "Pinpoint timing", "Flexible scheduling", "Scheduled Nudges", "By Day", "Set Time" | "Pick the time", "Pick the days", "Scheduled reminders", "By day", "Set time" |
| Reminders | "Routine reminders and shared notifications" | "Routine reminders and completion emails" |
| Reminders | "Notification permission is required to enable reminders." / "Enable notifications in settings to receive reminders" | "Notifications are off. Turn them on in device settings to get reminders." |
| Reminders | "remove all personal reminders" | "remove all reminders" |
| Running a routine | "Camera access is turned off for Pebble. Allow camera in your phone settings to take photos." | "Camera access is off. Turn it on in device settings to take a photo." (same pattern for Photos) |
| Running a routine | "Pebble Free includes one proof photo per step." with a button labelled "Plus" | "Free includes one photo per step." with "See Premium" |
| Running a routine | "Add more proof photos with Premium", "capture a proof photo" | "Add more photos with Premium", "take a photo" |
| Photos | "This proof photo is no longer available.", "Saved a photo to your phone.", "Something went wrong while saving to Photos." | "This photo is no longer available.", "Saved a copy to Photos.", "Could not save to Photos. Try again." |
| History | tab "Photo Vault", "No proof photos yet" | "Photos", "No photos yet" |
| History | "History is only kept for 2 days" | "Free keeps the last 48 hours of history" |
| History | "View Photos", "Run Photos", "View Routine Run" | "View photos", "Run photos", "View routine run" |
| Load errors | title "A momentary pause", button "Restore Connection", raw technical error text shown | "Something went wrong", "Try again", "Pebble could not load your history/routines. Try again." |
| Routine editor | "New Routine" / "Edit Routine" | "New routine" / "Edit routine" |
| Routine editor | "Record up to 10 seconds of step guidance for this checklist item." | "Record a voice tip of up to 10 seconds for this step." |
| Routine editor | "Add step creates the next one" | "Tap Add step for the next one" |
| Voice tips | "Play guidance", "Guidance audio", "Audio unavailable", "Failed to start/save recording." | "Play voice tip", "Voice tip", "Voice tip unavailable", "Could not start recording. Try again." |
| Create / templates | "ready-made checklist" | "ready-made routine" |
| Home menu | "Pin to Widget" / "Unpin from Widget", "Premium icon and color studio" | "Pin to widget" / "Unpin from widget", "Icons and colours with Premium" |
| Themes | "Amber-tinted contrast for migraines, Irlen, and visual stress." | "A warm amber tint that softens bright whites." (no medical claim) |
| Themes | "...for overwhelm and sensory load." | "...with less visual noise." |
| Website home page | "with proof you locked the door" (twice) | "with a photo of the locked door if you want one" |

## Suggestions not applied

**Load-bearing wording (other code looks for these phrases)**
- `local_data_ownership_guard.dart` and `entitlement_flow_messages.dart`:
  "Premium is active locally. Pebble is waiting for secure purchase verification..."
  and "Pebble will keep existing local data local until you choose how to handle
  this account." read like developer notes. Suggested: "Premium is on. Pebble is
  confirming your purchase." and "Routines already on this device stay here until
  you choose what to do." These need the matchers and tests changed together.
- Theme labels "Legacy warm dark" and "Archived cold dark": the theme screen
  hides themes by looking for those words.
- "Loading store products..." and the "Notification permission denied" message
  are also matched by code.

**Legal wording (owner decision)**
- In-app About/Privacy summary (`legal_about_screen.dart`): "paid entitlement",
  "sync records", "account metadata in Supabase" are jargon; "Pebble is a routine
  support and reassurance app" uses "reassurance", which the guidelines avoid.
- Backup consent sentence ("I understand Pebble backup may save...") left as is.
- `web/privacy.html`, `terms.html`, `delete-account.html`, `support.html` not edited.

**Store and marketing**
- Store listings in `docs/store/` were not reviewed in this pass.
- Website: "Spoken steps and photo proof" / "Hear the next step read out" may
  overstate voice tips (they are short recordings the user makes, Premium only).
  "Coming to Google Play" leaves out the App Store.
- Onboarding and paywall still lean on worry ("The doubt hits...", "The worry
  lands...", "Answers that stick around."). The guidelines advise against
  anxiety-based copy; this is a brand decision.

**Other**
- Server messages "Too many invites today. Please try again tomorrow." and "Too
  many requests. Please try again later." still say "Please" (needs a backend deploy).
- The Free plan is called "Pebble Personal", "Free plan" and "Free" in different places.
- Settings shows a fixed "Version 1.0.0".
- "Your Routines" and "Back to Home" keep capitals (many tests tap them).
- Template steps use "stroller", "mailbox" and "sunscreen"; fine globally, not UK-specific.
