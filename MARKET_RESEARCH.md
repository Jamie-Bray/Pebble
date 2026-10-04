# Pebble Routines: Market, Competitor and Pricing Report

Last updated: 4 October 2026 (SWOT added)
For: the owner. Written in plain English. No code changes come with this report.

## How to read this report

- **Fact** means something found in a public source. Each one has a link.
- **Our view** means judgement: a recommendation, an estimate or a guess. These
  are labelled so you can disagree with them.
- **Dates.** Every price, rating and review count was checked on **4 October
  2026**. Store prices change often and differ by country.
- **One limit you should know about.** This research ran in a cloud session
  whose network policy blocks `apps.apple.com` and `play.google.com`. Store
  details therefore come from search-engine copies of the store pages, not from
  the live pages. Before you rely on a number for a big decision, open the
  store page yourself. The ones most worth re-checking are marked **(re-check)**.

---

## 1. Summary

**The market.** Photographing the straighteners or the hob "just in case" is a
widespread habit. A whole wave of small "photo proof" checking apps launched in
2025 and 2026, mostly on iPhone. Almost none of them have enough ratings for the
App Store to show a score, so **nobody owns this category yet.** Android is
thinner still: the closest like-for-like Android app (SureCheck) is free, with no
paid tier. The big routine apps (Structured, Routinery, Tiimo, Fabulous) have
huge audiences but don't do checking or photos.

**Pebble's edge.** Pebble is the only one of these with Android **and** iPhone,
optional backup and account recovery, completion emails, voice prompts, a
template library, and copy that is careful not to promise anything. Most rivals
lead with "undeniable proof" or "everything is safe". That is exactly the
language Pebble avoids, and it is a real point of difference for a cautious
audience.

**Price.** £0.89 a month and £6.49 a year is too low. After VAT and the store
fee you would keep about **£0.63 a month or £4.60 a year** per person. At those
prices you would keep roughly **£11,600 a year** from 2,000 subscribers, before
running costs and tax. That is not a living. Our view: launch at **£2.99 a month / £19.99 a year** in
the UK and **$2.99 / $19.99** in the US, with a 7-day free trial on the yearly
plan only, and test £3.99 / £24.99 later. At £2.99 / £19.99, 2,000 subscribers
come to roughly **£34,000 a year** after all costs and before tax.

**AI photo labels ("Jev").** Our view: **build it, carefully, after launch.**
It is cheap to run (about **$0.0018 per photo** with Claude Haiku 4.5) and
nothing in the market does it properly. But for people who check, an AI that
answers "is it off?" on demand can quickly become a new thing to check. The
design below allows **one factual note per photo, written once, saved with the
photo and never re-asked.** Call the feature **"Photo note"**, not a character
name. Make it Premium-only, opt-in, and run a two-week accuracy test before
writing any app code.

A SWOT summary of where Pebble is strong and where it lags is in section
4.3. The top 5 actions are at the end (section 9).

---

## 2. The market

### 2.1 Who has this problem (facts)

