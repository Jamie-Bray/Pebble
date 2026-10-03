# Visual Walkthrough

**Date:** 3 October 2026
**Question this answers:** Does Pebble look and behave ready for Google Play and the App Store?
**Companion to:** `LAUNCH_READINESS_AUDIT.md`, the code audit. This report repeats none of its findings.

## Verdict

On a standard iPhone at the default text size, Pebble looks finished. The serif headlines, sage palette, player, templates and legal pages feel calm and considered, and nothing looks like a placeholder. Problems show up in three places:

- **Smaller phones.** On a common 360×640 Android screen, Home's **Start** button is cut off whenever a routine is in progress.
- **Larger text sizes.** At iOS/Android "Larger Text" settings, Home, the bottom bar, the routine list, the paywall button and the photo-step instructions overflow or get clipped. At 200%, Home loses its Start button entirely.
- **Trust and edge states.** The run detail screen says "4 / 4 steps done" for a run where a step was skipped. The paywall shows "Loading" forever when the store can't load, with the error message hidden at the bottom of the page.

None of this is a big redesign. I'd estimate 2–3 focused days of layout and copy fixes. Do the 🔴 items before submitting.

## How this was done

- Every screen was rendered from the **real app**: the real router, theme and screens, an in-memory database seeded with 3 routines, 8 history runs and 6 reminders, and fake store and sign-in services. This used a capture harness, `test/walkthrough/walkthrough_screens_test.dart`. It is skipped in normal `flutter test` runs unless `WALKTHROUGH=1` is set.
- Two phone sizes: **iPhone 390×844 @3x** (iOS look, 47pt notch and 34pt home bar) and **small Android 360×640 @2x**. Large text was tested at **1.6×** and **2.0×**. All 22 themes were rendered on Home, and 3 of them on the player, history and composer.
- Real fonts were used: Outfit, DM Sans and DM Serif Display, plus the Material and Lucide icon fonts. Text with no font set falls back to **Roboto**. On a real iPhone that text would show in SF Pro, so its widths differ slightly.
- I opened and checked every PNG. Every overflow listed below was also reported by Flutter's layout checker; the per-screen log is in `walkthrough/_layout_errors.txt`. The yellow-and-black overflow stripes appear only in debug builds. In release builds the same content is still cut off, just silently.

---

## 🔴 Must fix before launch

### 1. Small phones: Home's Start button is cut off while a routine is in progress
- **Screen:** `small__home_with_resume.png`. A 360×640 phone at normal text size, after leaving a routine part-way.
- **What's wrong:** the "In progress" resume card pushes the hero section down. The Start button's bottom edge is clipped by 22px and the button sits on top of the "Last completed" line. This is the main button on the main screen, and the problem happens at the default text size.
- **Where:** `lib/features/routines/list/ui/routine_list_screen.dart:2112`, the `home_hero_stage` Column, which has a fixed-height stage.
- **Fix:** let the hero scroll or shrink, or make the resume card more compact on short screens.

### 2. Run detail counts skipped steps as "done"
- **Screens:** `iphone__history_list.png` shows the Morning reset run as **"3 of 4 steps"**. Tapping it (`iphone__history_run_detail.png`) shows **"4 / 4 Steps done"**, even though "Make the bed" was skipped and has a different icon.
- **Why it matters:** Pebble's whole promise is "you can trust what you checked". A record that over-reports completion undermines that promise.
- **Where:** `lib/features/history/ui/routine_run_detail_screen.dart:623-628`. `_completedStepCount` counts `completed || skipped`.
- **Fix:** count completed steps only, and add a visible "Skipped" label on skipped step rows. Right now only an icon shows it.

### 3. Large text breaks Home, the bottom bar and the routine list
The app deliberately allows text scaling up to 3× (the `MediaQuery` clamp in `lib/main.dart` `PebbleApp.build`), so these layouts need to handle it.

