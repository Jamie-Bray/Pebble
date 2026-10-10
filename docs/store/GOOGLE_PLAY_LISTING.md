# Google Play Store Listing: Pebble Routines

Last updated: 8 October 2026

Ready-to-paste copy for Play Console > Grow > Store presence > Main store
listing, plus the policy questionnaires. Every limited field is in a fenced
block with a `limit` marker. Run `python3 docs/store/check_limits.py` after
any edit. The latest counts are in the table at the end.

Positioning (decided by Jamie, 8 October 2026): Pebble is a routine
checklist app you reuse every day. Every check is saved with the time, and you
can add a photo to any step. Photos are optional. The listing leads with those
three things (routines you reuse, a photo when it helps, history to look back
on) and fits the search phrases around them, rather than letting one phrase
set the brand. The full plan, keyword research and reasoning are in the
"Pebble launch marketing plan" doc in the project.

Copy rules applied (from `COPY_GUIDELINES.md` and `COPY_RISK_SCAN.md`):

- Plain, direct, UK spelling. No "worry less", "peace of mind" promises,
  "never worry again", "stay safe", "evidence", "guaranteed backup".
- No medical claims. "OCD" and "anxiety" are deliberately left out of the
  listing. Using them would present Pebble as a health product, invite Play
  health-claim review, and risk reading as a promise to people who are
  struggling. The audience still finds Pebble through the words they actually
  type: "routine checklist", "did I lock the door", "leaving the house
  checklist", "hair straighteners", "stove off".
- Backup always comes with "if you have Premium, sign in, and turn it on".
- "Photo" in daily copy. "Proof photos" only as a feature name.
- AI photo descriptions are not mentioned anywhere in the listing or the
  screenshots. They are expected to be off at launch.

Search terms used: routine checklist, routine, checklist, reusable checklist,
daily routine, photo, did I lock the door, leaving the house, leaving home,
hair straighteners, straighteners, curling iron, stove, oven, unplug, front
door, locked, reminder, bedtime check, hotel checkout, car lock, trip.

Google Play has no keyword field. The title counts most, then the short
description, then the full description. Repeating a word many times does not
help and can break Play's metadata policy, so each search phrase appears once
or twice in natural sentences.

About "peace of mind": the brief lists it as a search term, but
`COPY_GUIDELINES.md` lists "Unlock peace of mind" as copy to avoid. It is left
out of the copy below. If you want it indexed, the only wording I would use is
the neutral optional line at the end of the full description section. It
describes what people say, not what Pebble promises.

---

## App name (max 30)

Chosen (Jamie, 8 October 2026):

<!-- limit:30 id:play-name -->
```text
Pebble: Routine Checklist
```

Alternatives considered. Google Play allows descriptive phrases in titles. It
does not allow "free", "best", "#1", emoji or all caps.

<!-- limit:30 id:play-name-alt-1 -->
```text
Pebble: Photo Checklist
```

<!-- limit:30 id:play-name-alt-2 -->
```text
Pebble: Leaving Home Checklist
```

"Pebble: Did I Lock The Door?" was dropped: it chases one search phrase and
describes only one of Pebble's routines.

Note: the launcher label in `AndroidManifest.xml` is "Pebble Routines". A Play
title that is different from the launcher label is allowed.

## Short description (max 80)

Chosen (Jamie, 8 October 2026):

<!-- limit:80 id:play-short -->
```text
Reusable routine checklists. Add a photo and see when each check was done.
```

Alternatives:

<!-- limit:80 id:play-short-alt-1 -->
```text
Routine checklists you reuse, with the time saved and a photo if you want one.
```

<!-- limit:80 id:play-short-alt-2 -->
```text
Step-by-step routines for leaving home, bedtime and more. Add a photo to a step.
```

## Full description (max 4000)

