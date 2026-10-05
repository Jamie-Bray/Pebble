# Pebble Routines: Design Direction

Last updated: 3 October 2026

For: the owner (plain English) and whoever builds it (exact numbers, Flutter
approach). Every claim points to a screenshot in
`scratchpad/final_walkthrough/` or a file in `lib/`.

**One-line direction:** *the time is the hero.* Checking worry comes from not
being sure you did it. Pebble's real answer is a plain record ("Front door
locked, 08:02"), and right now that record is the smallest text on every
screen. The redesign makes the moment of checking something you feel, and
makes the result something you can see at a glance.

All copy below follows `COPY_GUIDELINES.md` and
`docs/store/LAUNCH_MARKETING_HOOKS.md`: no "safe", no "peace of mind", no
"relax", no "evidence". It sticks to facts: *checked, saved, 08:02.*

---

## 1. Verdict

### Where it already looks current (keep these)

- **Editorial type on the hero screens.** The DM Serif headlines on ivory
  (`iphone__onboarding_1_welcome.png`, `iphone__home_populated.png`,
  `iphone__paywall.png`) are distinctive and premium, closer to Things 3 or
  Headspace's 2025 editorial look than a generic checklist app. The
  struck-through "~~habit tracker~~ reliable kind of check." headline is the
  best piece of brand work in the app.
- **The palette.** Muted forest/sage on warm ivory (High Noon), sand plus
  forest plus terracotta (Sandstone, `iphone__theme_21_sandstone_home.png`),
  and the warm caramel dark (`iphone__theme_01_nordicNight_home.png`) all feel
  calm and grown-up. The high-contrast yellow on black
  (`iphone__theme_15_highContrastDark_home.png`) is properly bold.
- **The "What can Pebble do?" demo card** (`iphone__onboarding_possibilities.png`):
  a vertical checklist with checked steps, a photo chip and a pulsing current
  step. **This is the best screen in the app, and the real player should look
  more like it.**
- **History timeline** (`iphone__history_list.png`): large serif times
  ("6:18 am") already do the "time is the hero" idea. Extend that pattern
  everywhere else.
- **Theme picker mini-previews** (`iphone__appearance.png`) and the onboarding
  theme cards (`iphone__onboarding_2_theme.png`).
- **Honest, well-structured sheets:** leave prompt
  (`iphone__player_leave_prompt.png`), delete account
  (`iphone__account_delete_confirm.png`), and the reminder editor summary line
  "Every Monday at 8:15 AM. First one tomorrow."
  (`iphone__reminder_editor_existing.png`).

### Where it looks dated or "almost polished"

1. **The two most important moments are the plainest screens.**
   - Step check-off (`iphone__player_step1.png`): a big empty double ring, a
     heavy sans instruction, and a button. Tapping waits 400 ms, briefly shows
     a stock Material green tick (`Colors.green.shade600`,
     `routine_player_screen.dart:1179`), then the next step hard-cuts in with
     no transition. Haptics and sound are **off by default**
     (`player_settings_controller.dart:27,31`).
   - Completion (`iphone__player_complete.png`): a generic check circle,
     "Routine complete", and a one-row "SUMMARY · Steps completed 4 of 4"
     card. There is no time, no photos, and nothing that marks *this run*.
     It reads like a form receipt from 2018.
2. **The button font changes on the most-tapped buttons.** "Complete step",
   "Start", "Back to Home" and "Review routine" render in the platform
   fallback (Roboto/SF heavy), not DM Sans. Compare `iphone__player_step1.png`
   with `iphone__onboarding_1_welcome.png`. Cause: 14 call sites pass
   `textStyle: const TextStyle(fontSize:…, fontWeight:…)` to
   `*Button.styleFrom`, which replaces the theme font instead of merging with
   it (for example `routine_player_screen.dart:1345, 2132, 2156`,
   `routine_list_screen.dart:2225`).
3. **Three typefaces plus a fallback.** DM Sans is the theme font
   (`colors.dart:110`), but Outfit is used in 80 places (onboarding, paywall,
   account, history, sign-in, home) and DM Serif in 27. Fonts are also fetched
   at runtime by `google_fonts` with nothing bundled, so **a first launch
   offline (local-first app!) shows system fonts.**
