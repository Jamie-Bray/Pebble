# Copy pass: making Pebble sound like one person wrote it

Date: 4 October 2026

The owner felt the app's text read as AI-written: dramatic fragments, "Not X.
Not Y." lines, em dashes, slogans, stacked adjectives, and reassurance that the
copy rules already ban. This pass rewrote the user-facing text in the app, the
website, the completion emails and the store listings so it reads as plain,
specific and a little warm. The voice rules now sit at the top of
`COPY_GUIDELINES.md` under "How Pebble sounds".

## How it was measured

- `docs/review/copy/copy_inventory.py` pulls user-facing strings from `lib/`,
  `web/`, `supabase/functions/` and `docs/store/`. Output:
  `inventory_before.txt` (at `origin/main`) and `inventory_after.txt`.
- `docs/review/copy/ai_tell_score.py` counts tells with simple patterns. Each
  check is documented at the top of the script. It is a guide, not a target:
  it misses tells a reader would catch and flags some lines that are fine. Two
  checks were added after the first run because reading the copy turned up
  tells the regexes missed (hype and reassurance words, stacked adjectives),
  and one was narrowed so plain instructions such as "Try again." are not
  counted as dramatic fragments. Both inventories are scored with the same
  final script.

## Tell counts

| Check | Before | After |
| --- | ---: | ---: |
| Em dashes | 11 | 0 |
| "Not X. Not Y." / "not X, it's Y" | 3 | 0 |
| Hype and reassurance (confidence, never slip your mind, kept safe, ripples, nudges, future-you) | 21 | 3 |
| Stacked adjectives and three-item lists | 44 | 32 |
| Title Case labels | 49 | 22 |
| Buzzwords (ensure, unlock, simply...) | 18 | 14 |
| Dramatic one- or two-word fragments | 8 | 4 |
| "Just" as a softener | 1 | 0 |
| Fragment triplets ("Calm. Clear. Done.") | 1 | 1 |
| Trailing ellipses (not after -ing) | 18 | 18 |
| **All checks** | **174** | **94** |

By area: app 124 to 56, website 34 to 22, emails 9 to 9, store 7 to 7.

What is left is mostly deliberate (see "Left alone" below): legal lists on
the privacy and terms pages, proper names (High Contrast Dark, Personal
Premium Monthly), HTML page titles, store-doc tables and notes that quote
banned phrases, and "unlock" where it describes locked routines literally.
The trailing-ellipsis count is all progress labels ("Signing you in...",
"Search routines...") that the regex can't tell apart from a trailing-off
sentence.

## The 20 most improved lines

| # | Where | Before | After |
| --- | --- | --- | --- |
| 1 | Onboarding welcome | For routines you repeat. / Not goals. Not streaks. | For the checks you / already do. |
| 2 | Onboarding explainer | Step out the door with total confidence. | Every check is saved with the time. |
| 3 | Onboarding explainer | Daily routine or twice-a-year job: Pebble logs each step as you do it, so the doubt that hits later already has an answer. | Use it for the daily leave-the-house check or a job you do twice a year. If you wonder later, you can look back and see when you did each step. |
| 4 | Onboarding moment | The doubt hits halfway down the street. Open Pebble: you ticked it off two minutes ago, with a photo. No going back to check. | You're halfway down the street when you start to wonder. Open Pebble and you can see you checked them at 08:02, with a photo. |
| 5 | Onboarding moment | The routines you'd normally double-check, and why the camera roll won't cut it. | A few of the checks people tend to go back for. |
| 6 | Reminders | Stay on track. / Set up local, secure nudges to ensure your essential routines never slip your mind. | No reminders yet / Pebble can send a notification at the time you usually do "Leaving the house". |
| 7 | Reminders | Reminder rhythm. / Your local prompts for "X" are ready to keep the habit visible. | Reminders set / Pebble sends these from your phone at the times below. You can pause or change them at any time. |
| 8 | Reminders | Pinpoint timing: Choose the exact hour and minute you want to be prompted. | Pick a time: Any hour and minute you like. (Reminders are inexact on Android, so "exact" was also wrong.) |
| 9 | Home | Small steps, big ripples / YOUR NEXT RIPPLE | One step at a time / UP NEXT |
| 10 | Home empty state | A reliable checklist for the routines you repeat. | Make a checklist for something you check often, like leaving the house. |
| 11 | Paywall headline | Never wonder twice. | Keep three weeks of checks. |
| 12 | Paywall feature | Three weeks of answers, safe if you reinstall or change phone. | Three weeks of history, backed up in case you reinstall or change phone. |
| 13 | Paywall feature | Record a prompt on any step, so future-you hears exactly what to look for. | Record a short note on any step and play it back when you get there. |
| 14 | Backup | One tap and Pebble starts keeping a safe copy of your routines. | Turn it on and Pebble starts backing up your routines. |
| 15 | Composer | Start with a step and keep the list flowing. | Add one step at a time, in the order you do them. |
| 16 | Theme description | A deep, lush forest green surface with a natural feel. | Deep forest green. |
| 17 | Theme description | Warm, gentle, and quietly expressive. | Pale pink with warm accents. |
| 18 | Error view | A momentary pause / Restore Connection | Something went wrong / Try again |
| 19 | Website hero | Pebble walks you through the routines you already have — one step at a time, with proof you locked the door. No streaks to keep. Nothing to keep up. | Pebble walks you through the routines you already have, one step at a time. Add a photo of the locked door if you'd like to see it again later. There are no streaks to keep up. |
| 20 | Website | Your routines. Your business. / Ready when you are. | Your routines stay on your phone / Want to know when it's out? |