<!-- limit:4000 id:play-full -->
```text
Pebble is a routine checklist app. Set up a routine once, tick each step as you go and see exactly when each check was done. Add a photo to any step if it helps.

Did I lock the door? Is the hair straightener unplugged? Is the oven off? Open your routine and go through it one step at a time. Pebble saves the time of every check, so the answer is there later.

Use it for leaving the house, your morning routine, a bedtime routine, the school run, a trip away or locking up at work.

ROUTINES YOU REUSE
• Make a checklist in a minute or start from a ready-made routine.
• Or describe a routine in your own words and Pebble's AI drafts the steps. You check and edit them.
• Each step gets its own screen, so you always know what's next.
• Skip a step when it doesn't apply today.

A PHOTO WHEN IT HELPS
• Add a photo to any step. The straighteners on their mat. The oven dials. The back door.
• Take one there and then or pick one from your gallery.
• Photos are optional. Plenty of routines work fine without them.

SEE WHEN YOU CHECKED
• Every run is saved with the date and time of each step.
• Look back through recent runs with their photos.
• Run a routine again with one tap from Home.

READY-MADE ROUTINES TO EDIT
• Leaving the house: hair tools, oven, toaster, taps, heaters, windows and doors
• Bedtime house check
• Car lock check
• Hotel checkout sweep
• Big trip home shutdown
• School morning, gym bag, pet care, office lock-up and more

MAKE IT YOURS
• Themes and colours with a calm dark mode and accessibility themes
• Reminders at the time you usually start
• A home screen widget that starts a routine in one tap
• Voice prompts recorded in your own voice (Premium)
• Save any Pebble photo to your gallery

PRIVATE BY DEFAULT
• No account needed to start.
• Your routines, history and photos stay on your phone.
• No ads. Pebble never sells your data.
• Pebble keeps 21 days of photos and history, then deletes its own copies. It never deletes anything from your camera roll.
• Cloud backup stays off unless you have Premium, sign in and choose to turn it on.

EVERYONE GETS
• 2 routines with up to 10 steps each
• 1 photo per step
• The last 48 hours of history
• Reminders, ready-made routines and the widget

PERSONAL PREMIUM (MONTHLY OR YEARLY)
• Unlimited routines and steps
• Up to 4 photos per step
• The full 21 days of history
• Voice prompts and extra themes
• Optional cloud backup and account recovery (needs sign-in and your consent)
• Completion emails. Pebble can email one person when a routine is done. They accept first and can stop the emails at any time. Each email lists the steps, when they were checked and any notes you added. Photos are never emailed.

Premium renews until you cancel in Google Play. Pebble keeps working without it.

WHAT PEBBLE IS AND ISN'T
Pebble is a routine and checklist app. It is not a medical treatment, a home security system or an emergency service. Photos in Pebble are not legal evidence. If checking is taking over your day, a doctor or other qualified professional can help.

Privacy policy: https://pebbleroutines.com/privacy
Support: support@pebbleroutines.com
```

Optional neutral line, only if you decide you want "peace of mind" indexed. Put
it after the paragraph that starts "Did I lock the door?":

```text
Some people call it peace of mind. Pebble calls it a checklist with the time on it.
```

Check the length again after adding it.

## Category and tags

- **App category:** Productivity
- **Secondary option if you want to test it later:** Lifestyle. Productivity
  is the closer match for "checklist" and "routine" searches, and the
  competitors there are general to-do apps rather than health apps.
- **Tags (Play Console > Store settings > Manage tags, up to 5):** pick the
  closest available entries from Google's list. Suggested order:
  1. To-do list / Checklist
  2. Reminders
  3. Planner
  4. Habit tracker (only if no closer "routine" tag is offered)
  5. Personal organiser / Productivity tools

  Do not pick health, wellness, or mental health tags.
- **Contact details:** email `support@pebbleroutines.com` (confirm the domain;
  see `OWNER_NOTES.md`), website `https://pebbleroutines.com`, privacy policy
  `https://pebbleroutines.com/privacy`.

## Content rating questionnaire (IARC)

Play Console > Policy > App content > Content ratings.

| Question | Answer | Why |
| --- | --- | --- |
| Email for the rating certificate | Your support or privacy inbox | |
| Category | All Other App Types (Utility, Productivity, Communication, or Other) | Not a game, not a social or news app |
| Violence | No | |
| Fear or horror | No | |
| Sexuality, nudity | No | |
| Language (profanity, crude humour) | No | |
| Controlled substances (drugs, alcohol, tobacco) | No | The "Medication check" template is an ordinary routine. It does not show or promote drugs |
| Gambling, simulated gambling | No | |
| Does the app let users interact or exchange content with other users? | **Yes** | Conservative answer. Completion emails send text the user typed (the routine name) to one email contact who has accepted. It is one-way, opt-in, and has stop and block links. There is no chat, profile, public feed, or in-app messaging. If you want to answer No, the argument is that this is a system notification, not user-to-user messaging. Yes only adds a "Users Interact" note and does not change the age rating. |
| Does the app share the user's current location with other users? | No | No location permission |
| Does the app allow users to buy digital goods? | Yes | Personal Premium subscription |
| Does the app contain unrestricted internet access (browser)? | No | Links open the system browser only for legal pages and store subscription settings |
| Is the app a news or educational product? | No | |

Expected result: PEGI 3 / ESRB Everyone / USK 0, with "In-App Purchases" (and
"Users Interact" if you answer Yes above).

## Target audience and content

Play Console > Policy > App content > Target audience and content.

| Question | Answer |
| --- | --- |
| Target age groups | **18 and over** only |
| Could the app unintentionally appeal to children? | No. No cartoon characters, games, or child-directed content. The store listing and screenshots are adult and practical. |
| Store listing shown to children? | Not applicable |

