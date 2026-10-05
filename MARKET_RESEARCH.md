# Pebble Routines: Market, Competitor and Pricing Report

Last updated: 4 October 2026 (version 2: competitor data now taken directly
from the App Store and Google Play)
For: the owner. Written in plain English. No code changes come with this report.

## How to read this report

- **Fact** means something found in a public source. Each one has a link.
- **Our view** means judgement: a recommendation, an estimate or a guess. These
  are labelled so you can disagree with them.
- **Dates.** Every price, rating, download count and review was checked on **4
  October 2026**. Store prices change often and differ by country. UK prices are
  given first.
- **How the store data was gathered.** iPhone apps: Apple's public search and
  lookup service (exact ratings and rating counts for the UK and US stores),
  each app's App Store page (in-app purchase prices) and Apple's public reviews
  feed (recent reviews). Android apps: Google Play's UK search results and each
  app's store page (downloads, last update, ads and in-app purchases). Google
  Play doesn't show in-app prices without signing in, so Android prices are
  missing where the app has no iPhone version.

---

## 1. Summary

**The market.** Photographing the straighteners or the hob "just in case" is a
widespread habit. Developers have noticed: the App Store now has **33
dedicated "did I lock it?" checking apps, 28 of them launched in 2025 or 2026**
(21 this year alone). Between them they have **16 ratings in total**, and only 2
have any rating at all in the UK store. On Google Play the biggest dedicated
checking app has **1,000+ downloads** and most have under 100. **Nobody owns
this category yet**, and four apps found by an earlier web search have already
disappeared from the App Store.

**Three kinds of rival.**

1. **"Reassurance-first" apps** promise certainty ("Know for sure",
   "undeniable proof", "You are good"). Some send a reassurance message after
   each check, or push your morning photos to you at 2 pm.
2. **"Check-less" apps** are built around therapy ideas, with a pause before
   viewing, urge tracking and "move on or look" choices.
3. **"Neutral record" apps**, the closest to Pebble, just show what you checked
   and when. The two strongest, **Is It Locked?** and **Before You Go**, both
   launched in the last three months, are iPhone-only, and use language very
   like Pebble's.

**Pebble's edge.** Pebble is the only checking app found that offers
**Android and iPhone, backup and account recovery, completion emails, voice
prompts in your own voice, up to 4 photos per step, and a full template
library** together. Most rivals have one or two of these. **None of the 45 or so
checking apps describes its photos with AI.**

**Pebble's gaps.** Rivals already offer things Pebble doesn't: an iPhone
widget, Apple Watch, a reminder when you leave home (geofence), sharing a list
with the people you live with, a "camera only" option, app lock, a choice of
how long photos are kept, and one-off "lifetime" prices.

**Price.** £0.89 a month and £6.49 a year is too low. After VAT and the store
fee you would keep about **£0.63 a month or £4.60 a year** per person. At those
prices you would keep roughly **£11,600 a year** from 2,000 subscribers, before
running costs and tax. That is not a living. Rivals' UK prices cluster at
**£1.99–£5.99 a month and £14.99–£29.99 a year**. Our view: launch at **£2.99 a
month / £19.99 a year** in the UK and **$2.99 / $19.99** in the US, with a
7-day free trial on the yearly plan only, and test £3.99 / £24.99 later. At
£2.99 / £19.99, 2,000 subscribers come to roughly **£34,000 a year** after all
costs and before tax.

**Owner's decision (4 October 2026): £1.99 a month.** Jamie's reasoning: £1.99
is a price people do not stop to think about, and more subscribers at a lower
price is the easier target. It matches the most common monthly price among
direct rivals. After VAT and the store fee Pebble keeps about **£1.41 a month**
per monthly subscriber. The yearly price is not yet decided; rivals who charge
£1.99 a month mostly charge £14.99 a year, which would keep about **£10.60 a
year**. So 2,000 subscribers come to roughly **£21,000 a year if all pay
yearly and £34,000 if all pay monthly**, before running costs and tax. The
prices are set in Play Console and App Store Connect, not in the app; the
current store prices (£0.89 / £6.49) still need changing there. Raising a price
later is harder than lowering one, so this is worth one more look before the
store listing goes live.

**AI photo steps: agreed shape.** Personal Premium only, one routine with up
to five AI photo steps, one plain opt-in question. See
`docs/research/AI_PHOTO_STEPS_PROPOSAL.md` on the `research/ai-photo-description`
branch.

**AI photo labels ("Jev").** Our view: **build it, carefully, after launch.**
It is cheap to run (about **$0.0018 per photo** with Claude Haiku 4.5) and no
rival does it. But for people who check, an AI that answers "is it off?" on
demand can quickly become a new thing to check. One rival's only UK review
says the user "ended up checking it often". The design below allows **one
factual note per photo, written once, saved with the photo and never
re-asked.** Call the feature **"Photo note"**, not a character name. Make it
Premium-only and opt-in, and run a two-week accuracy test before writing any
app code.

The SWOT summary is in section 4.3. The top 5 actions are at the end (section
9).

---

## 2. The market

### 2.1 Who has this problem (facts)