4. **Home is cluttered at the top and empty in the middle**
   (`iphone__home_populated.png`). There are three different header controls:
   a filled sliders circle, a "Backup off" pill, and an outlined avatar. The
   tagline wraps to two lines when the chip reads "Checking backup"
   (`iphone__home_with_resume.png`). Below that sits a "5 Steps" bar of four
   unlabelled 16 px icons (bell, mail, gear, chevron). Then there is about
   230 pt of nothing, and the reassurance line ("Last completed 3h ago · 5 of
   5 steps") is 13 pt grey.
5. **Too many visual dialects.** I count 22 corner radii, about 38 font sizes
   and 8 weights in `lib/`. The `PebbleTypography` and `PebbleSpacing` tokens
   exist but are used 9 times. Cards are variously border-only
   (`iphone__onboarding_3_starting_point.png`), fill plus border plus shadow
   (`iphone__templates_gallery.png`, `iphone__settings.png`), shadow-only
   (`iphone__onboarding_possibilities.png`), or a white hard-coded card
   (completion).
6. **Old chrome patterns.** These include a white bottom bar with a drop
   shadow and a centre FAB, hairline dividers under every page title
   (`iphone__reminders_global.png`, `iphone__account_hub_signedOutFree.png`),
   outlined "web form" secondary buttons, and floating back buttons with no
   backdrop, so content scrolls under them (`iphone__settings_scrolled.png`).
   iOS 26 and Material 3 Expressive have moved to floating translucent chrome,
   capsule buttons and tinted (tonal) fills.
7. **Colour roles leak.**
   - The paywall CTA is a brighter, more saturated green than the rest of the
     app (`iphone__paywall.png`, from `_legibleThemeAccent`,
     `pebble_paywall.dart:2085`).
   - Composer "Voice tip ✓" is painted in the *error* red
     (`iphone__composer_edit.png`; `_StepOptionTone.clay => cs.error`,
     `routine_composer_step_row.dart:438`).
   - Sandstone shows a green Start and a terracotta FAB fighting on one screen
     (`iphone__theme_21_sandstone_home.png`), plus a terracotta "Required"
     chip next to a red "Voice tip" chip (`iphone__theme_sandstone_composer.png`).
   - The completion summary card is hard-coded `Colors.white` with
     `Color(0xFF2D2B2A)` text (`routine_player_screen.dart:2196-2208`), so it
     will be a white slab in every dark theme.

**Overall:** the brand foundation (type, palette, voice) is 2026-grade. The
*system* (tokens, components, motion) is a 2021 Material app that has been
painted carefully. The fix is not a redesign. It is to tighten the system and
add about four signature moments.

---

## 2. Design principles for Pebble

1. **Show the record, not the reassurance.** We never say "you're fine"; we
   show "Front door locked · 08:02". Times, photos and counts are the hero
   content, set in large serif with tabular figures. Words stay factual
   ("All checked.", "Saved on this device.").
2. **One thing at a time, one action per screen.** Each screen has exactly one
   filled button. Everything else is tonal or text. If two things are filled,
   one of them is wrong.
3. **Every check should be felt.** The check-off must land in under 300 ms
   with a physical response (stroke, haptic, optional stone-tap sound), so the
   moment sticks in memory. That is the whole point for someone who forgets
   whether they checked.
4. **Settle, don't bounce.** Motion is weighty and decelerating, like a stone
   coming to rest: critically damped springs, no elastic overshoot, no
   confetti. (Today the toasts use `Curves.elasticOut`,
   `zen_notifications.dart:166`, which is the opposite of calm.)
5. **Quiet surfaces, floating chrome.** Content sits on flat ivory with
   hairlines or soft fills. Only things that float (sheets, the tab bar, back
   buttons, the "checked" card) get blur or shadow.
6. **Fast for the fast checker.** Never block input for animation. State
   commits instantly and motion plays over it. Reduce Motion gives instant
   cross-fades, and the haptic is kept, because haptics are not motion.

---

## 3. Visual system tightening

Put all of this in `lib/core/theme/tokens.dart` (extend the existing classes)
and in a new `lib/core/ui/pebble_buttons.dart`. Do not hand-type numbers in
screens.

### 3.1 Type

**Two families only.**

- **DM Serif Display**: display text, page titles, and big numbers (times,
  prices, counts).
- **DM Sans**: everything else.
- **Remove Outfit** (80 call sites, mechanical swap to `GoogleFonts.dmSans`).
- **Bundle the fonts.** Add the TTFs under `assets/fonts/` and declare them in
  `pubspec.yaml`. Set `GoogleFonts.config.allowRuntimeFetching = false;` in
  `main()`.
- **Stop overriding button fonts.** Use
  `Theme.of(context).textTheme.labelLarge!.copyWith(...)`.

| Token | Family | Size / line-height | Weight | Tracking | Used for |
|---|---|---|---|---|---|
| `displayXL` | DM Serif | 56 / 56 | 400 | -1.0 | The time on completion and on the Home "checked" card |
| `display` | DM Serif | 44 / 46 | 400 | -0.6 | Home routine name, onboarding heroes, paywall hero |
| `title1` | DM Serif | 34 / 38 | 400 | -0.4 | **Every** page title (History, Templates, Reminders, Settings, Your account, Themes, Backup, Style Studio) |
| `title2` | DM Serif | 26 / 30 | 400 | -0.2 | In-page heroes ("Free plan", "Backup is off", "Personal Premium") |
| `step` | DM Serif | 38 / 42 | 400 | -0.4 | Player step instruction (was DM Sans 32/600) |
| `sheetTitle` | DM Sans | 22 / 28 | 600 | -0.2 | Bottom-sheet titles ("Leave routine?", "Add reminder") |
| `headline` | DM Sans | 18 / 24 | 600 | 0 | Card and row titles |
| `bodyLarge` | DM Sans | 17 / 25 | 400 | 0 | Lead paragraphs |
| `body` | DM Sans | 15 / 22 | 400 | 0 | Body, row subtitles |
| `caption` | DM Sans | 13 / 18 | 500 | 0 | Meta lines, chips |
| `overline` | DM Sans | 12 / 16 | 600 | +1.2, UPPERCASE | "YOUR NEXT RIPPLE", "STEPS" |
| `button` | DM Sans | 17 / 20 | 600 | 0 | All button labels |

Rules:

- **Weights allowed:** 400, 500, 600. Delete w200, w300, w700, w800 and w900
  (now 251 uses combined).
- **Times:** use `FontFeature.tabularFigures()` wherever times or counts can
  change, so digits don't jitter. DM Serif digits are lining and fine for big
  static times. Use DM Sans for time stamps in lists.
- **AM/PM:** follow the device locale (`DateFormat.jm(locale)`). Today History
  shows "6:18 am", run detail shows "4:13 AM", and reminders show "8:15 AM". In
  serif displays, set the meridiem at 45% size and baseline-aligned.
- **Italics:** only for the wordmark tagline. Remove from the Settings
  subtitle (`iphone__settings.png`) and "Hold to reorder".
- **Sentence case everywhere.** Fix "Reorder Steps", "Duplicate Routine",
  "Delete Routine", "Stats & History" (`iphone__home_routine_actions_menu.png`),
  "Save Changes" (`iphone__reorder_steps.png`), and "Unlock Routine Style"
  (`iphone__home_style_upsell_free.png`).
- **Large text:** keep the current `FittedBox(scaleDown)` approach only for
  single-line titles. Let body copy wrap. The a11y captures
  (`iphone__a11y2.0x_player_step1.png`) already look good, so don't regress
  them.

### 3.2 Spacing (4-pt base)

`PebbleSpacing`: `xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · x3 40 · x4 56`.
(This adds `sm 12` and `lg 20` and renames the rest. Keep old names as
deprecated aliases for one release.)

- Page gutter: 24 (width ≥ 375), 20 (width < 375,
  `small__home_populated.png`).
- Card padding 20, compact rows 16. Icon-to-text gap 12.
- Space between sections: 32. Overline to content: 12.
- Title to subtitle: 8. Subtitle to content: 24. **No divider line under page
  headers** (remove the `Container(height: 1)` in
  `pebble_navigation.dart:275` and `zen_components.dart:116`).

### 3.3 Corner radii (5 tokens, concentric)

`PebbleRadius`: `xs 8` (chips inside cards, thumbnails in strips) · `sm 12`
(icon tiles, inputs) · `md 16` (small cards, segmented controls) · `lg 24`
(cards, sheets, photo frames) · `pill 999` (all buttons, chips, tab bar).

- **Concentric rule** (the iOS 26 "concentricity" idea): inner radius = outer
  radius minus padding. A 24-radius card with 12 padding holds a 12-radius
  tile.
- Replace the 22 values now in use (10, 13, 14, 18, 20, 22, 26… are the ones
  to delete).

### 3.4 Surfaces: borders vs shadows

| Surface | Light themes | Dark themes |
|---|---|---|
| **Page** | `bgBase`, flat. Remove the always-on `AmbientParticlesPainter` on Home (`routine_list_screen.dart:325`): it repaints every frame forever, ignores Reduce Motion, and shows as stray specks (`iphone__home_empty.png`) | same |
| **Card** (content) | `bgBase` + 1 px hairline `fg @ 10%`, no shadow, r24 | `surfaceLow`, no border, no shadow |
| **Grouped list** (Settings, action menu) | single fill `fg @ 4%`, no border, no shadow, r24, rows divided by inset hairlines | `surfaceLow` |
| **Selected card** | 1.5 px `action` border + `action @ 6%` fill | same |
| **Floating** (sheets, tab bar, back button, toasts, "checked" card) | shadow `0 8 24 rgba(0,0,0,.08)` + optional `BackdropFilter` blur σ=24 over `bgBase @ 78%` | `surfaceHigh @ 82%` + blur, shadow `0 8 24 rgba(0,0,0,.32)` |

This removes the triple-treatment cards on Templates and Settings
(`iphone__templates_gallery.png`, `iphone__settings.png`). They currently use
fill, border and shadow together, and that combination is the main "almost
polished" tell.

### 3.5 Colour roles (refine, don't replace)

Add three semantic roles to `PebbleThemeX` (`colors.dart:66`), each with a
safe default so existing themes don't change unless you opt in:

- `action`: the one filled CTA per screen. Already exists as `actionAccent`.
- `done`: the colour of a completed check (stroke, pebble, time chip). Must
  reach 3:1 against `bgBase` for glyphs, or 4.5:1 if used for text.
- `doneContainer`: `done @ 10%` for the "checked" card and the time chip.

| Theme | `action` (fill / on) | `done` | Notes |
|---|---|---|---|
| High Noon | `#4A5D4E` / white (7.1:1) | `#4E7A58` (4.8:1 on `#FDFCF5`) | A slightly livelier sage than the structure green, so "done" reads as a result, not a button |
| Sandstone | `#3E5E45` forest / `#FBF6EC` | `#3F6B4A` (5.3:1) | **Terracotta becomes the accent for highlights only** (step badges, the time chip ring, the "+"). If terracotta ever carries text, use `#A3552F` (5.0:1). The current `#C4714A` with cream text is only 3.4:1 |
| Warm dark (`nordicNight`, shown as "Pebble Dark") | `#C4946A` / `#1B1813` (6.6:1) | `#8DB592` (7.7:1) | The palette already defines secondary `#7FA87E`, so use it as `done` |
| Sage Mist | `#6B8A72` / `#162119` | `#7FB08A` (6.7:1) | |
| High Contrast Dark | `#FFDD00` / black | `#FFDD00` | Keep. Never tint |
| Reduced Contrast | as is | `accent` | Don't add saturation here |

Leaks to fix:

- **Paywall:** use `action` directly. Delete the saturation boost in
  `_legibleThemeAccent` (`pebble_paywall.dart:2085`) or have it return
  `primary`.
- **Voice tip chip:** `_StepOptionTone.clay` should map to `cs.secondary`, or
  to a neutral `fg @ 8%` with an accent icon. Never `cs.error`
  (`routine_composer_step_row.dart:438`). Red is reserved for destructive
  actions.
- **Completion card:** `Colors.white`, `0xFF2D2B2A`, `0xFF746D66` and
  `0xFF6F6861` should become `surfaceLow`, `textPrimary`, and
  `readableSecondaryText` (`routine_player_screen.dart:2196-2283`).
- **Visual anchor success:** `Colors.green.shade600` should become `done`
  (`routine_player_screen.dart:1179`).
- **Switches:** `activeTrackColor: action`, `thumbColor: onAction`. Not iOS
  system green (`iphone__settings.png`).
- **Theme names:** a separate ticket, already noted in
  `VISUAL_WALKTHROUGH.md`. Several "dark" themes are near-identical browns.
  Don't fix this with new colours now. Rename or curate later.

### 3.6 Iconography

- **One icon family:** Lucide at 1.75 stroke. Today the app uses 369 Material
  `Icons.*` and 339 `LucideIcons.*`. The mix is visible in Settings
  (`iphone__settings.png`: filled Material palette and info icons beside
  Lucide outlines) and in the completion check (`Icons.check`).
- **Sizes:** 16 (inline with caption), 20 (rows, buttons), 24 (nav, headers).
- **Icon tile:** 40×40, r12, fill `fg @ 6%` (dark: `surfaceHigh`), icon 20 in
  `textPrimary @ 80%`. Use the same tile on onboarding lists, the action menu,
  Settings and Templates. They currently use 3 sizes.
- **Unlabelled icons are not allowed in primary surfaces.** The "5 Steps"
  bar's bell, mail and gear (`iphone__home_populated.png`) either get text or
  move into the routine menu.

### 3.7 Buttons (one component set)

Create `PebbleButton.primary / .secondary / .tertiary / .destructive /
.compact` in `lib/core/ui/pebble_buttons.dart`. All take
`label, icon?, onPressed, busy`.

| Kind | Look | Size | Where |
|---|---|---|---|
| **Primary** | Filled `action`, capsule (`pill`), label `button` style | 56 h, full width, ≥ 24 from edges | One per screen: Start, Complete step, Done, Continue, Save |
| **Secondary** | **Tonal**: `action @ 10%` fill, `action` label, no border | 52 h, full width | "What can Pebble do?", "Stay here", "Run again", "Sign in" |
| **Tertiary** | Text only, `body` 15/500, `readableSecondaryText` | min 44 h tap | "Skip for now", "Maybe later", "Cancel", "Previous" |
| **Destructive** | Text in `error`. Filled red **only** inside the final confirmation sheet | as above | "Discard progress", "Delete account" |
| **Compact** | Tonal capsule, 40 h, `caption`/600 | inline | "Play guidance", chip actions |

- Press feedback (all kinds): scale 0.97 over 90 ms on pointer-down, spring
  back on release. Reuse `ZenBounceButton`, which already exists.
- Disabled: `fg @ 8%` fill, `fg @ 38%` label, no shadow. This matches the
  current disabled "Complete step" (`iphone__player_photo_step.png`), which is
  fine.

### 3.8 Inconsistencies found (fix list)

| Where | What differs | Fix |
|---|---|---|
| `iphone__player_step1.png` vs `iphone__onboarding_1_welcome.png` | CTA font is platform fallback w700 vs DM Sans | §3.1, remove the 14 `const TextStyle` overrides |
| `iphone__onboarding_4_starter_preview.png` | "Use this starter routine" is w400; other CTAs w600 | `PebbleButton.primary` |
| `iphone__player_leave_prompt.png` | "Leave and save" w400 and 52 h; player CTA w700 and 56 h | same |
| `iphone__player_locked_routine.png` | "Renew Premium" is a compact pill used as the main action | Primary, full width |
| Home `Start` (r≈22), onboarding CTA (r≈18), completion (r20), player (pill), paywall (r≈20) | five different button shapes | all capsule |
| Back buttons | bare chevron (player/composer); 44 square outlined r14 (templates, reminders, account, reorder, legal, style studio); "← Back" text (onboarding); grey filled circle + overline (`iphone__sign_in.png`); grey filled square (`iphone__paywall.png`) | one `PebbleBackButton`: 44 circle, floating glass (§3.4). The player and composer keep a bare chevron because they are full-screen tasks |
| Page titles | serif (Home, History, Paywall, Sign in) vs sans 26-30 (Templates, Reminders, Settings, Account, Themes, Backup, Style Studio, Reorder) | all `title1` serif |
| Sheet titles | sans bold left (`iphone__home_create_choice_sheet.png`), sans centred (`iphone__home_style_upsell_free.png`), sans 600 centred small (`iphone__reminder_editor_sheet.png`) | `sheetTitle`, left-aligned, unless the sheet is a single centred confirmation |
| "Your Routines" | sans when collapsed, serif when expanded (`iphone__home_populated.png` vs `iphone__home_routines_sheet_open.png`) | serif `title2` in both |
| Run detail title | "Morning reset." in sans bold with a period (`iphone__history_run_detail.png`); Home uses serif with a period | serif |
| Header subtitles | italic (Settings), regular (Account), regular plus divider (Reminders) | `body`, regular, no divider |
| Home header | three control styles; tagline wraps (`iphone__home_with_resume.png`, `small__home_premium.png`) | see §5 Home |
| Composer chips | "Require photo" shrunk to ~11 pt to fit; "Required" 15 pt (`iphone__composer_edit.png`) | all chips `caption` 13/500; let the row wrap to 2 lines |
| Templates cards | left accent bar + fill + border + shadow (`iphone__templates_gallery.png`); onboarding list = border only | Card style §3.4; drop the left bar |
| Routine list rows | unexplained left vertical bar (`iphone__home_routines_sheet_open.png`) | remove, or use it only as the reorder handle while in reorder mode |
| History rows | a tiny "—" dash glyph before "5 of 5 steps" (`iphone__history_list.png`); "Stored on this device" pill on every row in dark (`iphone__theme_nordicNight_history.png`) | 5 mini dots (filled = done, ring = skipped); storage status shown once in the header |
| `iphone__onboarding_2_theme.png` | "Looking at High Noon - warm and light" uses a hyphen | "High Noon · warm light" |
| `iphone__composer_new.png` | "STEPS – 0 ADDED" | "Steps"; show the count only when > 0 |
| `iphone__history_empty.png` | the capture shows Home, not History empty | fix the capture harness so the History empty state is reviewed |

---

## 4. Signature moments (the wow)

Ranked by impact ÷ effort. All of them are built with Flutter built-ins
(`AnimationController`, `SpringSimulation`, `CustomPainter`, `PathMetric`,
`BackdropFilter`, `HapticFeedback`), the existing `just_audio`, and **no new
packages**. Every one checks
`MediaQuery.disableAnimationsOf(context) || !playerSettings.enableTransitions`
and falls back to a 120 ms cross-fade. Haptics stay on in Reduce Motion.

**Shared motion tokens** (new `PebbleMotion` in `tokens.dart`):

```dart
static const tap = Duration(milliseconds: 90);
static const quick = Duration(milliseconds: 150);      // fades, colour
static const standard = Duration(milliseconds: 250);   // enters
static const emphasized = Duration(milliseconds: 400);
static const enter = Curves.easeOutCubic;
static const emphasizedCurve = Cubic(0.2, 0.0, 0.0, 1.0); // M3 emphasized decelerate
// "Settle": no visible overshoot (<2%). Use for layout moves.
static final settle = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.9);
// "Land": one small, weighty bounce. ONLY for pebbles landing on completion.
static final land = SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 0.62);
```

Replace `Curves.elasticOut` in `zen_notifications.dart:166,176` and
`reminder_editor_sheet.dart:68` with `enter` / `settle`.

**Sound design** (optional chime already exists at
`assets/audio/step_complete.wav`): re-cut it as a **soft stone tap**. That
means pebble on pebble: about 120 ms, no reverb tail longer than 300 ms,
peaking around -14 dBFS. Add `assets/audio/routine_complete.wav`: three quick
taps rising slightly in pitch (about 450 ms total), the sound of a small
cairn being stacked. It is on-brand, it is not a "ding", and it films well for
TikTok concept #5. Make sure the audio session is *ambient* (mixes with
music, respects the iOS silent switch). Configure it with `audio_session`,
which `just_audio` already depends on transitively.