Why 18+ only: choosing any group under 13 brings in the Families policy, and
choosing 13 to 17 adds extra checks on content and ads. The school-run and
toddler-bag templates are for parents, not for children. Teenagers can still
install the app; this answer only sets who it is designed for. The privacy
policy states Pebble is not directed at children under 13.

## Other App content declarations

| Declaration | Answer | Notes |
| --- | --- | --- |
| Privacy policy | `https://pebbleroutines.com/privacy` | Publish the updated `web/privacy.html` first |
| Ads | No, my app does not contain ads | No ad SDK in `pubspec.yaml` |
| App access | All functionality is available without special access | Sign-in is optional. If Play reviewers ask, they can use the email one-time code with any address, or Google sign-in. No demo account is needed. |
| Data safety | See `DATA_SAFETY_ANSWERS.md` | |
| Account deletion URL | `https://pebbleroutines.com/delete-account` | In-app path: Your account > Delete Account |
| Government app | No | |
| Financial features | My app does not provide any financial features | Subscriptions are not a financial feature for this form |
| Health apps | My app does not have any health features | Pebble is a general checklist. It does not use Health Connect, sensors, or health records. The "Medication check" template is a plain checklist. If Play ever asks again, the honest answer is still "no health features"; do not add a medication-management claim to the listing. |
| News app | No | |
| COVID-19 contact tracing or status | No | |
| Photo and video permissions | No declaration needed | The app does not request `READ_MEDIA_IMAGES` or `READ_MEDIA_VIDEO`. Choosing a photo uses the system picker. |
| Foreground service, exact alarm, full-screen intent | Not used | `SCHEDULE_EXACT_ALARM` was removed; reminders are inexact |

## Screenshot captions (7)

Phone screenshots, portrait, 1080 x 1920, v3 set (approved 8 October 2026):
forest green background (#2C4434, the icon colour) with sage ripples, a
two-line cream serif headline with no highlighted word, a one-line subline and
the real app screen in a phone frame. Files and `make.py`:
`/mnt/project-files/marketing/screenshots-v3/` in the project.

Keep captions to one short line. Avoid "safe", "proof you", "never forget",
"free" or prices. Do not show AI photo descriptions.

<!-- limit:40 id:play-shot-1 -->
```text
Routines you reuse
```
Subline: "Set it up once. Run it every day." Screen: Home with the last check and the Earlier rows.

<!-- limit:40 id:play-shot-2 -->
```text
One check at a time
```
Subline: "Each step is saved as you go." Screen: routine player mid-run, ticked steps and their times enlarged.

<!-- limit:40 id:play-shot-3 -->
```text
See when you checked
```
Subline: "Every routine, with the time it was done." Screen: History with several runs across the day.

<!-- limit:40 id:play-shot-4 -->
```text
A photo when it helps
```
Subline: "Add one to any step you like." Screen: a photo step (sample photo of straighteners on a heat mat).

<!-- limit:40 id:play-shot-5 -->
```text
All done. All saved.
```
Subline: "Small steps, big ripples." Screen: the completion screen with the cairn and the time.

<!-- limit:40 id:play-shot-6 -->
```text
Make it yours
```
Subline: "Themes, colours and a calm dark mode." Screen: Home in different themes.

<!-- limit:40 id:play-shot-7 -->
```text
No sign-up. No ads.
```
Subline: "Open Pebble and start your first routine." Screen: Home ready for a first routine.

Later, if there is enough store traffic for a store listing experiment, test a
reminder or widget screenshot in place of number 5.

Use sample data only: no real addresses, faces, house numbers, or car plates
in screenshot photos.

## Feature graphic concept (1024 x 500)

- **Background:** the same cream as the screenshots, with the clay ripples.
- **Left half:** the cairn icon and "Pebble" in the serif, with one line
  below: "Routine checklists you reuse".
- **Right half:** a cropped phone showing Home with the last check and its
  time.
- **No** price, ratings, "free", award badges, or small text. Google crops
  and overlays the graphic, so keep important content away from the edges.
- **Accessibility:** keep the ink-on-cream contrast. Do not put text over
  photos.

## Character count results

Output of `python3 docs/store/check_limits.py` on 8 October 2026:

| Field | Chars | Max |
| --- | --- | --- |
| App name (chosen) | 25 | 30 |
| App name alt 1 / alt 2 | 23 / 30 | 30 |
| Short description (chosen) | 74 | 80 |
| Short description alt 1 / alt 2 | 78 / 80 | 80 |
| Full description | 3294 | 4000 |
| Screenshot captions 1 to 6 | 11 to 21 | 40 (house style, not a Play limit) |