- **Home at 1.6×** (`iphone__a11y1.6x_home_routines_sheet_open.png`): every routine card in the "Your Routines" sheet overflows by 22px, and its subtitle ("5 steps / Pinned", "Premium ended…") is cut in half. **Where:** `routine_list_screen.dart:1117`.
- **Home at 2.0×** (`iphone__a11y2.0x_home_premium.png`, `iphone__a11y2.0x_home_populated.png`):
  - the "pebble." wordmark breaks one letter per line, and the tagline breaks mid-word;
  - the hero overflows by 129px, so **the Start button disappears**;
  - the bottom bar labels are cut off ("Histor"). **Where:** `lib/core/navigation/app_shell.dart:155`, which uses a fixed 70px bar height.
- **Empty Home at 2.0×** (`iphone__a11y2.0x_home_empty.png`): the header row overflows 70px to the right and pushes the settings gear off-screen. **Where:** `lib/core/ui/zen_components.dart:59`.
- **Player photo step at 1.6× and 2.0×** (`iphone__a11y1.6x_player_photo_step.png`, `iphone__a11y2.0x_player_photo_step.png`): the instruction "Required to complete this step" is sliced through the middle of the letters. **Where:** `lib/features/routines/execution/ui/routine_player_screen.dart:1577`, a fixed `SizedBox(height: 17)`.
- **Onboarding theme cards at 2.0×** (`iphone__a11y2x_onboarding_2_theme.png`): overflow stripes on all four cards. The crossed-out "habit tracker" headline wraps, so the strike line ends up between two lines (`iphone__a11y2x_onboarding_1_welcome.png`). **Where:** `lib/features/onboarding/ui/onboarding_screen.dart:1988`, and `_StruckWelcomeWord` at `:593`.
- **Fix pattern:** take out fixed heights, let text wrap or scale down in headers (a `FittedBox` on the wordmark), and cap scaling to about 1.3× inside the bottom bar.

### 4. The paywall gets stuck on "Loading" when the store can't load
- **Screens:** `iphone__store_unavailable_paywall.png` and `iphone__store_unavailable_paywall_end.png`.
- **What's wrong:** both plan cards say **"Loading"** and the button says **"Loading store price"**, with no time limit. The real reason ("Could not load store products. Check your connection and try again.") appears only after scrolling to the very bottom. There is no Retry button, and "Restore purchase" is greyed out.
- **Why it matters:** App Review often tests in a sandbox where products are slow or missing. A paywall that never resolves is a common reason for a 2.1 rejection.
- **Where:** `lib/features/subscription/ui/pebble_paywall.dart:1874-1879` for the labels, and `:412` for where `unavailableReason` is read.
- **Fix:** once loading has failed, show "Prices unavailable" with the reason right next to the button, plus a **Try again** button.

### 5. Paywall at large text: the buy button is clipped and the price footer takes over the screen
- **Screens:** `iphone__a11y2.0x_paywall.png` and `iphone__a11y1.6x_paywall_scrolled.png`.
- **At 2.0×:** "Continue with £29.99/year" wraps and its second line is cut off. The "Annual" label collides with the "BEST VALUE" badge. The pinned price footer covers about two-thirds of the screen, so the feature list scrolls in a narrow strip.
- **At 1.6×:** the comparison chip breaks the word "Unlimite / d".
- **On the small phone at normal size** (`small__paywall.png`), the footer already takes about half the screen.
- **Where:** `pebble_paywall.dart:453` (`_PricingFooter` set as `bottomNavigationBar`) and `:1644` (fixed `height: 58`).
- **Fix:** let the button grow in height, and make the footer scroll with the content when there isn't enough room.

### 6. The Settings title is hidden behind the back button on iPhone
- **Screen:** `iphone__settings.png`. The back button covers the "S" of "Settings".
- **Where:** `lib/core/ui/zen_components.dart:54`. `ZenScreenHeader` uses a fixed top padding of 84 that doesn't allow for the notch.
- **Fix:** add `MediaQuery.paddingOf(context).top`, or use the same `PebbleSubscreenAppBar` as Account and Backup.

