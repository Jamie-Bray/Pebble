# Google Play Store Listing: Pebble Routines

Last updated: 3 October 2026

Ready-to-paste copy for Play Console > Grow > Store presence > Main store
listing, plus the policy questionnaires. Every limited field is in a fenced
block with a `limit` marker. Run `python3 docs/store/check_limits.py` after
any edit. The latest counts are in the table at the end.

Copy rules applied (from `COPY_GUIDELINES.md` and `COPY_RISK_SCAN.md`):

- Plain, direct, UK spelling. No "worry less", "peace of mind" promises,
  "never worry again", "stay safe", "evidence", "guaranteed backup".
- No medical claims. "OCD" and "anxiety" are deliberately left out of the
  listing. Using them would present Pebble as a health product, invite Play
  health-claim review, and risk reading as a promise to people who are
  struggling. The audience still finds Pebble through the words they actually
  type: "did I lock the door", "leaving the house checklist", "hair
  straighteners", "stove off".
- Backup always comes with "if you have Premium, sign in, and turn it on".
- "Photo" in daily copy. "Proof photos" only as a feature name.

Search terms used: did I lock the door, checklist, leaving the house, leaving
home, hair straighteners, straighteners, curling iron, stove, oven, unplug,
front door, locked, routine, reminder, photo, bedtime check, hotel checkout,
car lock, trip.

About "peace of mind": the brief lists it as a search term, but
`COPY_GUIDELINES.md` lists "Unlock peace of mind" as copy to avoid. It is left
out of the copy below. If you want it indexed, the only wording I would use is
the neutral optional line at the end of the full description section. It
describes what people say, not what Pebble promises.

---

## App name (max 30)

Recommended:

<!-- limit:30 id:play-name -->
```text
Pebble Routines: Checklist
```

Alternatives, if you would rather put the top search phrase in the title.
Google Play allows descriptive phrases in titles. It does not allow "free",
"best", "#1", emoji or all caps.

<!-- limit:30 id:play-name-alt-1 -->
```text
Pebble: Leaving Home Checklist
```

<!-- limit:30 id:play-name-alt-2 -->
```text
Pebble: Did I Lock The Door?
```

Note: the launcher label in `AndroidManifest.xml` is "Pebble Routines". A Play
title that is different from the launcher label is allowed.

## Short description (max 80)

Recommended:

<!-- limit:80 id:play-short -->
```text
Did I lock the door? Run your leaving-home checks step by step and add a photo.
```

Alternatives:

<!-- limit:80 id:play-short-alt-1 -->
```text
A step-by-step checklist for the door, the stove and the hair straighteners.
```

<!-- limit:80 id:play-short-alt-2 -->
```text
Check the door, stove and straighteners, with a photo and the time saved.
```

## Full description (max 4000)

<!-- limit:4000 id:play-full -->
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
• Home-screen widget: start a routine with one tap
• Voice prompts: record a short note in your own voice for any step (Premium)
• Save a copy to Photos: keep a photo from Pebble in your own gallery
• Themes, including accessibility themes

PRIVATE BY DEFAULT
• Works without an account. No sign-up needed to start.
• Your routines, history and photos are stored on this device.
• No ads. Pebble does not sell your data.
• On the free plan, photos and history are kept for 48 hours, then Pebble deletes its own copies. Pebble never deletes anything from your camera roll.
• Cloud backup only starts if you have Premium, sign in, and choose to turn it on.

FREE
• 2 routines, up to 10 steps each
• 1 photo per step
• 48 hours of recent history
• Reminders, ready-made routines and the home-screen widget

PERSONAL PREMIUM (MONTHLY OR YEARLY)
• Unlimited routines and steps
• Up to 4 photos per step
• 21 days of recent history
• Voice prompts on any step
• Extra themes
• Optional cloud backup and account recovery (needs sign-in and your consent)
• Completion emails: Pebble can email one contact when a routine is done. They accept first, and can stop the emails at any time. Photos and checklist details are not included.

Premium renews automatically until you cancel in Google Play. Pebble keeps working on the free plan without it.