---

### Moment 1: The step check-off ("tap, stroke, stamp, settle"). Impact: very high. Effort: M

**What the user sees and feels:** they tap **Complete step** and the response
is instant. A check *draws itself* inside the ring, in the theme's `done`
colour, with a light tap in the hand. A small time chip **"08:02"** appears
under the step. The whole step then shrinks and glides up into a slim
**trail** of completed steps at the top of the screen, and the next step rises
into place. Over the routine, the trail becomes a visible list: "✓ Hair tools
unplugged 08:01 · ✓ Stove and oven dials off 08:02". That is the record,
built in front of them.

**Layout change (enables the moment):**

- Above the step, a **trail** of completed steps: at most 2 rows visible,
  older ones collapse into a "+3 done" tonal pill (tap it to expand). Each row
  is 40 h: a 16 px `done` check, the step name in `body` at `textSecondary`,
  and the time right-aligned in `caption` with tabular figures. No
  strike-through, because a strike-through reads as "cancelled".
- Header becomes one line: "Leaving the house · 1 of 5" (`caption`). The
  progress bar stays.
- The ring stays as the "stage" for the check (it is the existing focus
  guide, `AnimatedVisualAnchor`). Shrink it to 132 to make room for the trail.

**Motion spec** (t=0 at tap-up; input re-enabled at 450 ms):

