# Visual polish review

Date: 4 October 2026. Branch: `fix/visual-polish`.

**Status: stopped early (usage limit).** Every screen was rendered and looked
at, and the findings are written up below. **No code was changed**, no
before/after pairs were saved, and no proposal mocks were made. Nothing here
has been fixed yet; this file is the to-do list for the next session.

Baseline run of the screenshot harness (before any change):

- 233 screenshots captured.
- 118 scenarios passed, 2 failed in the full run: `home checked highNoon
  iphone 1.0` and `2.0`. The 1.0 scenario passed when run on its own, so this
  looks like a flaky test, not a broken screen. Not investigated further.
- `_layout_errors.txt`: 19 warnings across 4 screens, all the same one
  ("ListTile background color or ink splashes may be invisible") on
  `reminders_global`, `reminders_global_scrolled`, `reminder_new_step1` and
  `reminder_editor_existing`.

Update, second session (also stopped by a usage limit): the branch now has
`origin/review/gemini-handover-assessment` merged in (real sample photos for
the harness). Still no code changes, no fixes, no mocks. The two "home
checked" failures were not re-run alone yet, so whether they are load-related
or a real flake is still unknown. The reminders warnings come from the
`ListTile`s at `lib/features/routines/list/ui/routine_reminders_screen.dart`
lines 2103, 2233 and 2240; that is the first fix to make.

`flutter analyze` and the full `flutter test` were not run in this session.

## Fixed

Nothing yet. The defects below were found and are ready to fix, in rough
order of how visible they are.

1. **Main buttons are not all the same shape.** The design system says every
   main button is a capsule (fully rounded). These are still rounded
   rectangles: "Renew Premium", "Get Premium", "Manage subscription", "Sign
   in" and "Sign out" on Your account; "Get Premium" on Backup; "Delete
   account" and "Cancel" on the delete sheet; "Update reminder" / "Save
   reminder"; "Save changes" on Reorder steps; "Save style" in Style Studio;
   "Add next step" in the composer; "Upgrade for voice tips"; "Add someone to
   notify" on Email; "Sign in to back up" on the purchase-success sheet. Fix:
   switch each to the existing `PebbleButton` set (or `PebbleRadius.pill`).
2. **Three in-page headlines are in the plain font instead of the serif.**
   "Morning reset." on the history run detail, "Reminder rhythm." on a
   routine's reminders, and "Privacy, without the fog." / "Deleting your
   account." / "Using Pebble fairly." on About Pebble. Sibling screens
   ("Backup is off", "Free plan", "Premium has ended.") use the serif. Fix:
   use the serif `title2` style.
3. **"Your Routines" changes font.** Plain font when the sheet is collapsed
   on Home, serif when it is open. Already listed in `DESIGN_DIRECTION.md`
   section 3.8 and still present. Fix: serif in both.
4. **Reminders screen is misaligned and has the layout warnings.** The title
   sits 28 from the left edge, but the day headings and cards sit at 20, so
   the page has two left edges. The reminder cards are also the source of all
   19 layout warnings (a `ListTile` inside a coloured box). Fix: one gutter,
   and wrap the tile in a transparent `Material`.
5. **Two short main buttons.** "Send code" (email sign-in sheet), "Send
   invite" (email invite sheet) and "Add this template" are about 40 high;
   every other main button is 56.
6. **Composer chips are different sizes.** "Require photo" is visibly smaller
   text than "Required" and "Voice tip" beside it (also still open from
   section 3.8).
7. **Voice tip sheet uses the error red** for its icon tile, and the composer
   shows a red bin tile on the step being edited. Red should mean "delete"
   only at the moment of confirming.
8. **Large text, onboarding theme page.** At 2x text the line "You can change
   this any time in settings." has its lines squashed together, unlike the
   same kind of line on the next page.
9. **Dark themes: bright line above the bottom bar.** On the dark themes the
   bottom navigation bar has a light hairline along its top edge that is much
   more noticeable than on light themes. Needs a look at full size before
   changing.
10. **Paywall, pinned footer.** The divider above the price cards cuts through
    the first benefit card mid-sentence ("...not just two of them."), on both
    light and dark. Looks unfinished in the first screenshot.

Not a defect: the Apple sign-in button shows white blocks instead of text in
the screenshots. That is the test harness lacking Apple's font, not the app.

## Proposals

Not mocked. Ranked by impact for effort; each is a small change.

1. **Completion screen: make the time bigger and the cairn the brand mark.**
   The time is the hero but the screen is half empty below the receipt card.
   Use the `displayXL` serif at 64 for the time, grow the cairn from about
   120 to 160, and move the group down so it sits at the optical centre
   between the top and the receipt card. Best candidate for the last store
   screenshot.
2. **Home: fill the empty middle.** Between "Last completed 7h ago" and the
   routines sheet there is about 150 of nothing. Put a faint, large cairn
   (theme `done` colour at 6 to 8% opacity, about 220 wide) low-right behind
   the content, and promote "Last completed" from 13 grey to `body` 15 with
   the time in serif. The header tagline is clipped at large text sizes, so
   drop it when text scale is above 1.3.
3. **Paywall: one clear first screen.** Hide the benefit list behind the
   pinned footer cleanly (soft fade instead of a hard line), drop the
   "WHAT PREMIUM GIVES YOU" overline from the first view, and set the two
   prices in serif `title2` with the selected card using the 1.5 px action
   border from the design system.
4. **Player step: serif for the instruction.** "Stove and oven dials off" in
   DM Serif Display 34/38 instead of DM Sans 600 would tie the most-used
   screen to the brand. Keep everything else. Cheap to mock (one style).
5. **Onboarding welcome: tighten the top.** The "Pebble" wordmark between two
   hairlines is small and generic. Replace it with the cairn mark at 40 above
   the italic "pebble." wordmark used on Home, and give the headline
   `display` 44/46 so it fills the width.
6. **History: drop the left bar and the per-row "Stored on this device"
   pill** (shown on every row in dark and Sandstone themes), and show storage
   once under the title. Makes the serif times the only strong element.