### 7. iOS: "Pin to Widget" is offered, but there is no iOS widget
- **Screen:** `iphone__home_routine_actions_menu.png` shows "Unpin from Widget – Remove this routine from your home widget".
- **What's wrong:** `ios/` has no WidgetKit extension. Only Android has `pebble_routine_widget_info.xml`. On iPhone this promises a feature that doesn't exist, and reviewers do tap every menu item.
- **Where:** `routine_list_screen.dart:1617`.
- **Fix:** on iOS, either hide the option or call it "Pin to top".

---

## 🟠 Should fix

### Contrast and legibility
- **Secondary text is far too faint.**
  - "Last completed 3h ago • 5 of 5 steps" on Home is drawn at 24% opacity. I measured about **1.6:1** contrast; the minimum guideline is 4.5:1. **Where:** `routine_list_screen.dart:2523-2566`. The same faintness affects "Hold to reorder" (`:910`), "History is only kept for 2 days" (`lib/features/history/ui/styled_history_screen.dart:1409`) and the step-row "Steps" label.
  - The **High Contrast Dark** theme still shows this line at about 1.9:1 (`iphone__theme_15_highContrastDark_home.png`), which defeats the point of an accessibility theme.
  - Colour Blind Safe and Oatmeal & Walnut have nearly invisible taglines and step rows.
- **The paywall's auto-renew notice is hard to read in dark themes** (`iphone__dark_nordic_paywall.png`). Apple's rule 3.1.2 wants this notice to be clear and conspicuous. Use a stronger text colour.
- **The bottom bar stops above the iPhone home indicator.**
  - A strip of page background shows below the bar (`iphone__home_populated.png`).
  - On History, list content shows through that strip below the bar (`iphone__theme_nordicNight_history.png`).
  - **Where:** `app_shell.dart:89`. The `SafeArea` wraps the bar, so the bar's background doesn't extend under the inset.

### Flows and dead ends
- **History disappears when there are no routines.** The bottom bar is hidden when the routine list is empty (`app_shell.dart:30-34,67`). If a user deletes all their routines, their saved runs can no longer be reached (`iphone__history_empty.png` was only reachable from code).
- **Returning users have a hard time finding sign-in.**
  - "Your account" offers no sign-in when signed out (`iphone__account_hub_signedOutFree.png`). This is deliberate (`lib/features/account_backup/ui/account_hub_screen.dart:270`).
  - The Backup screen locks "Sign in" behind "Get Premium first" (`iphone__cloud_backup_signedOutFree.png`, `lib/features/account_backup/providers/backup_dashboard_presentation_provider.dart:243`).
  - A Premium user on a new phone has to work out for themselves that the path is Restore, then Sign in, then Restore backup.
  - **Fix:** add an "Already have Premium? Restore & sign in" link on both screens.
- **The sign-in screen promises backup, but backup is Premium-only.** It says "Sign in to back up your data", and its bullets sell Premium features (`lib/features/auth/ui/sign_in_screen.dart:318`, `iphone__sign_in.png`). A free user who signs in gets no backup. Reword the screen, for example "Sign in to keep your account ready for backup".
- **Sign-in on the small phone:** "Continue with Google" sits at the fold and "Continue with Email" is off-screen (`small__sign_in.png`).
- **The "Delete reminder" button is cut off** at the bottom of the Edit reminder sheet on iPhone (`iphone__reminder_editor_existing.png`, `lib/features/routines/list/ui/reminder_editor_sheet.dart:446`).
- **The red trash icon in the top-right of every Reminders and Email screen** is a one-tap destructive action next to Back (`iphone__reminders_global.png`, `iphone__routine_email_alerts_from_home.png`). Make sure it asks for confirmation, or move it into a menu.
- **The Premium account screen is nearly empty** (`iphone__account_hub_signedInPremium.png`). It shows no plan card, renewal date or backup status. "Personal Premium" appears only in grey small print.