| t (ms) | What | Spec |
|---|---|---|
| −90→0 | Button press | scale 1→0.97 (`tap`), release with `settle` |
| 0 | **Commit state now** (`completeCurrentStep()` runs immediately, the animation plays on top). Today it waits 400 ms before committing (`routine_player_screen.dart:404-421`) | — |
| 0 | Haptic | `HapticFeedback.lightImpact()` |
| 0→240 | Check stroke draws inside the ring | `CustomPainter` + `PathMetric.extractPath(0, len*t)`, stroke 5, round caps, `done`, `Curves.easeOutCubic`. The ring border lerps to `done` and the fill to `doneContainer` |
| 120→270 | Time chip "08:02" fades in and rises 6 px | `quick`, `enter` |
| 240 | Sound (if on) plus a second haptic | stone tap; `HapticFeedback.selectionClick()` |
| 300→700 | The completed step (instruction + chip) moves to the trail slot: translate to the trail's position, scale to 0.47 (32 → 15 pt), cross-fade into the trail row | `settle` spring via `controller.animateWith(SpringSimulation(...))` |
| 380→630 | Next instruction enters from y+16, opacity 0→1; ring resets (border back to idle, check fades out) | `standard`, `enter` |
| 450 | Button re-enabled | — |

- **Fast tappers:** if they tap again before 700 ms, jump the running
  animation to its end (`controller.value = 1`) and start the next one. Never
  queue.
- **Skip:** no stroke and no haptic. The step slides to the trail with a
  hollow ring icon and "Skipped" in place of the time. The run stays honest.
- **Reduce Motion:** a check icon appears at full opacity, the step
  cross-fades into the trail over 120 ms, and haptics play.
- **Defaults:** turn **"Buzz on step complete" on by default** for new
  installs. Write `stepCompleteHaptic=true` when onboarding finishes, so
  existing users' choices are untouched. Keep sound off by default, and offer
  it in onboarding (Moment 5).
- **Copy:** button "Complete step" (keep). Chip "08:02". Trail overflow "+3
  done". Accessibility announcement after each check: "Hair tools unplugged,
  checked at 8:02." (`SemanticsService.announce`).

**Flutter approach:**

1. In `_RoutineStepSurface` (`routine_player_screen.dart:952`), wrap the
   instruction block in a widget keyed by step index.