## Other changes worth knowing

- **Errors** follow one pattern: what went wrong, then what to do. "Could not
  X. Please try again." became "Couldn't X. Try again." across the player,
  sign-in, backup, reminders and store messages. Raw exception text is no
  longer shown on the history and home error screens.
- **Sentence case** for titles, buttons and template names: "Everyday
  departure check", "Edit routine", "View run", "Continue with email". Template
  categories are now "Leaving and locking up", "Daily care", "Work and away".
  Two template names were shortened: "Essential School Morning Run" is now
  "School morning run", "Toddler Essentials Bag" is "Toddler day bag", and
  "Gym & Sports Prep" is "Gym bag". Template IDs are unchanged, and routines
  people already made from templates keep their names.
- **UK spelling** where US had crept in: colour, personalise, finishing (was
  "Finalizing"), socket (was "outlet").
- **Accuracy fixes found while rewriting:** the photo-limit toast offered a
  "Plus" button (the plan is Personal Premium); the website said steps are
  "read out" (voice tips are recordings, and Premium only); "Stats & history"
  only opened history; "Photo Vault" used the "vault" word the risk scan
  warns against; the reminder saved message lower-cased day names
  ("monday to friday"); the Warm Sepia theme claimed to help with migraines.
- **Notifications** now use the routine name as the title with "Tap to
  start." as the body, instead of "Time for your 'X' routine".
- **Legal pages** (privacy, terms, delete account, in-app summary) only had
  headings and a few sentences plain-Englished. Retention periods, legal
  bases, providers and the Apple 3.1.2 and auto-renew wording are unchanged.

## Left alone, on purpose

- **Machine-matched messages.** `entitlement_flow_messages.dart`,
  `local_data_ownership_guard.dart` and the stored errors in
  `cloud_sync_coordinator.dart` are matched by substring elsewhere. Labels
  compared in code ("Checking backup", "Turning on backup", "Backup off",
  "Sign in") and the server errors matched in `routine_reminders_screen.dart`
  ("Personal Premium is required" and others) are unchanged.
- **The backup consent sentence** in `cloud_backup_consent_provider.dart`. It
  is a recorded consent text; changing it should go with a consent-version
  bump.
- **Subscription legal text** on the paywall (Apple 3.1.2 auto-renew wording)
  and in the App Store description.
- **"Loading store products..." and "Could not load store products..."** in
  `revenuecat_purchase_repository.dart`, because test fakes mirror them.
- **The struck-through "~~habit tracker~~ reliable kind of check." headline.**
  It is technically a "not X, but Y" line, but `DESIGN_DIRECTION.md` calls it
  the best brand work in the app, and it reads as wit, not filler.
- **"When one photo isn't enough." and "Say it once, hear it every time."**
  paywall headlines. Both are clear and specific to the wall the user hit.
- **Email sentences the tests assert on:** "X would like Pebble Routines to
  email you...", "X completed a routine...", and the subjects.
- **"Too many invites today. Please try again tomorrow."** (server text that a
  test asserts verbatim).
- **Some social-video captions** in `LAUNCH_MARKETING_HOOKS.md` keep a casual,
  clipped style ("Check the safe. Every time.") because that is the register
  of the platform. The two fragment headlines used on screenshots were
  rewritten.
- **The optional "peace of mind" line** in the Play listing stays as an
  owner decision, as the listing already says.

## Checks run

- `flutter analyze`: no issues.
- `flutter test`: 390 passed, 120 skipped (the screenshot harness), the same
  as before the pass. Tests that look for text by string were updated to the
  new copy; no assertion was loosened.
- `python3 docs/store/check_limits.py`: all 33 fields within limits.
- Screenshot harness: see "Screenshot check" below.

## Screenshot check

`WALKTHROUGH=1 FLUTTER_TESTER_REAL_FONTS=1 flutter test test/walkthrough/walkthrough_screens_test.dart`
rendered 229 screens.

- `_layout_errors.txt` has no overflows. Its only entries are Flutter's
  "ListTile background color or ink splashes may be invisible" notes on the
  reminder screens, which have nothing to do with copy.
- Onboarding, home, paywall, account, reminders, player (leave prompt) and
  completion were checked by eye, and everything fits. The home tagline was
  first "Routines, one step at a time", which sat right against the header
  buttons on an iPhone, so it became "One step at a time".
- Six harness scenes fail ("home checked" x4 and "player complete photos"
  x2). They tap a button labelled "Add" that no longer exists anywhere in
  `lib/`, including at `origin/main` before this pass, so the failures were
  already there and aren't caused by the copy changes. The harness needs
  updating to the current photo flow.