### Copy and consistency
- **Two different home headers.**
  - Empty Home shows "Pebble" in sans with "Small routines. Lasting ripples." and a gear icon (`lib/core/ui/zen_components.dart:15-17`).
  - Populated Home shows the italic serif "pebble." with "Small steps, big ripples" and a sliders icon (`routine_list_screen.dart:746, 760`).
  - Compare `iphone__home_empty.png` with `iphone__home_populated.png`. Pick one wordmark, one tagline and one settings icon.
- **Inconsistent product names:**
  - "Pebble Premium", "Personal Premium" and "Premium" (`iphone__home_style_upsell_free.png`: "See Personal Premium"; `iphone__home_create_choice_sheet.png`: "View Pebble Premium").
  - "Voice tip" (composer), "Play guidance" (player) and "guidance audio" (privacy page).
  - "Annual" on the paywall card vs "Yearly" from the store.
- **Mixed capitalisation:** "Delete Account", "Reorder Steps", "Save Changes", "Steps Completed", "Evidence Saved" and "Keep Your Recent History" are in Title Case, while the rest of the app uses Sentence case.
- **Mixed spelling:** UK "colours" and "personalise" next to US "customize", "colors" and "recognizable" (`iphone__onboarding_4_starter_preview.png`, `iphone__home_style_studio_premium.png`).
- **Onboarding:**
  - "Continue onboarding" is developer jargon (`onboarding_screen.dart:1002`, `iphone__onboarding_possibilities.png`). Use "Continue" or "Set up Pebble".
  - The starter **"Everyday Departure Check"** has 4 steps (`onboarding_screen.dart:42-47`), but the template with the same name has 10 (`assets/seed/templates_en.json`, `iphone__template_detail.png`). Rename one of them, or make them match.
  - 3 of the 4 starter steps require a photo, which is a heavy first routine.
  - The step 4 title ("Here's how this could work") is in sans, while steps 1–3 use the serif.
- **Composer:**
  - The voice-tip chip reads "✓ Voice tip ✓" (two checks) and is tinted red, which reads as an error (`lib/features/routines/composer/ui/routine_composer_step_row.dart:214`).
  - The "Required" / "Optional" chip is about skipping, but it sits next to "Require photo", so it's easy to misread (`:197`).
  - Steps show unlabelled small circles (`iphone__composer_edit.png`).
  - "Require photo" is drawn at a smaller size than its neighbouring chips.
- **The Email alerts preview uses a hard-coded sample.** It reads "09 May 2026, 21:07" and claims "Verified & Complete" (`lib/features/routines/list/ui/routine_reminders_screen.dart:848, 900, 924, 947`). Use today's date and less absolute wording. Email alerts are also a Premium feature that the paywall never mentions.
- **"Premium ended" screen tone** (`iphone__account_hub_premiumEnded.png`). The red "A few things are at risk." with "Your history is fading… Locked now unless you renew" is alarming and unclear (`account_hub_screen.dart:984-995`). The very faint grey card title is also hard to read.
- **Settings** subtitle "System configurations & preferences" is jargon (`lib/features/settings/ui/settings_screen.dart:78`). Settings also has no Account, Restore or Contact support row.
- **About Pebble** links only to email (`lib/features/settings/ui/legal_about_screen.dart:12`). Add links to the full Privacy Policy and Terms web pages; Apple expects a privacy policy to be reachable in the app, not only on the paywall.