2. Add `_StepTrail` (a `Column` of rows, driven by a `List<CompletedStep>`
   already derivable from session state).
3. Use a `GlobalKey` on the trail's next slot to read its position for the
   fly-up (`RenderBox.localToGlobal`). This is a simple manual "Hero" inside
   one screen, done with an `OverlayEntry` or a `Stack` layer. If you want
   less risk, ship v1 with a cross-fade into the trail plus a
   `SizeTransition` of the trail, and add the fly-up in v2.
4. `AnimatedVisualAnchor` keeps its API (`playCompletion()`) but changes to
   the path-drawn check and no longer blocks the commit.
5. Tests in `test/features/routines/execution/` look for text, not timing.
   Update any that `pump` an exact 400 ms.

---

### Moment 2: Completion ("the cairn and the time"). Impact: very high. Effort: M

**What the user sees and feels:** the screen goes quiet and one pebble per
step drops onto a small cairn in the centre. Each one lands with a soft tap
you can feel, and the last one settles with a firmer one. Then the time
appears, huge: **08:04**. Under it: "Leaving the house · Fri 3 Oct". Below
that is a calm receipt: "5 of 5 steps", a strip of the photos taken this run,
and "Saved on this device". There is one button, **Done**. It is the
screenshot people will share, and it is something they can look back at
later.

**Layout** (replaces `RoutineCompleteScreen`, `routine_player_screen.dart:1962`):

- **Cairn:** 120×120 `CustomPainter`. N stacked pebbles (soft ovals; widths
  shrink up the stack from 76 to 44; colours alternate `done`,
  `done @ 70%`, `categoryAccents`). Cap the visual at 5 pebbles: for more
  steps, the bottom pebble carries a small "×N" count. Skipped steps are drawn
  as outline-only pebbles, so the record stays honest. **The cairn echoes the
  app icon** (`assets/icon/app_icon_full.png`), which ties the brand together.
- Overline `ALL CHECKED` in `done`, or `4 OF 5 CHECKED` when steps were
  skipped.
- Time: `displayXL` (DM Serif 56, use 64 if it fits), `textPrimary`.
- Subline: `body` "Leaving the house · Fri 3 Oct".
- **Receipt card** (Card style, r24): row "Steps · 5 of 5"; row "Photos" with
  up to 4 48×48 r8 thumbnails (tap opens the existing
  `PebblePhotoGalleryViewer`), shown only when the routine has photo steps;
  row "Saved on this device" or "Backed up" (the true state, using copy from
  `COPY_GUIDELINES.md`).
- **Buttons:** Primary **Done** (goes to Home, which then shows Moment 3).
  Tertiary "See details" (replaces "Review routine"; opens the run detail).

**Motion spec:**

| t (ms) | What | Spec |
|---|---|---|
| 0→300 | Route transition from the player: fade-through (out 90, in 210) | `quick`/`standard` |
| 200 + i·110 | Pebble *i* falls from y−48, opacity 0→1 | `land` spring; `HapticFeedback.selectionClick()` per pebble (max 5) |
| last + 160 | Final settle: the whole cairn compresses 2% and returns | `settle`; `HapticFeedback.mediumImpact()`; `routine_complete.wav` if sound on |
| +120 | Overline + time fade/rise 12 px | `emphasized`, `emphasizedCurve` |
| +240 | Receipt card rises 16 px | `standard` |
| +360 | Button fades in | `quick` |

- Total is about 1.3 s for 5 steps. The button is tappable from 0 ms (an
  invisible tap still works), so nobody is trapped.
- **Reduce Motion:** everything renders in its final state, with one
  `mediumImpact`.
- **Copy:** "All checked." / "4 of 5 checked." / "Done" / "See details".
  Avoid "Great job", "You're all set", "You're safe".
- **Tests:** `routine_player_guidance_audio_test.dart:168,190,198` find
  "Routine complete" and "Back to Home". Keep "Routine complete" as the
  `Semantics` label of the header and update the button finder to "Done".

**Flutter approach:** a single `AnimationController` (about 1300 ms) with
`Interval`s, like the existing `_StaggeredEntrance`, plus one
`AnimationController.unbounded` per pebble driven by
`SpringSimulation(PebbleMotion.land, -48, 0, 0)`. Fire haptics from a
`Timer` list scheduled on start, cancelled in `dispose`. The thumbnails come
from session proof assets, which the player already holds
(`playerState.proofAssets`).

---

### Moment 3: Home "Checked" state. Impact: high. Effort: S–M

**What the user sees:** after a run, Home doesn't just offer **Start** again.
The hero becomes a soft `doneContainer` card: a small cairn glyph, the
overline "CHECKED", the time **08:04** in DM Serif 56, "Leaving the house ·
all 5 steps", and a row of photo thumbnails. The person at the bus stop opens
the app and the answer is the first thing they see, which is the exact scene
of TikTok concept #2. A tonal **Run again** sits below it. The hero reverts to
the normal "Your next ripple / Start" state after a cut-off.

- **Rule:** show Checked when the hero routine's latest *completed* run ended
  today and less than 6 hours ago. Keep it a constant for now; if people ask,
  it becomes a setting later. If the run had skips: "CHECKED · 1 skipped".
- **Motion:** when you return from completion, the card cross-fades in over
  250 ms. If Moment 2 is in, the cairn glyph is the same widget at 40 px,
  which reads as continuity. Use a real `Hero` with tag
  `cairn-${routineId}`. No idle animation.
- **Copy:** "Checked" / "08:04" / "Leaving the house · all 5 steps" / "Run
  again". Not "You're good to go". That is emotional reassurance, which
  `COPY_GUIDELINES.md` rules out.
- **Android widget** (`home_widget` already in pubspec): mirror the same
  state, "Leaving the house · Checked 08:04", so the answer is one glance away
  without opening the app. (No iOS widget exists yet; see
  `VISUAL_WALKTHROUGH.md` item 7.)
- **Flutter approach:** a computed `heroState` provider (`ready | inProgress |
  checked`) from the existing last-run data that already powers "Last
  completed 3h ago" (`routine_list_screen.dart:2264`). Use one
  `AnimatedSwitcher` between the three hero layouts.

---

### Moment 4: Photo step, camera-first, with a "develop" moment. Impact: high (the TikTok crowd). Effort: M

**What the user sees:** on a photo step, the empty ring is replaced by a
large 4:3 **photo frame** (r24, dashed 1.5 px `action @ 40%`, camera icon 28
+ "Take a photo"), with "Choose from library" as a tertiary link under it.
After the shot comes back from the camera, the photo **develops** into the
frame: it starts slightly desaturated and soft, then over 600 ms the
saturation and sharpness come up, and a small time chip "08:02" stamps into
the bottom-left corner of the frame (displayed only, never burned into the
file). A light haptic plays on the stamp. **Complete step** lights up. One
good photo with the time on it replaces 40 near-identical camera-roll shots,
which is the whole marketing pitch shown in one moment.

- **Today** (`iphone__player_photo_step.png`): an 80×80 "Add" tile inside a
  form card titled "Proof photo / Required to complete this step", with the
  big empty space left unused.