| Fact | Source |
|---|---|
| OCD affects about 1.2% of people in the UK, an estimated 750,000 people. | [OCD-UK](https://www.ocduk.org/?p=2376) |
| r/OCD has about 260,000 members; r/ADHD about 2.3 million **(re-check)**. | [GummySearch r/OCD](https://gummysearch.com/r/OCD), [GummySearch r/ADHD](https://gummysearch.com/r/ADHD) |
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

### 2.3 Shape of the competition (our view)

- **Crowded but immature.** At least 15 small checking apps launched or updated
  in 2025–2026, most from solo developers and most iPhone-only. Almost none show
  a star rating yet. Nobody has brand recognition.
- **Android is underserved.** Pebble is launching on Android first, where the
  field is a handful of free or tiny apps.
- **The real incumbent is the phone camera.** Most people just take a photo,
  and it ends up buried in their camera roll. Pebble has to beat "free and
  already on my phone". The pitch is: one photo, saved with the time, in a list
  that shows what you already checked, kept out of your camera roll.

---

## 3. Competitors

All checked on 4 October 2026. "Too few to show" means the App Store says the
app "hasn't received enough ratings or reviews to display an overview".

### 3.1 Checking and "photo proof" apps

| App (platform) | Price model and prices | Headline features | Ratings | Praise and complaints | Sources |
|---|---|---|---|---|---|
| **Yepp – Your OCD Companion** (iOS) | Free, then subscription: **$4.99/week, $9.99/month, $79.99/year** | "Peace-of-mind camera"; time-stamped photos stored in the app; auto-delete after a day, a week, or your choice | Too few to show **(re-check)** | No reviews found. The weekly plan is the kind of pricing users complain about in other apps (see Fabulous). | [App Store (AT)](https://apps.apple.com/at/app/yepp-your-ocd-companion/id6744017205?l=en-GB), [App Store (TR)](https://apps.apple.com/tr/app/yepp-your-ocd-companion/id6744017205) |
| **Pruvd: OCD Checking Proof** (iOS) | Free, then subscription: **CA$6.99/month, CA$34.99/year**; AU$7.99 / AU$39.99 | Check once and save photo, video or voice proof; review instead of going back. Says it is "not a replacement for professional treatment" | Too few to show | Launched on Product Hunt. No user reviews found. | [App Store (CA)](https://apps.apple.com/ca/app/pruvd-ocd-checking-proof/id6757632735), [App Store (AU)](https://apps.apple.com/au/app/pruvd-ocd-checking-proof/id6757632735), [Product Hunt](https://www.producthunt.com/posts/1162799) |
| **OCD Rescuer: Anxiety Relief** (iOS) | Free with 1 routine; Premium **$19.99/year**, 3-day free trial | Custom checklists, time-stamped photo per step, "verified history" | Not found **(re-check)** | No reviews found. Its copy promises to "eliminate all doubt", which Pebble's rules forbid. | [App Store (US)](https://apps.apple.com/us/app/ocd-rescuer-anxiety-relief/id6751641770) |
| **DoneKit: Did I Lock It?** (iOS) | Free, then **$1.99/month or $9.99/year** | Photo-based checklist, "visual proof before you leave" | **5.0 (1 rating)** | Praise: "used to fill [my] phone gallery with photos of [my] stove and doors… this app solves that perfectly by keeping those photos separate." | [App Store (US)](https://apps.apple.com/us/app/donekit-did-i-lock-it/id6756815675) |
| **RemLock – no more door stress!** (iOS) | Free, then **$4.99** one-off for unlimited access ($1.99 special offer) | Door-lock reminders and checks, pitched "against OCD and anxiety" | **US: 4.0 (3 ratings).** A third-party site claims 4.6 from 9,296 ratings, probably worldwide **(re-check)** | No review text found | [App Store (US)](https://apps.apple.com/us/app/remlock-no-more-door-stress/id1599940275), [appstor.io](https://remlock-door-reminders.appstor.io/amp) |
| **Did I lock it?** (iOS, Dragica Soldo) | **$0.99** to buy, plus in-app purchases, including a **"GPT Subscription"** (₹699 in India) | Photo proof of locking, a widget, works offline | 5.0 (1 rating) | No reviews. **Note: the "GPT Subscription" suggests someone is already trying AI here.** | [App Store (US)](https://apps.apple.com/us/app/-/id6751820916), [App Store (IN)](https://apps.apple.com/in/app/did-i-lock-it/id6751820916) |
| **Did I Lock Up? – Checklist** (iOS) | Free | One-tap lock log with relative times ("Locked 10 minutes ago"), optional notes | Not found | None found | [App Store (US)](https://apps.apple.com/us/app/-/id6755089038) |
| **OCD Away** (iOS) | **$0.99** to buy | Leaving-home checklist with photos kept inside the app; history of past checklists | Not found | None found | [App Store](https://apps.apple.com/app/id6752787719) |
| **Checked OCD Companion** (iOS, UK store) | Free | Instant check log, custom lists, no cloud. Its copy says it gives "visual confirmation that everything is safe" | Too few to show | None found | [App Store (GB)](https://apps.apple.com/gb/app/checked-ocd-companion/id6741740614) |
| **PeacePoint: OCD Smart Routines** (iOS) | Free with 1 routine; **one-off lifetime unlock** in 3 price tiers (amounts not found) | Routines, "target counts for tasks requiring extra reassurance", journaling, calm tools, biometric app lock, colour themes | Not found | None found. Target counts build repeated checking into the product, which Pebble should not copy. | [App Store (US)](https://apps.apple.com/us/app/peacepoint-ocd-smart-routines/id6757390396) |
| **Paximus: OCD Companion** (iOS and Android) | Free with in-app purchases (prices not found) | Photo, voice note, written confirmation or checklist as "proof"; time-stamped records | Not found | None found | [Google Play](https://play.google.com/store/apps/details?id=com.foxir.paximus&hl=en_US), [App Store](https://apps.apple.com/us/app/-/id6745874911) |
| **DoorCheck Photo Proof** (iOS) | **Free; no subscriptions, no in-app purchases** | Live camera only (no library import), templates, local reminders, history search and date filter, on-device only | Not found | None found | [mwm.ai listing](https://mwm.ai/apps/doorcheck-photo-proof/6767494303) |
| **Locking Check** (iOS) | Free | Records the time you locked up; location registration with photos | Not found | None found | [App Store](https://apps.apple.com/py/app/locking-check/id1523162174?l=en-GB) |
| **Home Key Reminder** (iOS) | Free | Leaving-home templates, originally designed for older people | Not found | None found | [App Store](https://apps.apple.com/us/app/-/id1665279188) |
| **SureCheck – Did I Turn It Off?** (Android) | **Free, no ads, no premium tier** | Photo proof with large timestamps, custom checklists, **home-screen widget**, daily reminders, auto-delete photos, dark mode; updated 30 Jan 2026 | Not found **(re-check)** | None found. **The closest Android like-for-like, and it is free.** | [Google Play](https://play.google.com/store/apps/details?id=com.surecheck.surecheck&hl=en) |
| **Stay Calm: OCD Checklist** (Android) | Free | Photos of tasks, auto-deleted after an hour, a day or a week (your choice) | 50 to 100+ downloads | None found | [Google Play](https://play.google.com/store/apps/details?id=com.staycalm.ocdchecklist&hl=en_US) |
| **Lockt: Routines & Habits** (Android) | Not found | Photo of the locked door or unplugged iron; updated 22 Jan 2026 | Not found | None found | [Google Play](https://play.google.com/store/apps/details?id=com.ynifa.lockt&hl=en_US) |
| **Secure Check – Did I lock It?** (Android) | Not found | Private log of daily checks (garage, stove, door); updated 25 Apr 2026 | Not found | None found | [Google Play](https://play.google.com/store/apps/details?id=com.dornbros.securecheck_lockit) |

### 3.2 Routine and habit apps (adjacent, much bigger)

| App | Price model and prices | Headline features | Ratings | Praise and complaints | Sources |
|---|---|---|---|---|---|
| **Structured – Daily Planner** | UK: **£5.99/month, £17.99/year, £59.99 lifetime**. US list: $2.99/month, $29.99/year, $99.99 lifetime (promotions vary) | Visual timeline planner | **4.8 from about 155,300** (App Store) | Praise: the timeline, and time saved ("saved me at least two hours a week"). Complaint: **sync problems**, especially iCloud. | [App Store](https://apps.apple.com/app/apple-store/id1499198946), [Cool Curation UK review](https://coolcuration.com/structured-app-review-uk), [Saner review](https://blog.saner.ai/structured-review/) |
| **Routinery** | Premium from about **$5/month** or **$36–$39.49/year**, plus weekly, 6-month and family plans | Step-by-step routine timer, templates | **4.7 from about 16,200** (App Store) | Recognised as a leading routine app | [App Store](https://apps.apple.com/us/app/routine-planner-habit-tracker/id1450486923), [habi.app comparison](https://habi.app/insights/best-daily-routine-apps/) |
| **Tiimo** | **$7.99/month, $79.99/year**; 7-day trial on yearly; family $119.99 | Visual planner for ADHD and autistic users, AI planning | **4.6 from about 14,800** (App Store) | Strong brand with neurodivergent users | [App Store](https://apps.apple.com/app/tiimo/id1480220328), [Lifestack](https://lifestack.ai/blog/tiimo-pricing) |
| **Fabulous** | About **$49.99/year** (US), offers from $16.99 to $59.99 | Coached habit programmes | App Store **4.4 (88,901)**; Google Play **3.9 (about 589,000)**; Trustpilot **3.2** | Complaints are dominated by **billing confusion, auto-renewal and surprise charges**, plus a bloated interface | [habi.app](https://habi.app/insights/fabulous-alternatives/), [Nibble review](https://nibble-app.com/blog/fabulous-app-review), [Trustpilot](https://trustpilot.com/review/thefabulous.co?page=10) |

### 3.3 What users praise and complain about

Fact: the checking apps have almost no public review text. Most have 0 to 3
ratings. What there is, plus the adjacent apps, points the same way:

- **Praise:** "keeps those photos separate" from the camera roll (DoneKit). A
  clear visual timeline (Structured). Saving time.
- **Complaints:** billing, auto-renewal and surprise charges (Fabulous).
  Sync and backup failures (Structured). The camera roll filling up with
  near-identical photos (DoneKit's reviewer, your TikTok signal).

**Our view.** With so little review data, the best source of real complaints
is your own closed test. Add a one-line "What's missing?" prompt to the
support email in Settings, and read every reply.

---

## 4. Feature gap table and SWOT

Value and effort are our estimates. Effort: **S** about a day, **M** a few
days to a week, **L** more than a week. Ranked by value against effort.

### 4.1 What competitors have that Pebble lacks

| Rank | Gap | Who has it | Value | Effort | Our view |
|---|---|---|---|---|---|
| 1 | **"Camera only" option on a step** (no photo from the library) | DoorCheck | High | S | A library photo could be yesterday's. A per-step "Camera only" switch makes the record more trustworthy. Very cheap: the picker already exists. |
| 2 | **Choose a shorter photo auto-delete** (for example, delete after the run, after 12 hours, or after 48 hours) | Stay Calm, Yepp, SureCheck | High | S–M | Privacy-minded people like it, and shorter windows cost less storage. Keep 48 hours as the free default. Always say "Pebble deletes its own copy." |
| 3 | **Relative time on Home** ("Checked 2 h ago" next to "08:04") | Did I Lock Up? | Medium | S | Pebble already shows "Checked · 8:04". Adding the relative time is quick. |
| 4 | **App lock** (Face ID or fingerprint to open Pebble) | PeacePoint | Medium–High | S–M | Photos of the inside of a home are private. Adds a Premium reason. Needs the `local_auth` package. |
| 5 | **iPhone widget** | Did I lock it? (iOS); SureCheck (Android) | High on iOS | M | Pebble offers "Pin to widget" on iPhone but has no iOS widget (`VISUAL_WALKTHROUGH.md` item 7). Fix this before the iOS launch. |
| 6 | **Lifetime purchase option** | Structured, PeacePoint, RemLock | Medium | S (store setup) | Some people hate subscriptions. Test it later. If Photo notes ship, leave them out of lifetime because they cost money every time. |
| 7 | **Voice note as the record** (say "hob is off" and save it) | Pruvd, Paximus | Low–Medium | M | Pebble records voice *prompts*, not voice records. A spoken record is harder to glance at than a photo. Low priority. |
| 8 | **Video proof** | Pruvd, OCD Checker | Low | M | Large files, and filming invites watching it over and over. Skip. |
| 9 | **Location reminder when you leave home** | Locking Check (location) | High | L | Very useful, but it needs location permission and changes both privacy forms. Consider it for v2. |
| 10 | **"Target counts"** (check something N times) | PeacePoint | Negative | — | Builds repeat checking into the product. **Do not copy.** |
| 11 | **Journaling and calm tools** | PeacePoint, Fabulous | Low | M | Off-brand: therapeutic. Skip. |

### 4.2 What Pebble has that they lack

| Pebble strength | Who else has it | Why it matters |
|---|---|---|
| **Android and iPhone, one product** | Only Paximus is on both | Most rivals are iPhone-only. Pebble starts on Android, where the competition is thinnest. |
| **Optional cloud backup and account recovery** | None of the checking apps | Rivals are local-only. Losing a phone means losing your routines. This also answers the Structured "sync" complaint. |
| **Completion emails to a contact** | None found | Unique. Keep it literal, not a "safety network". |
| **Voice prompts in your own voice** | None found | Unusual and personal. Good for TikTok. |
| **Template library** (leaving the house, bedtime, car, hotel, trip, school run) | DoorCheck, Home Key Reminder (basic) | Gets people started in seconds. |
| **Up to 4 photos per step, 21-day history** | Few | Room for a fuller record. |
| **Android home-screen widget** | SureCheck | Already built. |
| **Accessibility themes, tested at double text size** | None claimed | Matters for older users and the Home Key Reminder audience. |
| **Copy that promises nothing** | None. Rivals say "undeniable proof", "eliminate all doubt", "everything is safe" | Rivals' copy can feed the doubt it claims to fix. Pebble's honest tone stands out, and is less likely to trip health-claim reviews. |
| **No ads, data not sold, works without an account** | Several local-only apps say the same | Table stakes. Keep saying it. |

### 4.3 SWOT: where Pebble stands

Strengths and weaknesses are about Pebble itself. Opportunities and threats
come from outside. Facts behind each point are in sections 2, 3 and 7. The
judgements are ours.

| | Helpful | Harmful |
|---|---|---|
| **Inside Pebble** | **Strengths** | **Weaknesses** |
| | 1. **Android and iPhone.** Of the checking apps found, only Paximus is also on both. | 1. **Prices are too low** (£0.89 / £6.49). That limits income, and it leaves no room for AI costs (section 7). |
| | 2. **Backup and account recovery.** Every checking rival found is local-only. | 2. **Zero ratings or reviews on day one.** Rivals have almost none either, but the first 50 reviews will matter a lot. |
| | 3. **Unique extras:** completion emails, voice prompts in your own voice, a template library, up to 4 photos per step, 21 days of history. | 3. **The free plan may be enough for many people.** Two routines of 10 steps covers "leaving the house" and "bedtime". Premium has to win on history, backup and photos. Test this. |
| | 4. **Honest copy.** No medical claims or promises, so less store-review risk and more trust from a wary audience. | 4. **Gaps rivals already fill:** no "camera only" option, no app lock, no choice of auto-delete window, and no iPhone widget even though the menu offers one (section 4.1). |
| | 5. **Private by default:** works without an account, no ads, data not sold, photos kept out of the camera roll. | 5. **The name doesn't say what it does.** "Pebble Routines" needs the store title and subtitle to carry "did I lock the door" and "leaving the house". |
| | 6. **Quality:** 291 tests passing, 180 screens checked at normal and double text size, plus a clear design direction. | 6. **One person, no budget.** Backend fixes are still undeployed and Supabase is on the free plan. Marketing time competes with build time. |
| | 7. **A real founder story** that suits TikTok. | 7. **Not yet launched on either store.** Every week a rival can collect reviews first. |
| **Outside Pebble** | **Opportunities** | **Threats** |
| | 1. **No category leader.** Most checking apps have 0 to 3 ratings. The first app with a few hundred good reviews can own the searches. | 1. **Free is the default.** The phone camera, plus free apps like SureCheck and DoorCheck. Pebble must clearly beat "just take a photo". |
| | 2. **Android is underserved.** Pebble launches there first. | 2. **Copying is easy.** These apps are simple to build, and AI coding tools make new ones appear every month. Polish, trust and reviews are the moat, not features. |
| | 3. **A proven viral format:** straightener videos reach 100k to 1.8M likes, and the photo hack has made UK news. | 3. **Rivals' AI verdicts.** If someone's "AI says your oven is off" goes wrong, stores or the press may crack down on the whole category. Stay clearly on the "describes, never promises" side. |
| | 4. **Photo notes (AI):** nobody does this properly yet (section 6). | 4. **Harm to vulnerable users.** If any feature becomes part of someone's checking loop, that hurts them and Pebble's reputation. Section 6.4's guardrails are the defence. |
| | 5. **Bigger nearby audiences:** ADHD (r/ADHD about 2.3M), travellers, parents, older people. | 5. **Smart plugs and smart locks** solve the problem in hardware for people who buy them. |
| | 6. **Billing trust.** The big habit apps get billing complaints. Honest billing (no weekly plan, trial reminders) can be a selling point. | 6. **Subscription fatigue.** Some rivals charge once ($0.99, $4.99, lifetime unlocks). Some people will refuse any subscription. |
| | 7. **Shareable completion cards** turn every user into free marketing. | 7. **Store and policy changes:** AI consent rules (Apple 5.1.2(i)), health-claim rules, fee changes. Supplier prices can also rise (Supabase, RevenueCat, Anthropic). |

**What to do about it** (our view):

- **Use strengths to grab opportunities:** launch on Android now. Lead with the
  founder story and the camera-roll video. Ask happy closed-test users for
  reviews to win the "no leader yet" race.
- **Fix weaknesses that block opportunities:** raise prices before launch, and
  ship "camera only", app lock and the iPhone widget. Tighten the store title
  around the search phrases.
- **Use strengths against threats:** honest copy plus the Photo note
  guardrails make Pebble the trustworthy choice if the category gets
  scrutiny. Backup and cross-platform support are hard for one-screen free
  apps to copy.
- **Watch the worst combination:** low prices, a free plan that's "enough", and
  free rivals together could leave Pebble with many users and little income.
  The pricing tests in section 7.6, and testing the free plan's limits,
  address this directly.

---

## 5. Feature ideas you may have forgotten (grounded in complaints)

| Idea | The complaint or signal behind it | Our view |
|---|---|---|
| **1. "Camera only" step option** | A library photo might be old, which brings the doubt back | Top of the list. Cheap, honest, on-brand. |
| **2. Photos never touch the camera roll** (say it clearly), plus **"Delete after this run"** | DoneKit review; "my camera roll is 40% straighteners" | Pebble already keeps its own copy. Say so on the photo step ("Not saved to your camera roll"). |
| **3. Billing you can trust:** no weekly plan, a reminder 2 days before any trial ends, one-tap "Manage subscription" | Fabulous billing complaints | Turns a common category complaint into a reason to trust Pebble. It also matters more for an anxious audience. |
| **4. Backup that just works** | Structured sync complaints | Already in hand (`SUBSCRIPTION_REVIEW.md`, `SUPABASE_LIVE_AUDIT.md`). Make "Backed up · 08:05" visible but quiet. |
| **5. App lock** | Private photos of your home on a shared or borrowed phone | Small build, clear Premium value. |
| **6. iPhone widget** showing "Leaving the house · Checked 08:04" | The bus-stop moment (TikTok concept 2) | Needed for the iOS launch anyway. |
| **7. "Start from the reminder"**: a notification action that opens straight onto step 1 | People check in a rush at the door | Reminder taps already open the routine. A "Start" action button saves a tap. |
| **8. Shareable completion card** (cairn, time, routine name, **no photos by default**) | TikTok is the growth channel | Free marketing every time someone posts it. Never include home photos unless the user adds one. |
| **9. One short text note on a step** ("Back door: key in the drawer") | Did I Lock Up? and Paximus offer notes | Small, useful, and not a re-check tool. |
| **10. Watch quick-check** (Wear OS, then Apple Watch) | Hands full at the door | Later. L effort. |

---

## 6. The owner's favourite idea: factual AI photo labels

### 6.1 The answer in short (our view)

**Build it, as a small, carefully limited Premium feature, after the Android
launch and the price change.** It suits Pebble's "record, not reassurance"
idea *only if* it behaves like a caption written once, not like a helper you
can keep asking. Nobody in the market does this well. The one AI hint we found
is a "GPT Subscription" in a $0.99 app. Running costs are small at Pebble's
scale.

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

Grounded in section 2.2: repeated checking erodes memory confidence, and
always-available AI answers can accommodate compulsions.

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

**Competitor prices** (section 3): DoneKit $1.99 / $9.99; OCD Rescuer $19.99
a year; Pruvd about US$5 / US$25 (CA$6.99 / CA$34.99); Yepp $9.99 / $79.99;
Structured (UK) £5.99 / £17.99 / £59.99 lifetime; Routinery about $5 / $36;
Tiimo $7.99 / $79.99.

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

- It sits in the middle of the checking apps (above DoneKit, close to OCD
  Rescuer and Pruvd, far below Yepp) and well below the big routine apps. It
  still feels like a fair, small utility, which matters for a careful audience.
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
3. **Ship three cheap gap-closers next:** a "Camera only" option on photo
   steps, a choice of shorter photo auto-delete, and app lock. Build the iPhone
   widget before the iOS launch, because the app already offers "Pin to widget"
   on iPhone.
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

**Competitors:** links are in the tables in section 3.

**Research on checking and AI**
- [Repeated checking causes memory distrust (Utrecht)](https://research-portal.uu.nl/en/publications/repeated-checking-causes-memory-distrust/)
- [OCD-like checking in the lab: a meta-analysis](https://utrecht-main-test.atmire.com/items/9902ebe4-19a8-4ae1-a5f2-25aab70c8c32)
- [Reassurance Robots: OCD in the Age of Generative AI (arXiv)](https://arxiv.org/html/2602.19401v1)
- [Why using ChatGPT for OCD reassurance can make OCD worse](https://www.ftpsych.ca/?p=19901)
- [Photographs as a checking OCD coping mechanism (MacEwan)](https://journals.macewan.ca/studentresearch/article/view/2684)
- [OCD-UK: occurrences of OCD](https://www.ocduk.org/?p=2376)

**Regulation**
- [CMA app store steering (TechRepublic)](https://www.techrepublic.com/article/news-uk-apple-google-app-store-reforms-cma/), [Apple's response (iClarified)](https://iclarified.com/101620)