### Visual polish
- **Theme picker:** the "Free" badge sits on top of each card's accent pill (`lib/features/settings/ui/appearance_screen.dart:489, 539`). The selected checkmark on High Noon covers its pill too (`iphone__appearance_scrolled.png`).
- **Theme names don't match their colours.** Several dark themes are near-identical warm browns: Nordic Night, Midnight Slate, Amber Resin, Terracotta and Dusk (`iphone__theme_01…`, `_06`, `_07`, `_10`, `_13`). "Nordic" and "Slate" suggest blue.
- **The Backup screen (Premium) is self-contradictory.** It shows green ticks next to "0 of 3 backed up" and "Waiting for first backup", under "Last backed up 4m ago" (`iphone__cloud_backup_signedInPremium_scrolled.png`, `backup_dashboard_presentation_provider.dart:534-551`). Only show a tick when the item has actually been backed up.
- **The iOS switches are bright system green** (Settings, Backup), which clashes with the sage palette.

---

## 🟡 Nice to have

- The completion screen shows "Evidence Saved: 0 Photos" even for routines with no photo steps (`routine_player_screen.dart:2195`, `iphone__player_complete.png`).
- The "Complete step" button jumps about 13px between step 1 and step 2, because the empty "Previous" row collapses (`iphone__player_step1.png` vs `iphone__player_step2.png`).
- Floating back buttons on the paywall and templates have no backdrop, so scrolled content passes under them (`iphone__paywall_end.png`).
- The tagline wraps to 3 lines on small phones and when the "Checking backup" chip is showing (`small__home_premium.png`).
- Onboarding starter descriptions are cut off with "…" (`iphone__onboarding_3_starting_point.png`).
- Locked routine cards and the locked screen always say "Premium ended" (`routine_list_screen.dart:1057`, `lib/main.dart` `_RoutineLockedScreen`). That's correct today, but it will read oddly if free users ever exceed the limit some other way.

## ✅ What looks great

- **Routine player:** big, calm, one-step-at-a-time layout, a clear progress bar and a good photo step. The leave prompt ("Leave and save / Stay here / Discard progress") and the "In progress – Resume" card on Home are excellent.
- **Typography and palette:** the DM Serif headlines with sage and ivory feel premium and distinctive. The default High Noon and Sandstone themes look polished.
- **Paywall structure:** a clear Free → Premium comparison per feature, correct per-month maths ("£2.50/month"), and the auto-renew, Restore, Terms and Privacy items in the right places.
- **Templates** gallery and detail are clean, scannable and well grouped.
- **Account deletion** is a clear, honest confirmation sheet that says exactly what is and isn't removed.
- **The legal pages** are in genuinely plain English.
- **Empty states** ("Start with one routine.", "No routine runs yet", "No reminders yet") are friendly and give one clear action.
- **The reminder editor** has a good "Every Monday at 8:15 AM. First one tomorrow." summary.

---

## Screenshots

Every file is in `/tmp/claude-0/-home-user-Pebble/9a8b8ff9-3225-56eb-9871-700f36e32791/scratchpad/walkthrough/`: 179 PNGs plus `_layout_errors.txt`. The `iphone__` prefix means 390×844 @3x; `small__` means 360×640 @2x; `a11y1.6x_`, `a11y2.0x_` and `a11y2x_` mean large text.