- **Multiple photos (Premium "up to 4"):** after the first, the frame shows
  the latest photo, with a strip of 56×56 r8 thumbnails plus a dashed "+"
  tile beneath. The locked "Add more" tile for free users stays as it is
  (`iphone__player_photo_step_free.png`), restyled to the r8 tile.
- **Motion:** photo fade 0→1 over 150 ms; `ColorFiltered` saturation matrix
  0.2→1 and `ImageFiltered` blur σ 6→0 over 600 ms (`enter`); chip scale
  0.9→1 with `settle` at 450 ms plus `HapticFeedback.lightImpact()`. Reduce
  Motion: show the photo and chip at once.
- **Copy:** "Take a photo" / "Choose from library" / chip "08:02" / helper
  only if required and empty: "Photo required for this step." Don't use "Proof
  photo" as the card title; it is the feature name, not a heading (Copy
  Guidelines: use "photo" in daily UI).
- **Flutter approach:** keep `image_picker`. Change only the layout and the
  post-capture animation in `_PlayerPhotoSummary`
  (`routine_player_screen.dart:1469`). **Later (L):** an in-app camera with
  the `camera` plugin, so the shutter, the develop and the stamp happen inside
  Pebble without the jump to the system camera. That is better for screen
  recordings, but it needs its own permissions, lifecycle and QA pass.

---

### Moment 5: First-run, "watch it check itself". Impact: medium. Effort: S

The possibilities card (`iphone__onboarding_possibilities.png`) already has
an entrance animation and a pulse (`onboarding_screen.dart:760-790`). Make it
**play the check-off from Moment 1 by itself, once**:

- About 1.2 s after it appears, "Front door locked" draws its check (same
  painter as the player), stamps "08:02", and moves into the done list. The
  progress label goes "3 of 5" → "4 of 5".
- It plays a single `selectionClick`, and only if the user has already
  touched the screen (never buzz unprompted).
- Then a small toggle row appears below the card: "Play a soft sound when
  you check a step" (off by default). Turning it on plays the stone tap
  immediately. This is where sound gets opted into.
- **Fix the outliers while there:** onboarding page 2's 2×2 theme grid is
  clipped at the bottom on a 390×844 screen (`iphone__onboarding_2_theme.png`).
  Reduce the card height to fit (about 200). Page 3 starter descriptions
  should wrap to 2 lines instead of "…"
  (`iphone__onboarding_3_starting_point.png`).

**Reduce Motion:** show the final state ("4 of 5", step checked).

---

## 5. Screen-by-screen polish list (ranked within each screen)

### Home (`iphone__home_populated.png`, `iphone__home_with_resume.png`, `iphone__home_empty.png`)

1. Hero states: ready / in progress / **checked** (Moment 3).
2. Replace the "5 Steps" icon bar with a human meta line in `caption`: "5
   steps · 2 photos · Reminder 8:15 AM". Move the bell, mail and gear
   actions into the existing routine actions sheet
   (`iphone__home_routine_actions_menu.png`). Tapping the meta line opens
   that sheet.
3. Header: wordmark "pebble." plus tagline on **one line** (drop the tagline
   below 375 pt width), then two 44 circle buttons with the same glass style:
   Settings (sliders) and Account (avatar). Backup status becomes an 8 px dot
   on the avatar (green = backed up, amber = paused, none = off). The "Backup
   off / Checking backup" pill goes away, which also removes the tagline
   wrapping (`iphone__home_with_resume.png`).
4. Bottom bar: go from a white bar with shadow and a centre FAB to a
   **floating capsule tab bar** (64 h, inset 16, r32, glass per §3.4) holding
   Home and History, plus a separate 56 circle **"+" in tonal style** on the
   right. Creating a routine is rare and running one is frequent, so "+"
   should not compete with Start (it fixes the Sandstone clash too,
   `iphone__theme_21_sandstone_home.png`). Code: `pebble_navigation.dart`.
5. Resume card (`iphone__home_with_resume.png`): Card style (no
   double-outline plus shadow). The trash icon becomes a tertiary "Discard"
   inside a "…" menu; it is too easy to hit next to Resume. Make the whole
   card the tap target for Resume.
6. Remove the ambient particles painter (§3.4).
7. Empty state (`iphone__home_empty.png`): keep the copy. Add a 3-row ghost
   preview of a routine (the onboarding preview style) above "Create
   routine", so the screen isn't 60% blank.

### Routine player (`iphone__player_step1.png`, `_step2`, `_voice_step`, `_photo_step`)

1. Moment 1 (check-off plus trail).
2. Fix the CTA font (§3.1) and lower the instruction weight to 600.
3. **Stop the CTA jumping** between step 1 and step 2 (the "Previous" row
   collapses). Always reserve the 36 h secondary row
   (`_RoutineStepFooter`, `routine_player_screen.dart:1304`; render an empty
   `SizedBox(height: 36)` when there are no secondary actions).
4. Moment 4 for photo steps.
5. Voice tip card (`iphone__player_voice_step.png`): one row, a 40 tile with
   the speaker, "Voice tip" in `headline`, and a compact tonal "Play" button.
   While playing, the button shows a 3-bar level meter (3 rounded bars
   animated from the `just_audio` position stream, or a simple looping
   animation).
6. Top bar: the back chevron becomes "Close" (×) with the leave sheet. The
   leave sheet itself stays (`iphone__player_leave_prompt.png`); switch its
   buttons to the new set (Primary "Leave and save", Secondary "Stay here",
   Destructive text "Discard progress").

### Completion (`iphone__player_complete.png`)

1. Moment 2. 2. Theme the card (dark themes). 3. Single primary "Done".

### Routine composer (`iphone__composer_edit.png`, `_photo_step_expanded`, `_new`)

1. The voice tip chip uses `secondary`, not red (§3.5).
2. Expanded-row trash: a neutral icon (`fg @ 60%`) in a 40 tile. It turns
   red only in the confirmation. Today a red tile is always visible on the
   step you're editing.
3. Collapsed rows: replace the cryptic hollow radio circles
   (`iphone__composer_edit.png`, right edge) with small labelled glyphs only
   where they apply: camera (photo required), mic (voice tip), and "Optional"
   in `caption` when the step is optional. Required is the default, so it
   needs no mark.
4. Chips: one size (`caption` 13/500, 36 h, capsule), allowed to wrap.
   Selected = tonal fill plus check. Unselected = hairline.
5. Name field: DM Serif `title1` placeholder "Name this routine" (now a light
   sans "Routine name (optional)", `iphone__composer_new.png`).
6. Header: "Done" uses `action` when enabled; when disabled, hide it rather
   than showing a grey "✓ Done".
7. Drop "Add step creates the next one" helper text.

### History list and run detail (`iphone__history_list.png`, `iphone__history_run_detail.png`)

1. Keep the serif times; tighten each row to Card style (§3.4) and remove the
   left accent bar.
2. Progress glyph: 5 mini dots (6 px, gap 4; filled `done`, ring for
   skipped) instead of the "—" dash.