| Fact | Source |
|---|---|
| OCD affects about 1.2% of people in the UK, an estimated 750,000 people. | [OCD-UK](https://www.ocduk.org/?p=2376) |
| r/OCD has about 260,000 members; r/ADHD about 2.3 million. | [GummySearch r/OCD](https://gummysearch.com/r/OCD), [GummySearch r/ADHD](https://gummysearch.com/r/ADHD) |
| The "photo of the unplugged straighteners" habit has been covered as a lifehack in UK local press. | [Get Surrey](https://www.getsurrey.co.uk/news/uk-world-news/womans-genius-hack-stop-you-17746606), [Lancashire Evening Post](https://www.lep.co.uk/news/opinion/columnists/have-i-turned-my-straighteners-off-modernproblems-1084051) |
| UK fire services run regular warnings about hair straighteners left on. | [London Fire Brigade](https://www.london-fire.gov.uk/incidents/2016/june/firefighters-issue-warning-following-hair-raising-fire), [Offaly Express](https://www.offalyexpress.ie/news/photos-firefighters-in-stark-warning-over-hair-straighteners-8039335) |
| A straightener "how people think they behave when left on" TikTok has about 1.8 million likes. | [TikTok @shaneblud](https://www.tiktok.com/@shaneblud/video/7620850048234016022) |
| Your own signal: "100 photos of my straighteners" videos get 100k to 200k likes. | Owner brief |
| A student study notes the "picture strategy" is already widely used for checking, but that there was **no published research** on whether it helps. | [MacEwan University student research](https://journals.macewan.ca/studentresearch/article/view/2684) |

**Our view.** There are three overlapping groups:

1. **Everyday doubters** (the biggest group). Busy, distracted, ADHD-ish, or just
   people who once left the hob on. They want a quick list and a timestamp.
   They find Pebble through "did I lock the door", "leaving the house
   checklist" and "straighteners".
2. **Heavy checkers**, some of whom live with OCD. They are the most engaged
   and the most likely to pay, and they are also the group a careless feature
   could harm. They should never be the target of marketing (see the copy
   rules), but the product has to be safe for them.
3. **Trip and travel planners** (hotel checkout, big trip shutdown). A lighter
   tone and an easy way to widen the audience.

### 2.2 What research says about checking (facts)

These findings matter for the AI feature and for Pebble's design generally.

- **Repeated checking makes memory less trustworthy, not more.** In lab
  studies, people who checked a virtual gas stove again and again ended up
  *less* sure of their memory, with less vivid and less detailed recollections.
  A meta-analysis of 28 experiments (1,662 participants) found large effects.
  ([Utrecht University: "Repeated checking causes memory distrust"](https://research-portal.uu.nl/en/publications/repeated-checking-causes-memory-distrust/),
  [meta-analysis](https://utrecht-main-test.atmire.com/items/9902ebe4-19a8-4ae1-a5f2-25aab70c8c32),
  [SAGE journal article](https://journals.sagepub.com/doi/10.5127/jep.040113))
- **AI chatbots are becoming a new reassurance source.** A 2026 CHI paper
  looked at 100 Reddit posts about OCD and generative AI. 31 described
  AI-based compulsions: reassurance-seeking, confession and decision-making.
  People often used AI so they wouldn't burden family. The authors call this
  pattern a "Reassurance Robot". Because going along with compulsions is known
  to make OCD worse over time, they treat it as a design harm.
  ([arXiv: Reassurance Robots, Barkhuff 2026](https://arxiv.org/html/2602.19401v1))
- Clinicians report the same thing: one patient spent upwards of ten hours a
  day seeking reassurance from chatbots.
  ([summary of the paper and clinical reports](https://a11y-paradise.onrender.com/reviews/69eb5ed285b5adefe46290d9),
  [Forest & Trees Psychology](https://www.ftpsych.ca/?p=19901))

**Our view.** Pebble's current design principle, "show the record, not the
reassurance" (`DESIGN_DIRECTION.md`), fits this research well. A check done
once, with the time on it, is a record. A button you can press again and again
for an answer is a loop. Section 6 applies this to the AI idea.

### 2.3 Shape of the competition

**Facts** (App Store and Google Play, 4 October 2026):

- **33 dedicated checking apps on the App Store.** 28 launched in 2025 or 2026,
  21 of them in 2026. Together they have 16 ratings. The most-rated, "Did I
  lock?", has 5, and it hasn't been updated since 2020.
- **About 12 on Google Play UK.** The largest, CheckAlarm, has 1,000+
  downloads. Paximus has 500+. Everything else has 100+ or fewer. None has
  enough ratings for Google Play to show a score.
- **High churn.** Four apps an earlier web search found (OCD Rescuer, Checked
  OCD Companion, "Did I lock it?" with its "GPT Subscription", and Home Key
  Reminder) no longer appear in the App Store in the UK, US, Canada, Australia,
  India, Germany, Japan or Turkey. One Android "Secure Check – Did I lock it?"
  listing has been turned into an unrelated photo app.
- **The real incumbent is the phone camera**, and the free timestamp-camera
  apps. On Google Play, Timemark: Photo Proof has 4.8 stars from about 942,000
  reviews.

**Our view.**

- The category is **crowded with very small apps but has no winner.** Most are
  side projects launched quickly, probably with AI coding tools, and many will
  be abandoned. A polished, maintained app with a few hundred genuine reviews
  could own "did I lock the door" searches on both stores.
- **Android is wide open.** Pebble launches there first.
- **The closest rivals in spirit are new and iPhone-only.** Is It Locked?
  (launched September 2026) and Before You Go (July 2026) use plain,
  record-not-reassurance wording very like Pebble's. Expect them to grow, and
  expect more like them.
- Pebble has to beat "just take a photo". The pitch is: one photo, saved with
  the time, in a list that shows what you already checked, kept out of your
  camera roll.

---

## 3. Competitors

All checked on 4 October 2026. **Angle** is our label for how each app talks
to its users (section 1). "none" means the store shows no ratings at all.

### 3.1 Checking apps on the App Store (33)

Prices are UK prices from each app's App Store page. "Free; …" means free to
download, with the in-app purchases listed. Dates are launch / last update.

| App | Angle | Launched / updated | UK price | Ratings (UK; US) | Headline features |
|---|---|---|---|---|---|
| [Before You Go: Leave Checklist](https://apps.apple.com/gb/app/before-you-go-leave-checklist/id6785884637) | Neutral record | 2026-07 / 2026-09 | Free; Before You Go Premium £3.99 | GB none; US none | 18 templates incl. hotel/Airbnb checkout with reminders the evening before; every item time-stamped; widget shows "Checked · Today, 8:14 · 8/8"; paste a list from Notes. No photos. |
| [Is It Locked? Door Checklist](https://apps.apple.com/gb/app/is-it-locked-door-checklist/id6813531030) | Neutral record | 2026-09 / 2026-09 | Free; Is It Locked? Plus Monthly £1.99, Is It Locked? Plus Annual £14.99 | GB none; US none | Hold one button to check the whole list; list stays checked for 8 h (1 h–3 days); widget; Plus adds Apple Watch, reminders when you leave a place, several places, **sharing with people you live with**, PDF export. |
| [DoorCheck - Photo Proof](https://apps.apple.com/gb/app/doorcheck-photo-proof/id6767494303) | Neutral record | 2026-05 / 2026-08 | £0.99 | GB none; US none | Offline templates; **live camera only**; photo, time, status and note per item; skipped items shown; history search. |
| [Batten: Did I Lock It?](https://apps.apple.com/gb/app/batten-did-i-lock-it/id6779814508) | Neutral record (ritual) | 2026-08 / 2026-08 | Free; Premium Yearly £14.99, Premium Monthly £1.99 | GB none; US none | "Manifests" and "Rounds"; hold to confirm each card; photo proof; geofence departure reminders; several homes; 7-day trial. |
| [DoneKit: Locked It?](https://apps.apple.com/gb/app/donekit-locked-it/id6756815675) | Neutral record | 2026-01 / 2026-08 | Free; Monthly £1.99, Yearly £9.99 | GB none; US 5.0 (1) | Spaces and switches; "point and call" (say it aloud); photo proof kept out of the camera roll. |
| [Did I Lock It? Lock'd](https://apps.apple.com/gb/app/did-i-lock-it-lockd/id6757942105) | Neutral record | 2026-01 / 2026-10 | Free; Lock'd Premium Lifetime £24.99, Annual Plan £19.99, Monthly Plan £1.99 | GB none; US none | Time-stamped before-you-leave list; lists for meds, packing, chores. |
| [Did I Lock Up? - Checklist](https://apps.apple.com/gb/app/did-i-lock-up-checklist/id6755089038) | Neutral record | 2025-11 / 2025-11 | Free | GB none; US 2.0 (1) | One-tap lock log with relative times; notes. |
| [Did I lock?](https://apps.apple.com/gb/app/did-i-lock/id1282374259) | Neutral record | 2017-09 / 2020-12 | Free | GB 5.0 (3); US 5.0 (5) | Tap after locking; history. Not updated since 2020. |
| [OCD Check & Photo Proof: yepp](https://apps.apple.com/gb/app/ocd-check-photo-proof-yepp/id6744017205) | Check-less (OCD-aware) | 2025-03 / 2026-10 | Free; Yepp+ Weekly £4.99, Yepp+ Yearly £79.99, Yepp+ Monthly £9.99 | GB none; US none | Photo proof, "self-trust" log without a photo, note an intrusive thought without acting, anxiety rating, auto-delete, Face ID. |
| [Pruvd: Did I Lock the Door?](https://apps.apple.com/gb/app/pruvd-did-i-lock-the-door/id6757632735) | Check-less (OCD-aware) | 2026-02 / 2026-07 | Free; Pruvd Pro - Monthly £4.99, Pruvd Pro - Annual £24.99 | GB none; US none | Photo, video, voice or tap as evidence; **One-Check Coach** suggests a pause before viewing evidence again; Siri; widgets. |
| [OneCheck: Check Less](https://apps.apple.com/gb/app/onecheck-check-less/id6788103404) | Check-less (ERP-style) | 2026-07 / 2026-08 | Free; OneCheck+ Monthly £2.99 | GB none; US none | Record once; when the urge comes, a **breathing delay before viewing**; one confirmation per recording; urge log; CSV export for a therapist. |
| [MakeSure: Did I Lock the Door?](https://apps.apple.com/gb/app/makesure-did-i-lock-the-door/id6756681295) | Check-less (ERP-style) | 2026-01 / 2026-09 | Free; Monthly MakeSure Premium £5.99, Annual MakeSure Premium £29.99 | GB none; US none | Run the routine once; rate the urge; choose "move on" or "look"; tracks how often you moved on. |
| [Paximus: OCD Companion](https://apps.apple.com/gb/app/paximus-ocd-companion/id6745874911) | Proof / reassurance | 2025-07 / 2026-07 | Free; Paximus Annual Special Offer £24.99, Paximus Premium Annual £39.99, Paximus Premium Monthly £7.99, Paximus Annual Package £24.99, Paximus Monthly Package £4.99 | GB none; US none | Photo, voice, written confirmation or checklist as proof; time-stamped records. Also on Android (500+ downloads). |
| [Certain: OCD ADHD Reassurance](https://apps.apple.com/gb/app/certain-ocd-adhd-reassurance/id6757313797) | Reassurance-first | 2026-01 / 2026-01 | Free; Certain Plus £6.99, Certain Plus £0.99 | GB 5.0 (2); US none | Records checks by room; optional "photo evidence for reassurance". |
| [Check: Stop Anxiety Checking](https://apps.apple.com/gb/app/check-stop-anxiety-checking/id6757536012) | Reassurance-first | 2026-01 / 2026-01 | Free; Weekly £1.99, Yearly £22.99, Monthly £3.99 | GB none; US 5.0 (1) | One-tap check, then a **"personalized reassurance message"**. |
| [Did I Lock It? - Checklist](https://apps.apple.com/gb/app/did-i-lock-it-checklist/id6761918539) | Reassurance-first | 2026-04 / 2026-04 | £1.99 | GB none; US none | One-tap log, photo, **"tiered reassurance messages"** and an "Overthink Mode". |
| [Capy Clear: Leaving Home Check](https://apps.apple.com/gb/app/capy-clear-leaving-home-check/id6782067107) | Reassurance-first | 2026-08 / 2026-08 | Free; Lifetime Offline £9.99 | GB none; US none | Departure checklist; **sends a 2 pm notification with your morning proof: "You are good"**. |
| [Peace of Mind: OCD Support](https://apps.apple.com/gb/app/peace-of-mind-ocd-support/id6755696639) | Reassurance-first | 2026-01 / 2026-01 | Free; Peace Of Mind Premium £2.99, Peace Of Mind Premium £14.99 | GB none; US none | Photos as "undeniable proof", kept out of the gallery. |
| [Proof - OCD & Anxiety Relief](https://apps.apple.com/gb/app/proof-ocd-anxiety-relief/id6757310377) | Reassurance-first | 2026-01 / 2026-01 | Free; Unlock Forever £4.99, Unlimited Access £4.99 | GB none; US none | Must snap a photo to tick an item; "forensic" date and time stamp; 3 items free. |
| [Did I Lock? Lock Check App](https://apps.apple.com/gb/app/did-i-lock-lock-check-app/id6781271218) | Reassurance-first | 2026-06 / 2026-06 | Free; Yearly premium £29.99, Monthly  Premium £6.99 | GB none; US none | Photo proof, voice notes, Face ID, "insistent alarms" for appliances. |
| [Latched - Did I Lock It?](https://apps.apple.com/gb/app/latched-did-i-lock-it/id6761677992) | Reassurance-first | 2026-04 / 2026-04 | Free | GB none; US 2.0 (1) | One-tap time stamp; **"confidence percentages"** from your track record. |
| [Did I Lock It ? – Door Check](https://apps.apple.com/gb/app/did-i-lock-it-door-check/id6757918937) | Reassurance-first | 2026-02 / 2026-02 | Free; Montly Package £7.99 | GB none; US 4.0 (1) | One tap marks the door locked; widget; "calm reassurance throughout the day". |
| [Home Checklist - Stay Calm](https://apps.apple.com/gb/app/home-checklist-stay-calm/id1639712722) | Reassurance-first | 2024-11 / 2026-06 | Free | GB none; US none | Room-by-room checklist with photo per item; widgets. |
| [Sure — Did I Turn It Off?](https://apps.apple.com/gb/app/sure-did-i-turn-it-off/id6754885481) | Reassurance-first | 2025-11 / 2026-01 | Free | GB none; US none | Photo per item, then a "Focus Moment"; Face ID. |
| [Home Checklist: Did I Lock](https://apps.apple.com/gb/app/home-checklist-did-i-lock/id6756528574) | Reassurance-first | 2025-12 / 2026-05 | Free; Premium Monthly £0.99, Premium Yearly £2.99 | GB none; US none | Simple one-tap home checklist. |
| [DidYou - Home Checklist](https://apps.apple.com/gb/app/didyou-home-checklist/id6771498811) | Reminder | 2026-06 / 2026-07 | Free; DidYou Unlock £2.99 | GB none; US none | **Geofence alert** when you leave home; photo proof in the one-off unlock. |
| [RemLock - no more door stress!](https://apps.apple.com/gb/app/remlock-no-more-door-stress/id1599940275) | Proof (video) | 2022-05 / 2023-05 | Free; Unlimited Access Special Offer £1.99, Unlimited access £4.99 | GB none; US 4.0 (3) | Record yourself locking the door; recordings auto-delete after 24 h; widget. Not updated since 2023. |
| [PeacePoint: OCD Smart Routines](https://apps.apple.com/gb/app/peacepoint-ocd-smart-routines/id6757390396) | Reassurance-first | 2026-01 / 2026-02 | Free; Peace Seeker £3.99, Peace Giver £19.99, Peace Keeper £7.99 | GB none; US 5.0 (1) | Routines with **"target counts"**, journaling, calm tools, biometric lock; one-off unlock. |
| [LockCheck Camera](https://apps.apple.com/gb/app/lockcheck-camera/id1658489976) | Proof | 2022-12 / 2026-07 | £1.99 | GB none; US none | Tap or photograph each item; silent shutter; photos auto-delete. |
| [OCD Away](https://apps.apple.com/gb/app/ocd-away/id6752787719) | Reassurance-first | 2025-10 / 2025-10 | £0.29 | GB none; US none | Checklist plus photos kept in the app. |
| [OCD Checker](https://apps.apple.com/gb/app/ocd-checker/id6762962233) | Reassurance-first | 2026-04 / 2026-04 | Free | GB none; US none | Photos or video for each check; templates. |
| [Check List: Daily Routine Task](https://apps.apple.com/gb/app/check-list-daily-routine-task/id6756558332) | Checklist | 2025-12 / 2026-03 | Free | GB none; US none | Reusable checklists for leaving, travel, school. |
| [Locking Check](https://apps.apple.com/us/app/locking-check/id1523162174) | Neutral record | 2020-07 / 2026-09 | Free (US store only) | US none | Tap when you lock; records the time; places with a photo; resets at a set time. |

**Patterns worth noticing (our view)**

- **Pricing is all over the place**, from £0.29 one-off (OCD Away) to £79.99 a
  year (yepp). Most cluster at **£1.99–£5.99 a month and £14.99–£29.99 a
  year**. About a third use a one-off price or a lifetime option instead of, or
  as well as, a subscription.
- **Weekly plans** (yepp £4.99, Check £1.99) are a red flag for this audience.
  Avoid them.
- **Several apps build reassurance into the product**: a reassurance message
  after each check (Check, the £1.99 "Did I Lock It?"), a 2 pm push of your
  morning photos saying "You are good" (Capy Clear), "confidence percentages"
  (Latched), and "target counts" for checking several times (PeacePoint). The
  research in section 2.2 suggests these can keep the checking going.
- **A few apps build the opposite**: a pause before you can look at your
  photos again (Pruvd's One-Check Coach, OneCheck's breathing delay), urge
  tracking (MakeSure, OneCheck), and a "self-trust" entry with no photo
  (yepp). These read as therapy tools, which brings health-claim risk.
- **Pebble sits with the "neutral record" group**, with much more depth than
  any of them.

### 3.2 Checking apps on Google Play UK

| App | Downloads | Last update | Ads / in-app purchases | Headline features | Angle |
|---|---|---|---|---|---|
| [CheckAlarm: Leaving Checklist](https://play.google.com/store/apps/details?id=com.checkalarm.app) | 1k+ | 1 Oct 2026 | Ads / none | Departure alarms on chosen days; start the checklist from the lock screen when it rings; widget; photos; record your own alarm sound; 90 days of history including skipped items; says it "does not verify or guarantee" anything | Neutral record + alarm |
| [Paximus: OCD Companion](https://play.google.com/store/apps/details?id=com.foxir.paximus) | 500+ | 3 Aug 2026 | Ads / yes (iPhone: £2.99–£7.99 a month, £9.99–£39.99 a year, £14.99 lifetime) | Photo, voice note, written confirmation or checklist as proof | Proof / reassurance |
| [Did I Lock It](https://play.google.com/store/apps/details?id=com.lunchboxclassx.didilockit) (LunchBoxClassX) | 100+ | 30 Jul 2026 | None / none | Mark doors, cars and gates locked or unlocked with a timestamp; six kinds of reminder, including **when you leave a location** | Neutral record |
| [Lockt: Routines & Habits](https://play.google.com/store/apps/details?id=com.ynifa.lockt) | 100+ | 22 Jan 2026 | None / yes | Photo proof, voice memos ("I double-checked the windows"), routines that reset; calls itself a "personal reassurance companion" | Reassurance-first |
| [Stay Calm: OCD Checklist](https://play.google.com/store/apps/details?id=com.staycalm.ocdchecklist) | 100+ | 31 Oct 2025 | Ads / none | Photos auto-deleted after an hour, a day or a week | Reassurance-first |
| [Delay: OCD Recovery & ERP](https://play.google.com/store/apps/details?id=com.delayocd) | 100+ | 27 Jul 2026 | None / yes | A timer to practise delaying the urge to check. A therapy-style tool, not a checklist | Check-less (ERP-style) |
| [Locked: OCD & Anxiety Checker](https://play.google.com/store/apps/details?id=com.slidehabit.locked) | 50+ | 31 Mar 2026 | None / none | One-tap time stamps; "the undeniable proof [your brain] needs to finally relax" | Reassurance-first |
| [SureCheck – Did I Turn It Off?](https://play.google.com/store/apps/details?id=com.surecheck.surecheck) | 10+ | 30 Jan 2026 | None / none (free) | Photo with timestamp per item, checklists, widget, reminders, auto-delete | Reassurance-first |
| [Did I Lock It?](https://play.google.com/store/apps/details?id=com.uikey.didilockit) (UIKEY) | 10+ | 2 Jan 2026 | Ads / none | Time-stamped checklist, optional photo | Neutral record |
| [All Clear: Leaving Checklist](https://play.google.com/store/apps/details?id=com.dyina.leavingchecklist) | 0+ (new) | 25 Sep 2026 | Ads / yes | "3 min ago" relative times, "Check all", routines as tabs (car, bedtime, travel) | Neutral record |
| [Timemark: Photo Proof](https://play.google.com/store/apps/details?id=com.oceangalaxy.camera.new) | (not shown) | 29 Sep 2026 | None / yes | Free timestamp and GPS camera for work photos. **4.8 stars from about 942,000 reviews** | The "just take a photo" incumbent |

None of these has enough ratings for Google Play to show a score.

### 3.3 Big routine and habit apps (adjacent)

These don't do checking or photos, but they set price expectations and show
what annoys people about subscription apps. The complaint counts come from each
app's **300 most recent App Store reviews** (150 UK, 150 US).

| App | UK prices (App Store) | Ratings (UK; US) | What the 1–2 star reviews are about |
|---|---|---|---|
| [Structured](https://apps.apple.com/gb/app/structured-daily-planner/id1499198946) | £5.99/month, £17.99/year, £59.99 lifetime (offers from £2.99/month, £9.99/year) | 4.8 (30,003); 4.8 (166,954) | 66 of 300 are 1–2 star. 24 of those are about price or paywalls ("any feature you need inside is behind a paywall"), plus sync problems and losing Pro after an OS update. |
| [Routinery](https://apps.apple.com/gb/app/routine-planner-habit-tracker/id1450486923) | £3.49–£5.00/month, £26.49–£34.90/year, £0.99/week | 4.6 (2,139); 4.7 (18,009) | 39 of 300. Price and trials (14), alarms and notifications (8: "no way to silence this app's alarms in DND"), battery drain and lag after updates. |
| [Tiimo](https://apps.apple.com/gb/app/tiimo-daily-to-do-list/id1480220328) | Pro from £6.49 to £39.99 depending on length and offer | 4.5 (4,040); 4.6 (20,493) | 115 of 300. Price (40) and **AI (22)**: "the AI genuinely sucks", "overly reliant on AI", "AI assistant instantly removed all my usual setup", "the only way… to update my routines was through the AI chat bot". |
| [Fabulous](https://apps.apple.com/gb/app/fabulous-daily-habit-tracker/id1203637303) | £19.99–£56.99 a year across offers | 4.2 (12,991); 4.4 (89,139) | 225 of 300. **184 are about billing**: "keep charging me monthly even though I cancelled during free trial", "can't cancel", "deceptive". |

### 3.4 What reviews actually say

**Every written review of a dedicated checking app on the App Store (UK and
US), word for word where short:**

- **"Certain" (UK, 5★, Jan 2026):** "I just tried this before going on holiday,
  **ended up checking it often** to make sure I locked all my doors, the
  timestamp and photo proof was INVALUABLE!!"
- **DoneKit (US, 5★, Jan 2026):** "I used to fill my phone gallery with photos
  of my stove and doors… this solves that perfectly by keeping those photos
  separate. The only thing I'm missing is the ability to **add notes**."
- **"Did I Lock It? – Door Check" (US, 4★, Feb 2026):** "Only shows on iPhone,
  **not Apple Watch**."
- **"Did I Lock Up?" (US, 2★, May 2026)** and **Latched (US, 2★, May 2026):**
  "can't figure out how to unlock locked items." The apps were confusing to
  use.
- **"Did I lock?" (UK, 5★, 2021):** "I would like to **check multiple things in
  one app**… oven, hair iron/straightener, set the alarm, unplugged the
  TV/computer, lock the car/bicycle."
- **"Did I lock?" (US, 5★, 2018):** "I wish there was **a paid version with more
  features and no ads**."
- **"Check" (US, 5★, Jan 2026):** "I can finally relax knowing I did not forget
  to turn on my home alarm."

Source: Apple's public customer-reviews feed for each app.

**Our view on what this tells Pebble**

1. **Keep photos out of the camera roll, and say so.** The most-praised
   benefit.
2. **Multi-item lists are the baseline.** Pebble has this.
3. **Notes on a step, and a watch app,** are the first feature requests.
4. **Clarity beats cleverness.** Two of the seven reviews are about not
   understanding the app.
5. **Even a simple record can become the new thing to check** ("ended up
   checking it often"). This matters for the widget and for Photo notes
   (section 6.4).
6. From the big apps: **billing honesty, reliable sync and AI that never takes
   over** are what earn or lose trust.

---

## 4. Feature gap table and SWOT

Value and effort are our estimates. Effort: **S** about a day, **M** a few
days to a week, **L** more than a week. Rows are ranked by value against effort.

### 4.1 What rivals have that Pebble lacks

| Rank | Gap | Who has it (fact) | Value | Effort | Our view |
|---|---|---|---|---|---|
| 1 | **"Camera only" option on a step** (no photo from the library) | DoorCheck (live camera only), Proof (must snap a photo) | High | S | A library photo could be yesterday's. A per-step "Camera only" switch makes the record more trustworthy, and the picker already exists. |
| 2 | **A short note on a step** ("Back door: key in the drawer") | DoorCheck, Did I Lock Up?, Paximus (written confirmation); the top request in DoneKit's only review | Medium–High | S | Cheap. A note helps you remember, without being a re-check tool. |
| 3 | **iPhone widget** | Is It Locked?, Before You Go, Pruvd, MakeSure, Home Checklist – Stay Calm, "Did I Lock It? – Door Check", RemLock | High | M | Pebble offers "Pin to widget" on iPhone but has no iOS widget (`VISUAL_WALKTHROUGH.md` item 7). Build it before the iOS launch. Pebble's Android widget already matches CheckAlarm and SureCheck. |
| 4 | **Choose how long photos are kept**, or when the "checked" state clears | yepp, Stay Calm, LockCheck Camera, RemLock (24 h); Is It Locked? clears a list after 8 h (adjustable from 1 h to 3 days) | Medium–High | S–M | Offer "Delete after this run", 12 h or 48 h (default). Always say "Pebble deletes its own copy". |
| 5 | **App lock** (Face ID or fingerprint) | yepp, PeacePoint, Sure, "Did I Lock? Lock Check App" | Medium–High | S–M | Photos of the inside of a home are private. A clear Premium reason. Needs the `local_auth` package. |
| 6 | **One-off or lifetime price** | Before You Go (£3.99), DidYou (£2.99), Proof (£4.99), Capy Clear (£9.99), Paximus (£14.99), Lock'd (£24.99), Structured (£59.99), PeacePoint | Medium | S (store setup) | Some people won't subscribe to anything. Test a lifetime price after launch (section 7.3). |
| 7 | **Longer free history** | Is It Locked? (7 days free), CheckAlarm (90 days, free) | Medium | S | Pebble's free plan keeps 48 hours and Premium 21 days. Both are short next to rivals. A 7-day free window could be the more generous, more competitive choice, at small storage cost. Test it. |
| 8 | **Start from the reminder** (an alarm that opens straight onto the checklist from the lock screen) | CheckAlarm | Medium | S | Pebble's reminder taps already open the routine. Add a "Start" action button on the notification. |
| 9 | **Paste a list from Notes** when creating a routine | Before You Go | Low–Medium | S | Quick win for onboarding. |
| 10 | **A reminder when you leave home** (geofence) | Batten, Is It Locked? Plus, DidYou, Did I Lock It (Android, LunchBoxClassX) | High | L | Very useful. It needs location permission and changes both privacy forms. Plan it for v2. |
| 11 | **Share a list with the people you live with** | Is It Locked? Plus | Medium | L | Pebble's completion email is a lighter version. Revisit after launch. |
| 12 | **Apple Watch** (then Wear OS) | Is It Locked? Plus; requested in a review | Medium | L | Later. |
| 13 | **Siri and Shortcuts** | Pruvd, Before You Go, Is It Locked? | Low–Medium | M | iPhone-only. Later. |
| 14 | **Voice note or video as the record** | Pruvd, Paximus, Lockt, yepp, OneCheck+, OCD Checker, RemLock | Low | M | Harder to glance at than a photo, and filming invites rewatching. Skip. |
| 15 | **"Check all" in one tap, or hold to check the whole list** | All Clear, Is It Locked? | Low | — | Rushing defeats the point: a deliberate step-by-step check is what makes it memorable. Don't copy. |
| 16 | **Reassurance messages, a 2 pm push of your morning photos, "confidence percentages", "target counts"** | Check, "Did I Lock It? – Checklist", Capy Clear, Latched, PeacePoint | Negative | — | These can keep checking going (section 2.2). **Do not copy.** |
| 17 | **A pause before you can look at your photos again**, urge tracking | Pruvd (One-Check Coach), OneCheck, MakeSure | Unclear | M | Thoughtful, but it makes Pebble a therapy tool, with health-claim risk. Pebble's answer is not to push records at people. Don't copy for now. |

### 4.2 What Pebble has that rivals lack

| Pebble strength | Who else has it (fact) | Why it matters |
|---|---|---|
| **Android and iPhone** | Only Paximus is on both stores | Every other rival is on one store. People switch phones, and households mix them. |
| **Backup and account recovery across Android and iPhone** | Only Is It Locked? syncs, through iCloud, so iPhone-only. DoneKit, Lock'd, Capy Clear and DoorCheck say plainly that they have no cloud sync. | Pebble's backup is the only one that survives a switch between Android and iPhone. It also answers the sync complaints seen in Structured's reviews. |
| **Completion emails to a contact** | None. Is It Locked? Plus shares lists with a household. | Unique. Keep it literal, not a "safety network". |
| **Voice prompts in your own voice** (spoken guidance on a step) | None. Rivals record voice notes as proof, which is different. | Unusual and personal. Good for TikTok. |
| **Up to 4 photos per step** | Most rivals allow one photo per item | Room for a fuller record (back door and window, both sides of the hob). |
| **Template library** (leaving the house, bedtime, car, hotel, trip, school run) | Before You Go (18 templates), DoorCheck and yepp have templates. Most rivals start from a blank list. | Gets people started in seconds. |
| **Reminders plus an Android widget** | CheckAlarm and SureCheck on Android | Pebble has both, alongside everything else above. |
| **Accessibility themes, tested at double text size** | None claimed | Matters for older users. |
| **Copy that promises nothing** | Is It Locked? and Before You Go are similar. Most others say "undeniable proof", "know for sure", "you are good". | Stands out with a wary audience, and less likely to trip health-claim reviews. |
| **No ads, data not sold, works without an account** | Several rivals say the same. CheckAlarm, Paximus, Stay Calm and others on Android show ads. | Table stakes on iPhone. A real difference on Android, where many rivals carry ads. |

### 4.3 SWOT: where Pebble stands

Strengths and weaknesses are about Pebble itself. Opportunities and threats
come from outside. Facts behind each point are in sections 2, 3 and 7. The
judgements are ours.

| | Helpful | Harmful |
|---|---|---|
| **Inside Pebble** | **Strengths** | **Weaknesses** |
| | 1. **Android and iPhone.** Of about 45 checking apps, only Paximus is on both stores. | 1. **Prices are too low** (£0.89 / £6.49). That limits income, leaves no room for AI costs, and sits below almost every paid rival (section 7). |
| | 2. **Backup and account recovery that works across Android and iPhone.** No rival offers this. | 2. **Short history.** 48 hours free and 21 days Premium, against 7 days free (Is It Locked?) and 90 days free (CheckAlarm). |
| | 3. **Unique extras:** completion emails, voice prompts in your own voice, up to 4 photos per step, a template library. | 3. **Gaps rivals already fill:** an iPhone widget, step notes, "camera only", app lock, a choice of how long photos are kept, a leave-home reminder, Apple Watch, household sharing (section 4.1). |
| | 4. **Honest copy.** No medical claims or promises, so less store-review risk and more trust. | 4. **The free plan may be enough for many people.** Two routines of 10 steps covers "leaving the house" and "bedtime". Premium has to win on history, backup and photos. Test this. |
| | 5. **Private by default:** works without an account, no ads (many Android rivals show ads), data not sold, photos kept out of the camera roll. | 5. **The name doesn't say what it does.** "Pebble Routines" needs the store title and subtitle to carry "did I lock the door" and "leaving the house". |
| | 6. **Quality:** 291 tests passing, 180 screens checked at normal and double text size, plus a clear design direction. Rival reviews complain about confusing apps. | 6. **One person, no budget.** Backend fixes are still undeployed and Supabase is on the free plan. Marketing time competes with build time. |
| | 7. **A real founder story** that suits TikTok. | 7. **Not launched yet.** Every month several new rivals appear (21 on the App Store this year). |
| **Outside Pebble** | **Opportunities** | **Threats** |
| | 1. **No category leader.** 33 App Store rivals share 16 ratings, and no Google Play rival has a visible score. A few hundred genuine reviews could put Pebble on top of both stores' searches. | 1. **Free is the default.** The phone camera, free timestamp cameras (Timemark: 942,000 reviews), and free apps like SureCheck. Pebble must clearly beat "just take a photo". |
| | 2. **Android is wide open.** The biggest dedicated rival has 1,000+ downloads. | 2. **A flood of copycats.** 21 new App Store rivals in 2026 alone, many probably built quickly with AI tools. The moat is polish, trust, reviews and staying power, not features. |
| | 3. **A proven viral format:** straightener videos reach 100k to 1.8M likes, and the photo hack has made UK news. | 3. **The nearest rivals are good.** Is It Locked? and Before You Go share Pebble's tone and are adding widgets, Apple Watch, geofencing and sharing. If they add Android, Pebble's main edge shrinks. |
| | 4. **Photo notes (AI):** none of about 45 checking apps describes photos with AI (section 6). | 4. **Category scrutiny.** Rivals promise "undeniable proof" and "you are good", and one deleted app sold a "GPT Subscription". If an "AI says your oven is off" app goes wrong, stores or the press may crack down on the whole category. Stay clearly on the "describes, never promises" side. |
| | 5. **Bigger nearby audiences:** ADHD (r/ADHD about 2.3M), travellers (hotel checkout), parents, older people. | 5. **Harm to vulnerable users.** One rival's only UK review says the user "ended up checking it often". Any Pebble feature could become part of someone's checking loop. Section 6.4's guardrails are the defence. |
| | 6. **Billing trust.** 184 of Fabulous's last 300 reviews are about billing. Honest billing (no weekly plan, a trial reminder) can be a selling point. | 6. **AI backlash.** 22 of Tiimo's recent 1–2 star reviews blame its AI. AI that takes control or is unreliable loses trust fast. |
| | 7. **Shareable completion cards** turn every user into free marketing. | 7. **Subscription refusal and policy change.** About a third of rivals offer one-off prices. AI consent rules (Apple 5.1.2(i)), health-claim rules, fee changes and supplier prices (Supabase, RevenueCat, Anthropic) can all move. |

**What to do about it** (our view):

- **Use strengths to grab opportunities:** launch on Android now, while it is
  open. Lead with the founder story and the camera-roll video. Ask happy
  closed-test users for reviews, and win the race to the first 100.
- **Fix weaknesses that block opportunities:** raise prices before launch.
  Ship "camera only", step notes and app lock. Build the iPhone widget before
  the iOS launch. Test a longer free history window. Tighten the store title
  around the search phrases.
- **Use strengths against threats:** cross-platform backup, completion emails
  and honest copy are hard for one-screen iPhone apps to copy. Photo notes,
  built with the section 6.4 guardrails, give Pebble something no rival has,
  in a way that won't attract scrutiny.
- **Watch the worst combination:** low prices, a free plan that's "enough",
  and free rivals together could leave Pebble with many users and little
  income. The pricing tests in section 7.6, and testing the free plan's
  limits, address this directly.

---

## 5. Feature ideas you may have forgotten (grounded in reviews and rivals)

| Idea | The evidence behind it | Our view |
|---|---|---|
| **1. "Camera only" step option** | DoorCheck and Proof require a live photo; a library photo could be old | Top of the list. Cheap, honest, on-brand. |
| **2. A note on a step** | The only request in DoneKit's only review | Small and useful. |
| **3. Say "Not saved to your camera roll" on the photo step**, and offer **"Delete after this run"** | DoneKit's review praises keeping photos separate; several rivals offer auto-delete | Pebble already keeps its own copy. Saying so is free. |
| **4. Billing you can trust:** no weekly plan, a reminder 2 days before any trial ends, one-tap "Manage subscription" | 184 of Fabulous's last 300 reviews are about billing; Routinery and Tiimo reviews complain about trial charges | Turns the commonest complaint in the category into a reason to trust Pebble. |
| **5. Backup that just works** | Structured reviews complain about sync and losing Pro | Already in hand (`SUBSCRIPTION_REVIEW.md`, `SUPABASE_LIVE_AUDIT.md`). Show "Backed up · 08:05" quietly. |
| **6. App lock** | Offered by yepp, PeacePoint, Sure and "Did I Lock? Lock Check App" | Small build, clear Premium value. |
| **7. iPhone widget** showing "Leaving the house · Checked 08:04" | 7 iPhone rivals have a widget; Pebble's iPhone menu already offers one | Needed for the iOS launch. Keep it quiet: the time only, no photos, no "all good". |
| **8. "Start" button on the reminder** | CheckAlarm's lock-screen alarm-to-checklist | Saves a tap at the door. |
| **9. Paste a list from Notes** | Before You Go | Faster first routine. |
| **10. Shareable completion card** (cairn, time, routine name, **no photos by default**) | TikTok is the growth channel | Free marketing every time someone posts it. Never include home photos unless the user adds one. |
| **11. Watch quick-check** (Wear OS, then Apple Watch) | Is It Locked? Plus; a 4★ review asking for Apple Watch | Later. L effort. |
| **12. Leave-home reminder** (geofence) | Four rivals have it | v2, with privacy-form updates. |

---

## 6. The owner's favourite idea: factual AI photo labels

### 6.1 The answer in short (our view)

**Build it, as a small, carefully limited Premium feature, after the Android
launch and the price change.** It suits Pebble's "record, not reassurance"
idea *only if* it behaves like a caption written once, not like a helper you
can keep asking. **None of the 33 App Store or 12 Google Play checking apps
describes photos with AI.** The only AI hint found, a "GPT Subscription" in a
$0.99 app, has since disappeared from the App Store. Running costs are small at
Pebble's scale.

Two lessons from the stores shape the design:

- **AI that takes over gets punished.** 22 of Tiimo's recent 1–2 star reviews
  blame its AI ("overly reliant on AI", "AI assistant instantly removed all my
  usual setup"). Photo notes must be small, optional, and never in the way.
- **Records themselves can become the new check.** One rival's only UK review:
  "ended up checking it often". Another rival pushes your morning photos back
  to you at 2 pm with "You are good". Pebble should do the opposite.

The biggest risk is not money or technology. It is making a new, faster,
always-available way to check again. Every design choice below is about
preventing that.

### 6.2 The name

"Jev" is a fine codename, but our view is that **the feature should not have a
character name** in the app:

- A name makes the AI feel like *someone*, and someone is a person you can
  ask. That is the "Reassurance Robot" pattern in section 2.2.
- `COPY_GUIDELINES.md` asks for plain, matter-of-fact wording. A named helper
  reads as a companion, which drifts toward therapeutic tone.
- Users won't know what "Jev" means. "Photo note" explains itself.

| Option | Verdict |
|---|---|
| **Photo note** | **Recommended.** Plain, factual. Reads naturally: "Photo note: Plug appears to be out of the socket." |
| Photo description | Clear but long |
| Auto caption | Accurate, but sounds like social media |
| What's in the photo | Friendly, but a question invites more questions |
| Second look | **Avoid.** Implies looking again, which is the habit we don't want to feed |
| Jev | Keep as an internal codename only |

In marketing, describe it as "a one-line description of each photo". Never
say "AI checks your oven".

### 6.3 Wording: a label grammar that describes and never promises

**Rules**

1. Describe **the photo**, never the home. The note is about what can be seen
   in this picture, at this moment.
2. Always hedge with **"appears"** or **"looks"**. Never "is".
3. One sentence, at most about 90 characters. For "couldn't tell", add one short
   reason.
4. No "you", no advice, no feelings, no exclamation marks, no emoji, no
   colours that signal pass or fail.
5. Say what is visible even when it isn't what the step hoped for. If the
   power light appears lit, the note says so, calmly.

**Allowed sentence shapes**

- `[Thing] appears to be [state].`
- `[Thing] appears [state].` / `[Thing] looks [state].`
- `Couldn't tell from this photo. [Reason].`
- `This photo doesn't seem to show [thing].`

**Banned words and phrases** (checked by code before any note is shown):
safe, fine, okay, OK, all good, nothing to worry, don't worry, relax,
confirmed, verified, definitely, certainly, guaranteed, sure, no need to check,
you can leave, done, "is off", "is unplugged", "is locked" (without
"appears"), and any time or future words ("still", "will", "now").

**Examples**

| Step | What the photo shows | Photo note |
|---|---|---|
| Straighteners unplugged | Plug lying beside the socket | Plug appears to be out of the socket. |
| Straighteners switched off | Close-up of the power switch | Power switch appears to be in the off position. |
| Hob off | Four dials | All four hob dials appear to be at 0. |
| Oven off | Oven display | Oven display appears dark. |
| Front door locked | Closed door, lock not clear | Door appears closed. Couldn't tell if it's locked from this photo. |
| Back door locked | Thumb-turn visible | Thumb-turn appears to be turned to the horizontal position. |
| Straighteners off | Small light glowing | Power light on the straighteners appears to be lit. |
| Hob off | Dark, blurry photo | Couldn't tell from this photo. It's too dark. |
| Hob off | Photo of the floor | This photo doesn't seem to show the hob. |
| Iron unplugged | Plug half out of the socket | Couldn't tell from this photo. The plug is only partly visible. |

**When the AI is unsure.** It says **"Couldn't tell from this photo."** and
gives a short reason from a fixed list: *too dark*, *blurry*, *[thing] not in
the photo*, *[thing] only partly visible*. "Couldn't tell" is a normal, expected
answer, not an error. Our view: up to a third of notes being "couldn't tell"
is acceptable. A wrong "appears off" is not.

**How to make the wording reliable.** Don't let the model write free text.
Ask it for a structured answer (outcome = *described* / *unclear* /
*not shown*, plus subject, state and reason), then **build the sentence from
the templates in code**, run the banned-word check, and fall back to
"Couldn't tell from this photo." if anything fails. The step title is passed
as "what the person meant to photograph", with an explicit instruction not to
assume the step was done. That instruction is tested in 6.9.

### 6.4 Guardrails so it can't become a re-ask loop

Grounded in section 2.2 (repeated checking erodes memory confidence, and
always-available AI answers can accommodate compulsions) and in section 3.4
(a user of a simple record app "ended up checking it often").

| Guardrail | Why |
|---|---|
| **One note per step, per run.** Only the first photo on a step gets a note. Extra photos (Premium allows 4) show "Photo note is on the first photo." | Otherwise taking 4 photos becomes asking 4 times. |
| **The note is written once, when the photo is taken, and never again.** No "ask again", "try again", "regenerate" or chat box. | Stops the on-demand answer loop. |
| **Opening a saved photo never calls the AI.** It shows the saved text. | Looking at history must not produce a fresh answer. |
| **The note is saved into history with the photo**, read-only, with the time it was written. | It becomes part of the record, like the timestamp. |
| **No waiting.** "Complete step" never waits for the note. If the note isn't back in about 8 seconds, or the phone is offline, the step records "No photo note" and moves on. **No filling in later.** | Waiting and watching for a note to arrive is itself a check. A note that might turn up later invites re-opening the app. |
| **Neutral styling.** Same text colour for every outcome. No green tick for "off", no red for "on", no confidence percentage. | A pass/fail signal turns a description into a verdict. |
| **Not on Home, the widget, notifications or completion emails.** It lives inside the run's photo and in history only. | The time stays the hero. Notes don't follow you around. |
| **A generous daily limit** (for example, 30 notes a day), worded plainly: "Photo notes resume tomorrow." | Caps cost and the worst-case loop. Normal use never reaches it. |
| **Opt-in, per step.** Off by default, switched on in Settings, then per step in the composer. | People choose it only where it helps (straighteners, hob). |
| **Watch the totals, never the contents.** Track counts only: notes per run, photos per step, and runs repeated within 10 minutes, before and after launch. | If people start taking more photos or re-running routines, the feature is feeding checking. Pull it back. |

### 6.5 Technology: on-device or cloud

**Facts**

- Claude counts an image as `⌈width/28⌉ × ⌈height/28⌉` visual tokens. Haiku
  4.5 is on the "standard" tier (long edge up to 1568 px). Claude 4.7 and later
  models use a "high-resolution" tier (up to 2576 px), which can cost up to
  three times more tokens for the same photo.
  ([Anthropic: Vision](https://platform.claude.com/docs/en/build-with-claude/vision))
- Current Claude API prices per million tokens (input / output): **Haiku 4.5
  $1 / $5**, **Sonnet 5.5 $2 / $10**, **Opus 5.5 $4 / $20**. The Batch API
  halves these, but batch is asynchronous, so it doesn't suit a live note.
  ([Anthropic: Pricing](https://platform.claude.com/docs/en/about-claude/pricing))
- By default Anthropic deletes API inputs and outputs within 30 days and does
  not train on API data. Zero data retention is available on eligible
  endpoints and models.
  ([Anthropic privacy centre: retention](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data),
  [training](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training),
  [API and data retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention))
- Claude's limitations include possible mistakes on "low-quality, rotated, or
  very small images", and Anthropic advises human oversight for high-stakes
  uses. ([Anthropic: Vision, Limitations](https://platform.claude.com/docs/en/build-with-claude/vision))
- Haiku 4.5's time to first token is roughly 0.6 to 1.2 seconds in
  third-party measurements.
  ([Vercel AI Gateway](https://vercel.com/ai-gateway/models/claude-haiku-4.5/latency),
  [benchmark write-up](https://www.kunalganglani.com/blog/llm-api-latency-benchmarks-2026.md))
- Gemini 2.5 Flash-Lite costs about $0.10 per million input tokens (images
  included), and Gemini counts an image as 258 tokens per 768×768 tile.
  (Third-party sources: [morphllm](https://www.morphllm.com/gemini-api-pricing),
  [Google AI forum](https://discuss.ai.google.dev/t/incorrect-image-token-calculation-results-in-overcharging/99312))
- **Android on-device:** ML Kit's GenAI Prompt API sends image-and-text prompts
  to Gemini Nano on the phone, offline. It is in **alpha**, and only runs on
  phones whose AICore system supports it.
  ([Android Developers blog](https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html?hl=zh),
  [Gemini Nano](https://developer.android.com/ai/gemini-nano))
- **iPhone on-device:** Apple announced image input for its Foundation Models
  framework at WWDC 2026. It needs an Apple Intelligence-capable iPhone.
  ([Callstack](https://www.callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new))

**Cost per photo.** Our estimate: the photo is resized to 1024×768 (1,036
visual tokens), plus about 450 tokens of instructions and about 60 tokens of
answer.

| Option | Runs where | Cost per photo (est.) | Per 1,000 photos | Speed (est.) | Offline | Notes |
|---|---|---|---|---|---|---|
| **Claude Haiku 4.5** | Cloud | **≈ $0.0018** | ≈ $1.79 | 1–3 s including upload | No | **Recommended for v1.** Cheap, fast, good vision. |
| Claude Sonnet 5.5 | Cloud | ≈ $0.004–0.006 (thinking adds tokens) | ≈ $4–6 | Slower | No | Use in the accuracy test as the "is Haiku good enough?" yardstick. |
| Claude Opus 5.5 | Cloud | ≈ $0.007–0.013 (thinking can't be switched off) | ≈ $7–13 | Slowest | No | Overkill for a one-line caption. |
| Gemini 2.5 Flash-Lite | Cloud | ≈ $0.0001 | ≈ $0.12 | Fast | No | Cheapest, but adds a second AI processor to your privacy forms. Prices from third parties. |
| Gemini Nano (ML Kit GenAI, Android) | Phone | £0 | £0 | Varies by phone | **Yes** | Alpha; limited phones; quality unknown for switch positions. |
| Apple Foundation Models (iPhone) | Phone | £0 | £0 | Varies | **Yes** | New; Apple Intelligence iPhones only; needs native Swift code alongside Flutter. |
| ML Kit classic image labelling | Phone | £0 | £0 | Fast | Yes | **Not suitable.** Gives generic labels ("Appliance"), not states ("dials at 0"). |

**Cost at Pebble's scale** (Haiku 4.5, monthly, our estimate):

| Premium subscribers | 30 notes each a month (1 a day) | 60 a month (2 a day) | 150 a month (5 a day) |
|---|---|---|---|
| 500 | $27 | $54 | $134 |
| 2,000 | $107 | $214 | $536 |
| 5,000 | $268 | $536 | $1,339 |

At 60 notes a month, Photo notes cost about **$1.29 (about £1) per subscriber
per year**. At £0.89 a month that is roughly 1 in every 6 pounds you keep. At
£2.99 a month it is about 1 in 20. **This is another reason the price needs to
rise.**

**Recommended architecture (v1).**

```
Phone                     Supabase Edge Function            Anthropic API
─────                     ──────────────────────            ─────────────
Take photo
Resize to 1024 px,  ───►  describe-proof-photo:        ───►  Claude Haiku 4.5
strip location data       • signed in + Premium?             returns a structured
(already done for         • photo notes consent on?          answer (outcome,
backup uploads)           • daily limit not reached?         subject, state)
                          • does NOT store the image
                          • logs counts only
Save note with the  ◄───  builds the sentence from    ◄───
photo, locally            templates + banned-word check
```

- The API key stays on the server, never in the app.
- It reuses the existing pattern: Premium checks already run server-side for
  completion emails.
- **Offline:** no note; the step shows "No photo note (offline)". It is never
  filled in later.
- **Later (v2):** use on-device models on phones that support them (free,
  works offline), and keep the cloud for the rest. Test both against the same
  photo set first.

### 6.6 Privacy

**What is sensitive.** Photos of the inside of someone's home can show
addresses on post, house numbers, keys, valuables, medication, children and
other people. Treat every photo as personal data.

**Defaults and consent**

- **Off by default.** Turned on only from a clear consent sheet (below).
- **Apple fact:** since 13 November 2025, App Review guideline 5.1.2(i)
  requires apps to "clearly disclose where personal data will be shared with
  third parties, including with third-party AI, and obtain explicit
  permission before doing so". ([TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai),
  [QAwerk summary](https://qawerk.com/blog/apple-app-store-ai-data-sharing-guidelines/))
- Turning it off stops all sending at once. Existing notes stay in history
  unless the user deletes them ("Turn off and delete photo notes").
- Send only the resized photo and the step title. Never the routine name,
  other steps, the account email, or location.

**Consent sheet copy** (follows `COPY_GUIDELINES.md`):

> **Add photo notes?**
> When you take a photo on a step with photo notes on, Pebble sends that photo
> to Anthropic's Claude AI. It writes one short line about what the photo
> shows, for example "Hob dials appear to be at 0." The note is saved with the
> photo in your history.
>
> Notes are written by AI and can be wrong. They describe the photo, not your
> home.
>
> Pebble does not keep the photo on its servers for this. Anthropic deletes it
> within 30 days and does not use it to train AI models.
>
> **[Turn on photo notes]**  **[Not now]**

**Files to update before release** (the "keep in step" rule in `docs/store/`):

| File | Change |
|---|---|
| `docs/store/APP_PRIVACY_LABELS.md` | **Photos or Videos:** keep Linked = Yes, purpose App Functionality. Widen "Why" to: also sent to Anthropic for a photo note when the user turns photo notes on (Premium, signed in), even without backup. **Other User Content:** add the photo note text (stored on the device; backed up with run data when backup is on). **Related iOS items:** add the in-app consent for 5.1.2(i), and update `ios/Runner/PrivacyInfo.xcprivacy` if the declared types change. |
| `docs/store/DATA_SAFETY_ANSWERS.md` | **Photos:** Collected stays **Yes**. Widen the notes to cover photo notes. Shared stays **No**, because Google does not count service providers acting for you. Ephemeral: answer **No**, because Anthropic keeps API data for up to 30 days. Only revisit this if you get zero data retention and backup is off. **Other user-generated content:** add photo notes. Add a row to "Things that would change these answers": "Photo notes moved on-device: the Photos purpose changes". |
| `LEGAL_PROCESSOR_MAP.md` | Add Anthropic: what is sent, US processing, 30-day retention, the DPA and UK transfer mechanism. |
| `web/privacy.html` | New "Photo notes" section, matching the consent sheet. |
| `web/terms.html` | A "Photo notes" clause (see 6.7). |
| `CURRENT_PRODUCT_OVERVIEW_PRD.md`, `COPY_GUIDELINES.md` | Add the feature, its limits and the label grammar. |
| A short **DPIA** (data protection impact assessment) | Our view: the ICO expects one for new technology processing images of private homes. A two-page note is enough for a sole trader. |

### 6.7 Liability and store policy

**Disclaimers, where they appear**

- The consent sheet (above).
- A small "AI" tag on every note, and a one-line explainer when you tap it:
  "Written by AI from this photo. It can be wrong."
- Settings > Photo notes, About, and the Terms. Draft clause: *"Photo notes are
  generated automatically from your photo and may be inaccurate or incomplete.
  They are not a statement about the condition of your home or any appliance,
  and you should not rely on them in place of your own check."*
- Not in the main routine flow beyond the "AI" tag, following the guidelines'
  rule that disclaimers "should not dominate the main routine workflow".

**Store policies**

| Store | What applies | What to do |
|---|---|---|
| Apple | 5.1.2(i): consent before sending personal data to third-party AI (fact, above) | The consent sheet. Mention photo notes and the consent flow in the App Review notes. |
| Apple and Google | Health claims | Keep "Health apps: no health features". Never market Photo notes as help for OCD or anxiety. |
| Google Play | AI-Generated Content policy. Reports say productivity apps using AI as a feature are out of scope. ([TechCrunch](https://techcrunch.com/?p=2619733), [Google's policy page](https://support.google.com/googleplay/android-developer/answer/14094294)) | Add a quiet "Report this note" link in run detail anyway (never in the player, and it doesn't regenerate anything). It is cheap and covers you if the policy is read broadly. |
| UK consumer law (our view) | Features must match how they are described | Store copy says "a one-line AI description of the photo", never "checks" or "detects". |

Our view: this is not legal advice. A one-hour review of the Terms clause by a
solicitor before launch is worth the money.

### 6.8 Product fit

**Premium-only, or a free taster?** Our view: **Premium-only, with no free
taster.**

- It costs money per photo and needs a signed-in account for the server-side
  Premium check.
- A taster that switches off after a few uses takes something away from
  someone who may have come to lean on it. For this audience that is unkind.
  The 7-day trial (section 7) lets people try it fairly, and the paywall can
  show a fixed sample photo with its note.
- It gives Premium a clear new reason at a higher price.

**Screens that change**

1. **Settings > Photo notes** (new): the switch, consent sheet, "What is sent",
   "Turn off and delete photo notes".
2. **Routine composer, photo step:** a new option "Photo note (AI)", shown only
   once photo notes are on. Off by default per step.
3. **Routine player, photo step:** the note appears under the photo frame.
4. **Completion receipt:** photo thumbnails as now. Tapping one opens the
   viewer with its note. No notes on the receipt itself.
5. **History, run detail:** each photo step shows its thumbnail and note text.
6. **Paywall:** one comparison row, "Photo notes (AI)", plus a sample.
7. **Not changed:** Home, widget, notifications, completion emails.

**Mockups**

Player, photo step, just after taking the photo:

```
┌─────────────────────────────────┐
│ ←                     2 of 5    │
│                                 │
│ Straighteners unplugged         │
│                                 │
│ ┌─────────────────────────────┐ │
│ │                             │ │
│ │       [ your photo ]        │ │
│ │                             │ │
│ │ 08:02                       │ │
│ └─────────────────────────────┘ │
│ Photo note · AI                 │
│ Plug appears to be out of the   │
│ socket.                         │
│                                 │
│ Not saved to your camera roll   │
│                                 │
│ ┌─────────────────────────────┐ │
│ │        Complete step        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

While the note is being written, the note area shows a quiet "Adding photo
note…" line. "Complete step" works straight away. There is no "ask again"
button anywhere.

History, run detail:

```
┌─────────────────────────────────┐
│ Leaving the house               │
│ 08:00 → 08:04 · 5 of 5 steps    │
│─────────────────────────────────│
│ 08:01  Hob off              ✓   │
│        [thumb] Photo note · AI  │
│        All four hob dials       │
│        appear to be at 0.       │
│                                 │
│ 08:02  Straighteners unplugged ✓│
│        [thumb] Photo note · AI  │
│        Couldn't tell from this  │
│        photo. It's too dark.    │
│                                 │
│ 08:04  Front door locked    ✓   │
│        (no photo)               │
│                                 │
│        Report a photo note      │
└─────────────────────────────────┘
```

Settings > Photo notes:

```
┌─────────────────────────────────┐
│ Photo notes                     │
│                                 │
│ Photo notes            [ on  ]  │
│ One short AI line about each    │
│ photo, written once and saved   │
│ with it. Premium.               │
│                                 │
│ What is sent                  > │
│ Turn off and delete notes     > │
│                                 │
│ Notes can be wrong. They        │
│ describe the photo, not your    │
│ home.                           │
└─────────────────────────────────┘
```

### 6.9 Accuracy test and stop rules

Before writing app code, run a prototype (a small script, no app changes):

- **Test set:** 200 to 300 photos you take yourself. Straighteners, hob, oven,
  iron, plugs, doors and windows, each **both** on and off, locked and
  unlocked, in good and bad light, at odd angles, and some with nothing
  relevant in shot. Include "trick" cases: the step title says "off" but the
  photo shows it on.
- **Run** Haiku 4.5 and Sonnet 5.5 with the structured prompt and templates.
- **Measure:**
  - **False "appears off / unplugged / at 0 / locked" when it isn't.**
    Target: **zero** in the test set. This is the number that matters.
  - "Couldn't tell" rate. Acceptable up to about 30–35%.
  - Banned-word failures. Must be zero after the code check.
- **Stop rules after launch** (our view): pause the feature if any credible
  report of a wrong "appears off" note comes in, or if photos per step or
  repeat runs rise noticeably among people using photo notes.

### 6.10 Phased plan

| Phase | What | Rough effort | Gate to move on |
|---|---|---|---|
| **0. Prove it** | Accuracy prototype (6.9). Decide the name. Write the label rules into `COPY_GUIDELINES.md`. | 1–2 weeks; under £20 of API use | Zero false "off" notes; "couldn't tell" under about 35% |
| **1. Build behind a switch** | Edge Function, consent sheet, Settings, composer option, player row, history row, daily limit, banned-word check, "Report a photo note". Update the privacy and store docs (6.6). | 2–3 weeks | All tests green; privacy docs updated; DPIA written |
| **2. Closed beta** | 20 to 50 Premium testers. Track counts only (6.4). One-question survey: "Was the photo note useful?" | 3–4 weeks | No wrong "off" reports; no rise in photos per step or repeat runs |
| **3. Release to Premium** | Paywall row, store listing line, App Review notes. Market it as "a one-line description of each photo". | 1 week | — |
| **4. On-device** | Gemini Nano (Android) and Apple Foundation Models (iPhone) where supported, with cloud as the fallback. Re-run the same photo set. | 2–4 weeks | Matches cloud accuracy |

**Recommendation:** start Phase 0 after the Android closed test is running.
Don't let it delay the launch.

---

## 7. Pricing

### 7.1 Facts

**Store fees**

- **Apple:** 15% commission on subscriptions under the App Store Small
  Business Program (proceeds up to $1M a year; new developers qualify).
  ([Adapty](https://adapty.io/blog/app-store-small-business-program/),
  [Appbot](https://appbot.co/blog/app-developers-apple-google-small-business-programs/))
- **Google Play:** from 30 June 2026 in the UK, US and EEA, the fee is split
  into a **10% service fee** (which applies to all auto-renewing
  subscriptions) plus a **5% billing fee** when using Google Play Billing.
  That totals **15%**, the same as before.
  ([Android Developers blog, June 2026](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html),
  [Adapty](https://adapty.io/blog/google-play-billing-changes-subscriptions-fees/))
- **UK prices include 20% VAT.** The stores handle the VAT and, as we
  understand it, work out their fee on the price without VAT. So for each £1 a UK customer pays, you keep about
  £1 ÷ 1.2 × 0.85 ≈ **£0.71**. US prices are shown before sales tax, so you
  keep about **$0.85** per $1.
- **RevenueCat:** free below $2,500 in monthly tracked revenue, then 1% of
  tracked revenue (before store fees).
  ([costbench](https://costbench.com/software/subscription-billing/revenuecat/),
  [toolradar](https://toolradar.com/tools/revenuecat/pricing))
- **UK steering:** the CMA has consulted on making Apple and Google allow links
  to cheaper outside payments. Apple is pushing back.
  ([TechRepublic](https://www.techrepublic.com/article/news-uk-apple-google-app-store-reforms-cma/),
  [iClarified](https://iclarified.com/101620)) Not something to plan on yet.

**Benchmarks** (RevenueCat State of Subscription Apps 2026)

- Median yearly price rose to **$34.80** (from $31.60). The average monthly
  price rose to about **$8.01**. Typical bands: $7.99–$9.99 a month,
  $29.99–$39.99 a year.
- **Low-priced apps earn far less over time.** Median yearly revenue per
  subscriber is **$62.19 for high-priced apps against $10.69 for low-priced
  ones**, nearly 6×. Trial conversion is **8.9% against 4.3%**.
- Trials of 17–32 days convert at a 42.5% median, against 25.5% for trials
  under 4 days.
- Annual subscribers who cancel rarely come back (about 5% reactivate).
  Monthly subscribers come back at about 4× that rate.

Sources: [RevenueCat report](https://www.revenuecat.com/state-of-subscription-apps),
[summary of figures](https://theswiftk.it.com/blog/ios-subscription-pricing-strategy-2026),
[ARPU Brothers](https://arpubrothers.com/blog/revenuecat-subscription-app-report-2026/),
[9to5Mac](https://9to5mac.com/2026/05/27/new-report-shows-annual-app-subscribers-rarely-return-after-they-cancel/)

**Rivals' UK prices** (App Store, section 3):

| App | Monthly | Yearly | One-off / lifetime |
|---|---|---|---|
| Home Checklist: Did I Lock | £0.99 | £2.99 | — |
| DoneKit | £1.99 | £9.99 | — |
| Batten | £1.99 | £14.99 | — |
| Is It Locked? Plus | £1.99 | £14.99 | — |
| Lock'd | £1.99 | £19.99 | £24.99 |
| Peace of Mind: OCD Support | £2.99 | £14.99 | — |
| OneCheck+ | £2.99 | — | — |
| Paximus (several offers) | £2.99–£7.99 | £9.99–£39.99 | £14.99 |
| Check: Stop Anxiety Checking | £3.99 (also £1.99 a week) | £22.99 | — |
| Pruvd Pro | £4.99 | £24.99 | — |
| MakeSure | £5.99 | £29.99 | — |
| Did I Lock? Lock Check App | £6.99 | £29.99 | — |
| Did I Lock It? – Door Check | £7.99 | — | — |
| yepp | £9.99 (also £4.99 a week) | £79.99 | — |
| One-off only | Before You Go £3.99, DidYou £2.99, Proof £4.99, Capy Clear £9.99, DoorCheck £0.99, LockCheck Camera £1.99, OCD Away £0.29 | | |
| Big routine apps | Structured £5.99, Routinery £3.49–£5.00, Tiimo Pro various | Structured £17.99, Routinery £26.49–£34.90 | Structured £59.99 |

The middle of the checking apps is about **£2.99 a month and £19.99 a year**.

### 7.2 What you keep per sale

| Price | UK: you keep (after VAT and 15%) | US: you keep (after 15%) |
|---|---|---|
| £0.89 / month (current plan) | **£0.63** | — |
| £6.49 / year (current plan) | **£4.60** | — |
| £2.99 or $2.99 / month | £2.12 | $2.54 |
| £3.99 or $3.99 / month | £2.83 | $3.39 |
| £19.99 or $19.99 / year | £14.16 | $16.99 |
| £24.99 or $24.99 / year | £17.70 | $21.24 |

### 7.3 Recommendation (our view)

| Market | Monthly | Yearly | Yearly saving shown |
|---|---|---|---|
| **UK** | **£2.99** | **£19.99** | "Save 44%" |
| **US** | **$2.99** | **$19.99** | "Save 44%" |
| Other countries | Use the stores' automatic price conversion from the US price, then check a few key markets (Canada, Australia, the EU) by hand | | |

**Why**

- It sits right in the middle of the checking apps: above DoneKit, Batten and
  Is It Locked? (£1.99 / £14.99), level with Lock'd and Peace of Mind, below
  Pruvd, MakeSure and yepp, and well below the big routine apps. Pebble does
  more than any of them, and the price still feels like a fair small utility,
  which matters for a careful audience.
- It is more than **3×** what you keep per subscriber at £0.89 / £6.49 (see
  7.5), and RevenueCat's data says very cheap apps also convert worse.
- It leaves room for Photo notes, which cost about £1 per subscriber a year.
- Keep **one paid plan, "Personal Premium"**. No weekly plan: the Fabulous
  complaints show weekly and confusing plans cost trust.

**Trial or introductory offer?**

- **Yes: a 7-day free trial on the yearly plan only.** No trial on monthly,
  because monthly is already a small commitment.
- Pebble sends its own reminder 2 days before the trial ends ("Your Premium
  trial ends on Friday. You won't be charged if you cancel before then."),
  with a one-tap link to manage the subscription. This answers the most common
  complaint in the category.
- The free plan already works as a long, no-card "trial", so don't stack extra
  discounts at launch.
- Housekeeping: `SUBSCRIPTION_REVIEW.md` and `docs/store/APP_STORE_LISTING.md`
  currently say there is **no trial**. The paywall fine print, store
  descriptions and App Review notes all need updating if you add one.
- If any closed-test users already bought at £0.89, keep them on that price.
  Both stores support keeping existing subscribers on an old price.

**Lifetime?** Not at launch. Test a **£49.99 lifetime** later for people who
won't subscribe. If Photo notes ship, leave them out of lifetime because they
cost money every time.

### 7.4 Assumptions behind the scenarios

- 60% of subscribers on yearly, 40% on monthly. This is our assumption.
  RevenueCat finds productivity apps lean more monthly than most categories, so
  check it against your own data after launch.
- All UK prices, so a cautious case. US sales keep a little more per sale.
- Fixed costs about **£520 a year**: Supabase Pro (about $25 a month), the
  Apple Developer Program (about £79), plus domain and email.
- Photo notes at 60 notes per subscriber a month on Haiku 4.5 (about £1 per
  subscriber a year), assuming about $1.30 to the pound. Check the rate.
- RevenueCat at 1% once monthly revenue passes $2,500.
- Before income tax and National Insurance.

### 7.5 Revenue scenarios (per year)

| Plan | Subscribers | Customers pay | You keep after VAT and store fee | RevenueCat | Photo notes (AI) | Fixed costs | **Left before tax** |
|---|---|---|---|---|---|---|---|
| **Current: £0.89 / £6.49** | 500 | £4,083 | £2,892 | £0 | £496 | £520 | **£1,876** |
| | 2,000 | £16,332 | £11,568 | £0 | £1,983 | £520 | **£9,066** |
| | 5,000 | £40,830 | £28,921 | £408 | £4,957 | £520 | **£23,036** |
| **Recommended: £2.99 / £19.99** | 500 | £13,173 | £9,331 | £0 | £496 | £520 | **£8,315** |
| | 2,000 | £52,692 | £37,324 | £527 | £1,983 | £520 | **£34,294** |
| | 5,000 | £131,730 | £93,309 | £1,317 | £4,957 | £520 | **£86,515** |
| **Higher test: £3.99 / £24.99** | 500 | £17,073 | £12,093 | £0 | £496 | £520 | **£11,078** |
| | 2,000 | £68,292 | £48,374 | £683 | £1,983 | £520 | **£45,188** |
| | 5,000 | £170,730 | £120,934 | £1,707 | £4,957 | £520 | **£113,750** |

Without Photo notes, add the "Photo notes" column back to the last column.

**Our view.** "A couple of thousand paying subscribers" only becomes a living
at about £3 a month or more. At the current prices you would need about 6,500
subscribers to keep what 2,000 bring in at £2.99 / £19.99.

### 7.6 What to A/B test (in order)

Use RevenueCat Offerings (and its Experiments feature, if your plan includes
it) so prices can change without a new app build. Test one thing at a time,
and run each test until each group has at least a few hundred paywall views.

1. **Price level:** £2.99 / £19.99 against £3.99 / £24.99. Measure revenue per
   paywall view and refunds, not just conversion.
2. **Trial:** 7-day trial on yearly against no trial. Also watch refund
   requests and support emails, since this audience may find trials stressful.
3. **Which plan is pre-selected** on the paywall: yearly or monthly.
4. **Paywall timing:** the third routine and the 11th step (the limits) against
   also showing it once after the 5th completed run.
5. **Later:** a £49.99 lifetime option. Then, once Photo notes exist, whether
   the sample on the paywall lifts conversion.

---

## 8. Where people talk about this (low-budget marketing)

`docs/store/LAUNCH_MARKETING_HOOKS.md` already has 10 video concepts and good
rules ("laugh with, never at"; no #OCD hashtags; no medical claims). This adds
the places.

| Where | Size or signal (fact) | How to show up (our view) |
|---|---|---|
| **TikTok:** #hairstraightener, #straightener, and searches like "did I turn my straighteners off" | A straightener-anxiety video with about 1.8M likes ([TikTok](https://www.tiktok.com/@shaneblud/video/7620850048234016022)); tag pages [#hairstraightener](https://www.tiktok.com/tag/hairstraightener), [#straightener](https://www.tiktok.com/tag/straightener) | Concept 1 ("my camera roll is 40% straighteners") and concept 6 (founder story) first. Use #didilockthedoor, #leavingthehouse, #grwm, #morningroutine. **Don't use #OCD, #anxiety or #intrusivethoughts to reach people.** |
| **r/ADHD** | About 2.3M members ([GummySearch](https://gummysearch.com/r/ADHD), re-check) | Answer "how do you remember if you locked the door?" threads with real tips first. Mention Pebble only where the rules allow. |
| **r/LifeProTips, r/organization, r/CasualUK, r/AskUK** | Large general subreddits (sizes not checked) | Share the "one photo, with the time, in a list" tip. Read each sub's self-promotion rules first. |
| **r/OCD** | About 260k members ([GummySearch](https://gummysearch.com/r/OCD)) | **Do not promote here.** Read it to understand the experience. If someone asks about apps, you may answer honestly, but never pitch. |
| **Mumsnet, Netmums** | Long-running UK straighteners and "did I leave it on" chat ([Mumsnet example](https://www.mumsnet.com/talk/style_and_beauty/5549805-what-are-travel-straighteners-like-these-days)) | The hotel checkout, big trip and school-run templates fit here. Read their rules on self-promotion before posting anything about Pebble. |
| **UK local and lifestyle press** | The straighteners photo hack has already been a news story ([Get Surrey](https://www.getsurrey.co.uk/news/uk-world-news/womans-genius-hack-stop-you-17746606)) | Pitch "solo UK founder builds an app because of their straighteners camera roll" to local papers and lifestyle sites. Free, and it ranks in search. |
| **Product Hunt** | Pruvd launched there ([Product Hunt](https://www.producthunt.com/posts/1162799)) | One free launch day once iOS is live. |
| **Pinterest** | — | Pin the "leaving the house checklist" as an image (already in the marketing hooks). |
| **OCD-UK and other charity forums** | — | Don't promote. If you ever want to work with a charity, ask them first, and take their advice on wording. |

---

## 9. Top 5 actions for the owner

1. **Change the prices before launch:** £2.99 / £19.99 in the UK and $2.99 /
   $19.99 in the US, with a 7-day free trial on yearly only and Pebble's own
   reminder before it ends. Set it up in RevenueCat Offerings so you can test
   £3.99 / £24.99 later without a new build. (Claude can update the paywall
   copy, store listings and `SUBSCRIPTION_REVIEW.md` for the trial.)
2. **Don't wait for AI to launch.** Carry on with the `START_HERE.md` list:
   Play Console forms, then the 12-tester, 14-day closed test. The market has
   no leader yet, and Android is the thinnest part of it.
3. **Ship the cheap gap-closers next:** a "Camera only" option on photo
   steps, a short note on a step, a choice of how long photos are kept, and app
   lock. Build the iPhone widget before the iOS launch: seven iPhone rivals
   have one, and Pebble's iPhone menu already offers it. Test a 7-day free
   history window, since rivals offer 7 to 90 days free.
4. **Run the two-week Photo note accuracy test** (section 6.9) with about 200
   of your own photos and Claude Haiku 4.5. Call the feature "Photo note", not
   "Jev". Build it only if there are zero false "appears off" notes, and only
   with the one-note-per-photo, no-ask-again guardrails in 6.4.
5. **Start the free marketing now:** post TikTok concept 1 (the camera roll)
   and concept 6 (your founder story), answer "did I lock the door" threads in
   r/ADHD and r/LifeProTips with real tips, and pitch the founder story to UK
   local press. Never use #OCD or make claims about anxiety.

---

## Sources

All accessed 4 October 2026.

**Product and pricing data**
- Anthropic: [Pricing](https://platform.claude.com/docs/en/about-claude/pricing), [Vision](https://platform.claude.com/docs/en/build-with-claude/vision), [API and data retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention), [Retention (privacy centre)](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data), [Training (privacy centre)](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training)
- Google: [Play billing and fee changes, June 2026](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html), [ML Kit GenAI Prompt API alpha](https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html?hl=zh), [Gemini Nano](https://developer.android.com/ai/gemini-nano), [AI-Generated Content policy](https://support.google.com/googleplay/android-developer/answer/14094294)
- Apple: [5.1.2(i) third-party AI consent (TechCrunch)](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai), [Small Business Program (Adapty)](https://adapty.io/blog/app-store-small-business-program/), [Foundation Models image input (Callstack)](https://www.callstack.com/blog/on-device-ai-after-wwdc-2026-whats-new)
- RevenueCat: [State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps), [figures summary](https://theswiftk.it.com/blog/ios-subscription-pricing-strategy-2026), [9to5Mac on reactivation](https://9to5mac.com/2026/05/27/new-report-shows-annual-app-subscribers-rarely-return-after-they-cancel/), [RevenueCat pricing (costbench)](https://costbench.com/software/subscription-billing/revenuecat/)
- Gemini pricing (third party): [morphllm](https://www.morphllm.com/gemini-api-pricing)
- Latency (third party): [Vercel AI Gateway](https://vercel.com/ai-gateway/models/claude-haiku-4.5/latency)

**Competitors:** each app's store link is in the tables in section 3. Store
data came from Apple's public search and lookup service (`itunes.apple.com`),
each App Store page (in-app prices), Apple's customer-reviews feed, and Google
Play UK search results and app pages, all on 4 October 2026. Apps no longer
found in the App Store: OCD Rescuer (id6751641770), Checked OCD Companion
(id6741740614), "Did I lock it?" (id6751820916) and Home Key Reminder
(id1665279188).

**Research on checking and AI**
- [Repeated checking causes memory distrust (Utrecht)](https://research-portal.uu.nl/en/publications/repeated-checking-causes-memory-distrust/)
- [OCD-like checking in the lab: a meta-analysis](https://utrecht-main-test.atmire.com/items/9902ebe4-19a8-4ae1-a5f2-25aab70c8c32)
- [Reassurance Robots: OCD in the Age of Generative AI (arXiv)](https://arxiv.org/html/2602.19401v1)
- [Why using ChatGPT for OCD reassurance can make OCD worse](https://www.ftpsych.ca/?p=19901)
- [Photographs as a checking OCD coping mechanism (MacEwan)](https://journals.macewan.ca/studentresearch/article/view/2684)
- [OCD-UK: occurrences of OCD](https://www.ocduk.org/?p=2376)

**Regulation**
- [CMA app store steering (TechRepublic)](https://www.techrepublic.com/article/news-uk-apple-google-app-store-reforms-cma/), [Apple's response (iClarified)](https://iclarified.com/101620)