| Screen | Files |
|---|---|
| Onboarding | `iphone__onboarding_1_welcome[_scrolled]`, `_2_theme[_scrolled]`, `_3_starting_point[_scrolled]`, `_4_starter_preview[_scrolled]`, `iphone__onboarding_possibilities[_scrolled/_end]`; the same 8 files with `small__`; the same 8 with `iphone__a11y2x_` |
| Home | `iphone__home_populated`, `home_empty`, `home_premium`, `home_routines_sheet_open`, `home_premium_routines_sheet_open`, `home_create_choice_sheet`, `home_with_resume`, `home_routine_actions_menu`, `home_style_upsell_free`, `home_style_studio_premium`; `small__home_populated/_empty/_premium/_routines_sheet_open/_with_resume`; `iphone__a11y1.6x_home_populated/_premium/_routines_sheet_open/_with_resume`, `iphone__a11y2.0x_home_populated/_premium/_routines_sheet_open/_empty` |
| Composer & reorder | `iphone__composer_new`, `composer_edit[_scrolled]`, `composer_edit_free`, `composer_photo_step_expanded`, `composer_plain_step_expanded`, `composer_voice_tip_free`, `composer_voice_tip_recorder`, `small__composer_edit`, `iphone__reorder_steps` |
| Player | `iphone__player_step1`, `player_step2`, `player_photo_step`, `player_photo_step_free`, `player_voice_step`, `player_leave_prompt`, `player_complete`, `player_locked_routine`; `small__player_step1/_photo_step`; `iphone__a11y1.6x_` and `iphone__a11y2.0x_` `player_step1/_photo_step` |
| History | `iphone__history_list[_scrolled]`, `history_empty`, `history_run_detail[_scrolled]` |
| Reminders | `iphone__reminders_global[_scrolled]`, `reminders_global_empty`, `reminder_new_step1`, `reminder_editor_sheet`, `reminder_editor_existing`, `routine_reminders_from_home`, `routine_email_alerts_from_home`, `routine_email_alerts_premium` |
| Templates | `iphone__templates_gallery[_scrolled]`, `template_detail[_scrolled]` |
| Paywall | `iphone__paywall[_scrolled/_end]`, `iphone__store_unavailable_paywall[_scrolled/_end]`, `small__paywall[_scrolled/_end]`, `iphone__a11y1.6x_paywall[…]`, `iphone__a11y2.0x_paywall[…]`, `iphone__dark_nordic_paywall[…]` |
| Sign-in | `iphone__sign_in[_scrolled]`, `sign_in_email_sheet`, `small__sign_in` |
| Account hub | `iphone__account_hub_{signedOutFree,signedInFree,signedInPremium,premiumEnded}[_scrolled/_end]`, `account_delete_confirm`, `small__account_hub_premiumEnded` |
| Cloud backup | `iphone__cloud_backup_{signedOutFree,signedInFree,signedInPremium,premiumEnded}[_scrolled]` |
| Settings / appearance / legal | `iphone__settings[_scrolled]`, `appearance[_scrolled/_end]`, `appearance_premium`, `legal_about[_scrolled/_end]`, `legal_about_terms`, `legal_about_delete[_scrolled]` |
| Themes | `iphone__theme_00_highNoon_home` … `iphone__theme_21_sandstone_home` (all 22); `iphone__theme_{nordicNight,highContrastDark,sandstone}_{player,history,composer}` |

### Not rendered, and why
- **Native system UI:** the camera, photo library picker, notification and microphone permission prompts, Google and Apple sign-in sheets, and the App Store / Play purchase sheet are drawn by the OS or plugins, which don't exist in a widget test.
- **Real proof photos:** Photo Vault and run-detail photo thumbnails need real image files, so the seeded runs have no photos.
- **The email code-entry step:** only the "Sign in with email" address sheet was captured.
- **The home-screen widget, landscape and iPad layouts:** not captured. Landscape and iPad are a pending decision in audit item 11.
- **The Backup screen for a Premium user** is shown in its "Checking backup" state, because there's no live server in the harness. The contradictory ticks it shows are real presentation logic, but the "Checking" wording itself comes from the harness.

### Re-running the capture
```
WALKTHROUGH=1 FLUTTER_TESTER_REAL_FONTS=1 WALKTHROUGH_OUT=<dir> WALKTHROUGH_FONTS=<fonts dir> \
  flutter test test/walkthrough/walkthrough_screens_test.dart
```
`flutter test` always forces the Ahem test font, so text with no font set renders as black boxes. The screenshots above were taken with a locally patched Flutter SDK (in the scratchpad, not the repo) that drops that flag when `FLUTTER_TESTER_REAL_FONTS=1` is set. The harness header explains this. Without the patch, those button labels render as boxes.