3. Storage status ("Stored on this device") shows once under the title, not
   per row (`iphone__theme_nordicNight_history.png`).
4. Run detail: serif title; a hero time block "08:02 → 08:08 · 6 min";
   stats tiles hide "Photos taken" when the routine has no photo steps (same
   rule as completion's `showPhotoSummary`); step rows put the time on the
   left in DM Serif 20 like the list, the check on the timeline, and photos
   inline as 56 thumbnails.
5. Photo Vault tab: a 3-column grid of r8 thumbnails, each with a time chip;
   group headers by day. (Not captured in the walkthrough. Add it to the
   harness.)

### Reminders (`iphone__reminders_global.png`, `iphone__reminder_editor_sheet.png`)

1. Default to **grouped by routine**, not by day. Today one weekday reminder
   repeats as 5–7 near-identical cards. Each reminder row: the time in DM
   Serif 26 ("8:15"), meridiem small, weekday mini-chips "M T W T F", the
   routine name in `caption`, and a switch.
2. Remove the per-row trash and the ambiguous red trash in the header. Delete
   lives in the edit sheet (the editor already has a delete action at the
   bottom, `iphone__reminder_editor_existing.png`) and as swipe-to-delete with
   undo.
3. "New reminder" FAB: add bottom padding equal to the FAB height + 24 so the
   last card isn't covered.
4. Editor sheet: keep the big time and the summary line (they're good). Make
   the day circles 40 with selected = filled `action`. "Every day" /
   "Weekdays" become compact tonal chips.
5. "Choose a routine" sheet (`iphone__reminder_new_step1.png`): use routine
   icon tiles, not the generic list glyph.

### Templates (`iphone__templates_gallery.png`, `iphone__template_detail.png`)

1. Card style §3.4 (drop fill + border + shadow + left bar).
2. Descriptions wrap to 2 lines and then stop: no mid-word "…" after
   "sto…".
3. Template detail is good. Change only the CTA to Primary capsule, and use
   the photo chips from the composer chip style.

### Paywall (`iphone__paywall.png`, `iphone__paywall_scrolled.png`)

1. Use the theme `action` colour for the CTA and plan selection (§3.5).
2. The pinned footer takes about 48% of the screen on a 390×844 phone. Make
   the plan cards 72 h (from about 115) and set the fine print in `caption`
   12/17 at 4 lines max. Keep all the required items: price, period,
   auto-renew, cancel, Restore, Terms, Privacy.
3. Replace the repeated "FREE x → PREMIUM y" chip pairs with **one compact
   2-column comparison table** (Free | Premium), 6 rows, with check glyphs.
   It's faster to scan and halves the scroll.
4. Hero: add a cropped, real "Checked 08:04" card (Moment 3) beside the
   headline as the visual. It shows what you're buying (longer history,
   backup) without promising feelings.

### Account, Settings, Backup, Sign-in (`iphone__account_hub_*.png`, `iphone__settings.png`, `iphone__cloud_backup_*.png`, `iphone__sign_in.png`)

1. Unified header plus glass back button; fix the Settings scroll overlap
   (`iphone__settings_scrolled.png`).
2. Settings: Lucide outline icons only, grouped-list style, switch colours
   from `action`. Rename "Buzz on step complete" to "Vibrate when you check a
   step" and "Sound on step complete" to "Sound when you check a step". Add a
   "Preview" tap on the sound row.
3. Account: the plan stat tiles ("48h / 2 / 10") stay, but in DM Serif with
   `caption` labels, inside one card rather than three bordered tiles in a
   bordered card.
4. Sign-in: keep the serif hero and the black Apple button (Apple's rule).
   "Continue with Email" becomes Secondary tonal; the back button becomes the
   standard one.
5. Backup: only show ticks for things that have actually happened (already
   flagged in `VISUAL_WALKTHROUGH.md`).

### Themes (`iphone__appearance.png`)

1. Keep the previews. Use the "selected card" style (§3.4) for the active
   theme, instead of the floating check that covers the pill.
2. Live-preview on tap: cross-fade the whole screen's theme over 250 ms with
   `AnimatedTheme`, so choosing a theme feels immediate.

---

## 6. Store screenshots and icon

### Art direction

- **Story order** (the user's journey, which is also the sales argument):
  where am I → check it → photo → record → done before → set up → reminders →
  privacy.
- **Canvas:** iOS 1320×2868 (6.9"); Play 1080×2340. Background is the High
  Noon ivory `#FDFCF5`, with a very soft radial glow of forest at 6% opacity
  behind the device, top-centre. Use **one dark screenshot** (number 6),
  Pebble Dark `#1B1813`, to show the dark themes and the night-time use case.
- **Caption:** DM Serif Display, 104 px on iOS (84 px on Play), colour
  `#2D3A30`, left-aligned, top margin 160 px, side margins 96 px, one line
  (two at most), with **no** sub-caption. One word in each caption may be set
  in italic forest `#4A5D4E`, echoing the welcome screen's italic
  "*reliable*".
- **Device:** a frameless rounded screen (r 120 px at iOS size) with a
  0 40 80 rgba(0,0,0,.10) shadow, about 82% of the canvas width, starting
  about 40% down so the caption breathes. Don't use a photoreal phone frame;
  frames date screenshots quickly.
- **The "08:02" callout:** on shots 1, 3 and 4, lift the key time chip out
  of the screen as a 1.6× enlarged floating card that overlaps the device edge
  (soft shadow, r24). It is the single most persuasive detail.
- **Data:** sample routines only; one staged straighteners-on-heat-mat photo
  taken in your own home (no addresses, plates or faces, per
  `GOOGLE_PLAY_LISTING.md`). Use 08:02 everywhere, consistent with the
  marketing hooks.
- **Production:** render the app screens with the existing walkthrough
  harness (`test/walkthrough/`) at the store sizes, with seeded sample data,
  then compose them in Figma or a small PIL script with a fixed template.
  That way screenshots are re-generated, not hand-made, after each release.

| # | Caption (from `GOOGLE_PLAY_LISTING.md`) | Screen | Callout |
|---|---|---|---|
| 1 | Did I lock the door? Check it here. | Home in the **Checked** state (Moment 3): "Leaving the house · Checked 08:02" | "08:02" chip |
| 2 | Your leaving-home checks, step by step | Player on "Front door locked" with the trail above it (2 checked steps with times) | — |
| 3 | Straighteners off? Take a photo. | Photo step just after the "develop", stamped 08:02 | photo with "08:02" chip |
| 4 | See what you checked, and when | History list, today, serif times | "Front door locked · 08:02" row |
| 5 | Start from a ready-made routine | Templates gallery (departure, bedtime, car, hotel, trip) | — |
| 6 | A reminder at the time you leave | Reminders grouped by routine, "8:00 · M T W T F" (**dark theme**) | — |
| 7 | Start a routine from your home screen (Play) / Record a voice prompt for any step (iOS) | Android home screen with widget in Checked state / composer voice recorder | — |
| 8 | No account needed. No ads. | Completion screen (Moment 2): cairn + time + "Saved on this device" | — |

Shot 8 deliberately ends on the cairn: it's the most beautiful screen, and
"Saved on this device" makes the privacy point visually.

### Icon

The cairn on forest (`assets/icon/app_icon_full.png`) is right. Keep it.
Refine it for iOS 26:

1. **Rebuild it as a layered icon in Icon Composer**: three pebble layers
   over a `#2C4434` background, so iOS 26 can apply the Liquid Glass specular
   edge. Supply the **dark** and **tinted** variants. Dark: pebbles on
   `#14211A`. Tinted: the pebbles as a single luminance layer.
2. Shift the top pebble from olive-yellow to the app's sage-tan
   (about `#C9C59A` → `#CBD3B0`) so the three tones read as one family. Add a
   very subtle top-light gradient (+4% lightness) on each pebble for depth,
   not gloss.
3. Android: keep the adaptive foreground as it is. Add a **monochrome** layer
   for Android 13+ themed icons.
4. The feature graphic (`assets/icon/feature-graphic-1024x500.png`) uses a
   different serif from the app. Re-set "pebble." and the headline in DM
   Serif Display so the store, the icon and the app match.

---

## 7. Implementation plan

Each batch is a separate PR. It must be testable on its own, should rerun the
walkthrough capture for a before/after comparison, and must pass
`flutter test` (including `sandstone_theme_golden_test.dart`; regenerate that
golden deliberately where a batch changes Sandstone visuals).

| # | Batch | Effort | Contents | Risk / how to test |
|---|---|---|---|---|
| 1 | **Fonts** | S | Bundle DM Sans (400/500/600, with italic 400 for the tagline) + DM Serif Display TTFs; `allowRuntimeFetching = false`; fix the 14 `textStyle: const TextStyle(...)` button overrides to inherit family; swap `GoogleFonts.outfit` → `GoogleFonts.dmSans` (80 sites) | Low. DM Sans is slightly wider than Outfit, so check the a11y 2.0× captures and `small__` captures for overflow (`_layout_errors.txt` should not grow) |
| 2 | **Tokens** | S | `PebbleSpacing` (+sm, lg), `PebbleRadius`, `PebbleType` (text styles from §3.1 built from the theme), `PebbleMotion`, `done`/`doneContainer` in `PebbleThemeX` with defaults | None visually. Unit-test contrast of `done` for every `ThemeId` using `readable_colors.dart` |
| 3 | **Colour leaks** | S | Completion card theming; `Colors.green` → `done`; paywall saturation boost removed; voice-tip tone → secondary; switch colours; `elasticOut` → `settle`/`enter` | Low. Check dark-theme captures of player and completion; add `iphone__theme_nordicNight_complete` to the harness |
| 4 | **Buttons** | M | `PebbleButton` set; migrate player, completion, Home Start, onboarding, the leave sheet, the limit/upsell sheets, the paywall CTA. Sentence case on all labels | Medium (many files). Migrate per feature folder in sub-PRs; tests find by text, so keep labels except the documented ones |
| 5 | **Chrome** | M | One `PebbleBackButton` (44 circle, glass); unified sub-page header (serif `title1`, no divider); fix Settings overlap; Lucide-only icons in Settings / account / completion | Low–medium. Watch `reserveBackButtonSpace` users |
| 6 | **Step check-off** (Moment 1) | M | Commit-first ordering; path-drawn check; time chip; trail; reserved footer row; haptic default on for new installs; re-cut chime; ambient audio session | Medium. Widget tests for: double-tap speed, skip path, Reduce Motion path, the semantics announcement. Test on a real device for haptic feel |
| 7 | **Completion** (Moment 2) | M | Cairn painter, receipt card, `routine_complete.wav`, "Done" | Low–medium. Update the 3 test finders noted above |
| 8 | **Home** (Moment 3 + clean-up) | M | `heroState` provider; Checked card; meta line replacing the icon bar; header simplification + avatar backup dot; remove particles; resume card restyle | Medium. Home is the most-viewed screen; capture all `home_*` variants and the a11y ones |
| 9 | **Photo step** (Moment 4) | M | Camera-first frame, develop + stamp, thumbnail strip | Medium. Test camera-cancel, lost-data recovery (`_recoverLostCameraPhoto` path), free/locked tile |
| 10 | **Floating tab bar** | M | Capsule glass bar + separate tonal "+" in `pebble_navigation.dart` | Medium. Check large text (the bar must grow, not clip), small Android, and the routines sheet peek height |
| 11 | **Screen polish** | M | History rows/detail, Reminders grouping + delete model, Composer chips/rows, Templates cards, Paywall footer + comparison table, Account tiles | Ship one screen per PR |
| 12 | **Onboarding** (Moment 5) | S | Self-playing check, sound opt-in row, theme grid fit, 2-line descriptions | Low |
| 13 | **Store assets** | S–M (design) | Screenshot template + harness sizes; layered icon; feature graphic re-set | Outside the app binary |
| later | Optional | L | In-app camera (`camera` plugin); iOS widget; "Hold to check" option (press-and-hold fills the ring over 600 ms with rising haptic ticks, opt-in; test with users before shipping) | Larger QA surface; do after launch |

**Order rationale:** 1–3 are invisible-to-small fixes that make every later
screenshot correct. 4–5 give one consistent component language. 6–8 are the
wow, built on that language. 9–12 are polish. Don't start 6 before 2, because
the moments depend on `PebbleMotion` and `done`.

### What NOT to change

- The palette identity: High Noon ivory/forest, Sandstone sand/forest/
  terracotta, the warm dark, High Contrast yellow. Refine the roles, keep the
  hues.
- DM Serif as the display voice, and the welcome headline with the
  struck-through "habit tracker".
- The one-step-at-a-time player structure and the top progress bar.
- History's serif-time timeline layout.
- The leave-routine sheet's three choices and copy; the delete-account sheet;
  the reminder editor's summary sentence; the template detail layout.
- Theme picker mini-previews.
- Local-first, matter-of-fact copy. Don't let any of the new moments drift
  into reassurance language. The moments do the emotional work; the words
  stay factual.
- `ensureContrast` / `readable_colors.dart`: keep routing secondary text
  through it.
- No confetti, no streaks, no badges, no mascots. Pebble's onboarding
  literally says "Not goals. Not streaks."

---

## Sources consulted for current platform direction

- Flutter and iOS 26 Liquid Glass status (Cupertino not yet updated; DIY with
  `BackdropFilter`, or native packages):
  [The Flutter Kit: Liquid Glass guide](https://theflutterk.it.com/blog/flutter-liquid-glass-ios-26-cupertino-guide),
  [liquid_glass_native](https://pub.dev/packages/liquid_glass_native)
- Material 3 Expressive spring motion tokens (spatial vs effects springs) in
  Flutter packages, used only as reference for the spring values above:
  [material_3_expressive](https://pub.dev/documentation/material_3_expressive/1.0.8/),
  [expressive_m3](https://pub.dev/packages/expressive_m3),
  [motor](https://pub.dev/packages/motor)

No new packages are recommended. All of the above is achievable with
Flutter's own `SpringSimulation`, `BackdropFilter` and `CustomPainter`.