WHAT PEBBLE IS, AND IS NOT
Pebble is a routine and checklist app. It is not a medical app or treatment, a home security system, or an emergency service, and photos in Pebble are not legal evidence. If checking is taking up a lot of your day, a doctor or other qualified professional can help.

Privacy policy: https://pebbleroutines.com/privacy
Support: support@pebbleroutines.app
```

Optional neutral line, only if you decide you want "peace of mind" indexed. Put
it after the paragraph that starts "Pebble is for anyone who...":

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
- **Contact details:** email `support@pebbleroutines.app` (confirm the domain;
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
| Controlled substances (drugs, alcohol, tobacco) | No | The "Medication Check" template is an ordinary routine. It does not show or promote drugs |
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
| Health apps | My app does not have any health features | Pebble is a general checklist. It does not use Health Connect, sensors, or health records. The "Medication Check" template is a plain checklist. If Play ever asks again, the honest answer is still "no health features"; do not add a medication-management claim to the listing. |
| News app | No | |
| COVID-19 contact tracing or status | No | |
| Photo and video permissions | No declaration needed | The app does not request `READ_MEDIA_IMAGES` or `READ_MEDIA_VIDEO`. Choosing a photo uses the system picker. |
| Foreground service, exact alarm, full-screen intent | Not used | `SCHEDULE_EXACT_ALARM` was removed; reminders are inexact |

## Screenshot captions (8)

Phone screenshots, portrait, 1080 x 1920 or larger. Put the caption at the top
in large type, with the real app screen below. Keep captions to one short
line. Avoid "safe", "proof you", "never forget".

<!-- limit:40 id:play-shot-1 -->
```text
Did I lock the door? Check it here.
```
Screen: routine list with "Everyday Departure Check" at the top.

<!-- limit:40 id:play-shot-2 -->
```text
Your leaving-home checks, step by step
```
Screen: routine player on "Front door locked", progress bar visible.

<!-- limit:40 id:play-shot-3 -->
```text
Straighteners off? Take a photo.
```
Screen: photo step with a photo of unplugged straighteners on a heat mat.

<!-- limit:40 id:play-shot-4 -->
```text
See what you checked, and when
```
Screen: history list showing completion times for today.

<!-- limit:40 id:play-shot-5 -->
```text
Start from a ready-made routine
```
Screen: template picker (departure, bedtime, car, hotel, trip).

<!-- limit:40 id:play-shot-6 -->
```text
A reminder at the time you leave
```
Screen: reminders screen with a weekday 08:00 reminder.

<!-- limit:40 id:play-shot-7 -->
```text
Start a routine from your home screen
```
Screen: Android home screen with the Pebble widget.

<!-- limit:40 id:play-shot-8 -->
```text
No account needed. No ads.
```
Screen: privacy section or paywall footer: "Pebble has no ads, does not sell
your data, and backup only starts when you choose to turn it on."

Use sample data only: no real addresses, faces, house numbers, or car plates
in screenshot photos.

## Feature graphic concept (1024 x 500)

- **Background:** Pebble forest green `#2C4434` (the adaptive icon
  background), with a soft lighter band behind the phone.
- **Left half:** the cairn icon and "Pebble Routines" in the site serif, with
  one line below: "Leaving-home checks, step by step".
- **Right half:** a cropped phone showing three check cards, matching the
  website hero: "Straighteners unplugged, 08:02" with a small photo
  thumbnail, "Stove off, 08:02", "Front door locked" as the active step.
- **No** price, ratings, "free", award badges, or small text. Google crops
  and overlays the graphic, so keep important content away from the edges.
- **Accessibility:** white text on the green passes contrast. Do not put
  text over the photo thumbnail.

## Character count results

Output of `python3 docs/store/check_limits.py` on 3 October 2026:

| Field | Chars | Max |
| --- | --- | --- |
| App name (recommended) | 26 | 30 |
| App name alt 1 / alt 2 | 30 / 28 | 30 |
| Short description (recommended) | 79 | 80 |
| Short description alt 1 / alt 2 | 76 / 73 | 80 |
| Full description | 2978 | 4000 |
| Screenshot captions 1 to 8 | 26 to 38 | 40 (house style, not a Play limit) |
