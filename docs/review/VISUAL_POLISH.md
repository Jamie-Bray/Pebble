# Visual polish review

Date: 4 October 2026. Branch: `fix/visual-polish` (PR #8).

Every screen was rendered with the screenshot harness and looked at, before
and after. Part 1 lists what was fixed. Part 2 lists design proposals that are
**not** applied; three of them have mock screenshots.

## Checks

| Check | Before (base branch, with the new copy) | After |
|---|---|---|
| Screenshot harness | 120 of 120 scenarios, 235 screenshots | 120 of 120, 235 screenshots |
| Layout warnings (`_layout_errors.txt`) | 19, all on the reminders screens | 0 |
| `flutter analyze` | n/a | No issues found |
| `flutter test` | n/a | 389 passed; 1 failed, the known local-only Sandstone golden |

The Sandstone golden was failing locally before this work (it passes in CI)
and it draws its own boxes, not the app's buttons, so these changes should not
affect it. CI will confirm.

**The two "home checked" failures from the first run:** they were
load-related. They only appeared in the one run that overlapped with other
agents using the harness. Run alone, the scenario passed, and three later full
runs on this branch all passed 120 of 120. The error text from the failing run
was not kept (that run's log was not saved), so the exact assertion is
unknown.

## Fixed

Before/after images are in `docs/review/beauty/polish/`.

1. **Reminders: layout warnings and alignment.** The reminder cards were the
   source of all 19 warnings (taps on a card drew no visible ripple). The
   cards are now a proper tappable surface. The list also had a different left
   edge (16) from the page title (24); both now use 24, and the day headings
   use the standard heading style.
   `lib/features/routines/list/ui/routine_reminders_screen.dart:2029, 2053, 2077, 2094`.
   [before](beauty/polish/iphone__reminders_global_before.png) /
   [after](beauty/polish/iphone__reminders_global_after.png);
   sheet over it:
   [before](beauty/polish/iphone__reminder_editor_existing_before.png) /
   [after](beauty/polish/iphone__reminder_editor_existing_after.png)
2. **All main buttons are now capsules.** 30 buttons across 12 files were
   still rounded rectangles (five different corner sizes: 10, 14, 15, 16, 18).
   They now match Start, Done and Complete step. Affected: Your account,
   Backup, sign-in sheet, reminder editor, Reorder steps, Style Studio,
   composer "Add next step", Themes, paywall and its sheets, history, and the
   theme's default button shape (`lib/core/theme/colors.dart:187-203`).
   [account before](beauty/polish/iphone__account_hub_premiumEnded_scrolled_before.png) /
   [after](beauty/polish/iphone__account_hub_premiumEnded_scrolled_after.png);
   [composer before](beauty/polish/iphone__composer_edit_before.png) /
   [after](beauty/polish/iphone__composer_edit_after.png);
   [Style Studio before](beauty/polish/iphone__home_style_studio_premium_before.png) /
   [after](beauty/polish/iphone__home_style_studio_premium_after.png);
   [purchase sheet before](beauty/polish/iphone__sub_purchase_success_signed_out_before.png) /
   [after](beauty/polish/iphone__sub_purchase_success_signed_out_after.png)
3. **In-page headlines use the serif.** Three were in the heavy plain font
   while their siblings ("Backup is off", "Free plan") used the serif:
   - history run detail title, `lib/features/history/ui/routine_run_detail_screen.dart:129`
     ([before](beauty/polish/iphone__history_run_detail_before.png) /
     [after](beauty/polish/iphone__history_run_detail_after.png))
   - About Pebble tab headings, `lib/features/settings/ui/legal_about_screen.dart:228`
     ([before](beauty/polish/iphone__legal_about_before.png) /
     [after](beauty/polish/iphone__legal_about_after.png))
   - a routine's reminders heading, `routine_reminders_screen.dart:258`
     ([before](beauty/polish/iphone__routine_reminders_from_home_before.png) /
     [after](beauty/polish/iphone__routine_reminders_from_home_after.png))
4. **"Your routines" on Home no longer changes font.** It was plain when the
   sheet was closed and serif when open; it is serif in both.
   `lib/features/routines/list/ui/routine_list_screen.dart:827`.
   [before](beauty/polish/iphone__home_populated_before.png) /
   [after](beauty/polish/iphone__home_populated_after.png)
5. **Three short main buttons are now full height (56).** "Send code"
   (`lib/features/auth/ui/email_otp_sheet.dart:101`), "Send invite"
   (`routine_reminders_screen.dart:1603`) and "Add this template"
   (`lib/features/templates/ui/template_detail_screen.dart:183`) were about 40
   high.
   [sign-in before](beauty/polish/iphone__sign_in_email_sheet_before.png) /
   [after](beauty/polish/iphone__sign_in_email_sheet_after.png);
   [template before](beauty/polish/iphone__template_detail_before.png) /
   [after](beauty/polish/iphone__template_detail_after.png)

### Found but left alone

- Composer chips: "Require photo" is smaller text than "Required" and "Voice
  tip". Fixing it properly means letting the row wrap, which is a layout
  change, not a touch-up.
- Paywall: the line above the price cards cuts the first benefit card in half.
  The accessibility agent is working in that footer, so I left it.
- Red bin tile on the step being edited in the composer, and the red "clear
  all" bin in the Reminders header. Colour-role questions; belongs with the
  accessibility/contrast work.
- Dark themes: the bottom bar has a visible light line along its top edge.
  Needs a decision on the floating tab bar (design batch 10) first.
- The Apple sign-in button shows white blocks in screenshots. That is the
  test harness lacking Apple's font, not an app defect.

## Proposals (not applied)

Ranked by impact for effort. "Current" and "mock" images are in
`docs/review/beauty/proposals/`. The mock code was reverted and is not in any
commit.

**Update:** proposals 1 to 3 are now applied (branch `feat/art-direction`).
Before and after captures for iPhone light, Pebble Dark, the small phone and
1.6x text are in `docs/review/beauty/art-direction/`. Proposals 4 to 6 are
still open.

1. **Completion: make the time and the cairn the picture.** *Mocked.*
   Weak now: the time is the hero of the whole app, but at 64 it is only a
   little bigger than a page title, and the cairn (120) reads as an icon.
   Change: time to DM Serif 88 (line height 1, same `displayXL` style), cairn
   to 168. Two numbers in `routine_complete_screen.dart`. The screen now reads
   from across a room and is the obvious last store screenshot. To check
   before applying: 2x text size and the small phone (the time is already
   inside a shrink-to-fit box, so it should hold).
   [current](beauty/proposals/iphone__player_complete_current.png) /
   [mock](beauty/proposals/iphone__player_complete_mock.png);
   dark: [current](beauty/proposals/iphone__theme_nordicNight_complete_current.png) /
   [mock](beauty/proposals/iphone__theme_nordicNight_complete_mock.png)
2. **Player step: set the instruction in the serif.** *Mocked.*
   Weak now: the most-used screen is the only hero screen with no serif, so it
   looks like a different app from Home and Completion. Change: the step
   instruction from DM Sans 32/600 to DM Serif 38/42 (one style in
   `routine_player_screen.dart:515`, or change the `step` token itself in
   `tokens.dart`). Everything else stays. Risk: long instructions wrap one
   line sooner; cap at three lines.
   [current](beauty/proposals/iphone__player_step1_current.png) /
   [mock](beauty/proposals/iphone__player_step1_mock.png);
   with the trail: [current](beauty/proposals/iphone__player_trail_current.png) /
   [mock](beauty/proposals/iphone__player_trail_mock.png)
3. **Onboarding welcome: lead with the brand mark.** *Mocked.*
   Weak now: the first thing a new user sees is the word "Pebble" in tiny
   spaced capitals, which could be any app. Change: replace it with the cairn
   (44) beside the italic serif "pebble." wordmark (26) already used on Home,
   keeping the two hairlines. One widget in `onboarding_screen.dart`
   (`_WelcomeWordmark`). Caveat seen in the mock: on the small phone it pushes
   the sub-headline down by about 30, so tighten the gap under the page dots
   from 24 to 12 when applying.
   [current](beauty/proposals/iphone__onboarding_1_welcome_current.png) /
   [mock](beauty/proposals/iphone__onboarding_1_welcome_mock.png)
4. **Home: fill the empty middle and promote the record.** Not mocked.
   Weak now: about 150 of blank space between "Last completed 7h ago" (13,
   grey, the smallest text on the screen) and the routines sheet. Change: set
   "Last completed" as a two-part line, the time in DM Serif `title2` (26) and
   "5 of 5 steps" in `body` (15), left-aligned under Start with 24 above. Add
   a large cairn (220 wide, the theme's `done` colour at 6 to 8% opacity)
   bottom-right behind the content as a watermark. No new colours.
5. **Paywall: one clean first screen.** Not mocked (the accessibility agent
   is changing the footer). Weak now: the hard line above the prices slices
   the first benefit card mid-sentence. Change: replace the line with a 32
   high fade from the page colour; move the "WHAT PREMIUM GIVES YOU" label
   below the fold by adding 24 above it; show the selected plan with the
   1.5 px action-colour border from the design system instead of a slightly
   darker fill; prices stay in DM Serif `title2`.
6. **History: let the times carry the page.** Not mocked. Weak now: every row
   has a left accent bar, a dash glyph and a "Stored on this device" pill, so
   the serif times compete with three other marks. Change: remove the bar and
   the per-row pill, show storage once under the title in `caption`, and widen
   the time column so the time can go from 22 to `title2` (26).
