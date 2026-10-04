# Accessibility and colour contrast audit

Date: 4 October 2026. Branch: `fix/accessibility-pass`.

**Status: audit only, stopped early.** The session ran out of budget before any
fix was made. Nothing in the app's code has changed on this branch. Every
finding below is therefore "Not fixed" or "Needs owner decision". The findings
themselves are ready to act on.

## How this was checked

- **Screenshots.** The screenshot harness was run twice on the unchanged code:
  120 of 120 scenarios passed, 235 screenshots, and `_layout_errors.txt`
  contained no overflow or clipping errors (only a harmless "ListTile ink may
  be invisible" notice on the reminders screens). About 16 of the 235
  screenshots were looked at by eye.
- **Contrast numbers.** Calculated from the real colour values in
  `lib/core/theme/colors.dart` for all 22 themes, using the app's own
  `contrastRatio` helper (`lib/core/ui/readable_colors.dart`). These are
  measured, not judged by eye. The rule (WCAG AA): 4.5:1 for normal text, 3:1
  for large text and icons.
- **Tap targets and screen-reader labels.** Flutter's built-in accessibility
  checks (48x48 tap target, "every tappable thing has a label") were run on
  every screenshot scenario using a temporary, uncommitted hook in the harness.
- **Not checked:** a real phone with TalkBack or VoiceOver; reading order in
  the player, completion, paywall, sign-in and backup screens; whether every
  animation respects "reduce motion". See the last section.

## Findings

### Colour contrast

| # | Finding | Measured | Where | Status |
|---|---|---|---|---|
| C1 | **Main button label is too faint in six themes.** White (or dark) label on the theme's accent colour. | Matcha 3.66, Rose Quartz 3.41, Oatmeal & Walnut 3.82, Parchment 4.00, Soft Pink 4.10, Deep Glacier 4.37 (need 4.5). Reduced Contrast 4.35 is deliberate. All other themes pass (High Noon 7.08, Sandstone 7.26, High Contrast Dark 15.59). | `lib/core/ui/pebble_buttons.dart:149-150`; colours at `lib/core/theme/colors.dart:76` | Not fixed. Suggested small fix: darken the button fill just enough with the existing `ensureContrast` helper. This visibly darkens the button in those themes, so it **needs owner decision**. Soft Pink is a free, main-picker theme. |
| C2 | **"Muted" text colour fails almost everywhere it is used as text.** | On the page: Pebble Dark 1.98, Colour Blind Safe 1.98, Matcha 2.38, Soft Pink 2.51, Sandstone 2.55, High Noon 2.63, Paper & Ink 3.33 (need 4.5). Only High Contrast Dark (5.92) and four dark themes pass. | Token: `colors.dart:275`, `:559`, `:738`, `:763`. Used as text in `pebble_paywall.dart:948, 1468, 1706, 1760, 2233`; `routine_list_screen.dart:1736, 1755, 1835, 1891, 2677, 2695`; `styled_history_screen.dart:794, 797, 1440`; `routine_run_detail_screen.dart:424`; `appearance_screen.dart:292, 750`; `routine_creation_choice_sheet.dart:191`; `routine_card.dart:168, 190` | Not fixed. Fix is to swap these to the existing `readableSecondaryText`. About 20 call sites, each a small visual change, so it was not attempted in the time available. |
| C3 | **Secondary button and small pill labels slightly under on their own tinted fill** in seven light themes. | Warm Sepia 4.05, Soft Pink 4.06, Matcha 4.12, Oatmeal 4.15, Parchment 4.20, Rose Quartz 4.23, Paper & Ink 4.31 (need 4.5) | `pebble_buttons.dart:139, 154-155, 175-176` | Not fixed. Small fix: include the tinted fill in the backgrounds passed to `ensureContrast`. |
| C4 | **Red "delete" button label too faint in two themes** (filled destructive button). | Pebble Dark 3.91, Colour Blind Safe 3.98 (need 4.5) | `colors.dart:83, 266, 550`; `pebble_buttons.dart:165-166` | Not fixed. |
| C5 | **Placeholder text in text boxes** (theme default: text colour at 50%). | Fails in 19 of 22 themes, e.g. Matcha 2.45, Soft Pink 2.59, Sandstone 2.64, High Noon 2.73, Pebble Dark 4.36 | `colors.dart:182-184` | Needs owner decision. One-line theme change, but it affects every text box and possibly the Sandstone golden image test. |
| C6 | **Raw "secondary" text colour used directly** instead of the readable helper. | Matcha 3.74, Soft Pink 4.09, Sandstone 4.19, Oatmeal 4.20, High Noon 4.44 on the page; Pebble Dark 3.83 on raised cards | e.g. `routine_card.dart:145`; `styled_history_screen.dart:850`; `zen_components.dart:28` (not all call sites reviewed) | Not fixed. The helper `readableSecondaryText` already passes in every theme (4.51 to 14.45 on the page). |
| C7 | `readableSecondaryText` only guarantees the page and low cards; on **raised cards in Pebble Dark and Colour Blind Safe** it is just under. | 4.41 (need 4.5) | `readable_colors.dart:54-57` | Not fixed. Adding `surfaceHigh` to the helper's list would fix it. |
| C8 | **Accent colour used directly as small text** fails in several themes where the helper `readableAccentText` is not used. | Rose Quartz 3.05, Oatmeal 3.33, Matcha 3.39, Parchment 3.48, Soft Pink 3.73, Warm Sepia 4.15 | `colors.dart:199` (outlined button text); other direct uses of `cs.primary` as text not listed | Not fixed. Call sites not fully reviewed. |
| C9 | **Sandstone's terracotta "action" colour** as text or behind a label. | Terracotta on page 3.10; cream on terracotta 3.36. Fine for the "+" icon (needs 3.0), not for body text. Step badge tints: sage 2.41, tan 1.86 on the page. | `colors.dart:336-348` | Needs owner decision. Where it is used as text was not checked. |
| C10 | **Text-box and card outlines are nearly invisible** as a boundary. | 1.23 to 1.67 in every theme (guideline for UI boundaries is 3.0) | `colors.dart:87`, `:174-177` | Needs owner decision. This is the app's soft visual style; boxes are also filled. |
| C11 | In the High Contrast Dark composer screenshot, the "STEPS – 4 ADDED" heading, step-number badges 2-4 and "Require photo" look faint. | Seen by eye only; not measured | `routine_composer_screen.dart`, `routine_composer_step_row.dart` | Not verified. |

What passes in every theme: main text on the page (7.39 to 21.0), the "done"
green on the page (4.81 and up; Reduced Contrast 4.35 by design), red error text
on the page (5.29 and up), and `readableSecondaryText` on the page and low
cards.

### Text size

| # | Finding | Evidence | Where | Status |
|---|---|---|---|---|
| T1 | **The app caps text enlargement at 1.6x.** Someone who sets their phone to 2x gets 1.6x. The "2.0x" screenshots are pixel-for-pixel the same layout as the 1.6x ones. | Screenshots compared; code comment says this is deliberate | `lib/main.dart:741-747` | Needs owner decision. Raising it needs a layout pass first. |
| T2 | The Home header (wordmark, tagline) only grows to 1.3x, and the tagline "Small steps, big ripples" fades out under the settings button at large text. | `iphone__a11y1.6x_home_populated.png` | `routine_list_screen.dart:684-735` | Not fixed. Cosmetic: the tagline is decorative and fades by design. |
| T3 | Bottom navigation labels only grow to 1.3x; sub-page headers to 1.5x; button labels to 1.6x. | Code | `app_shell.dart:117`; `pebble_navigation.dart:296`; `pebble_buttons.dart:117` | Needs owner decision (deliberate caps). |
| T4 | No clipped or overlapping text was found in the large-text screenshots viewed (home, home checked, routines sheet, player step, player photo step, paywall top and end, onboarding theme page). | Harness reported zero layout errors across all 235 captures | | Passed, for the screens the harness covers. |

### Tap targets under 48x48

Measured by Flutter's Android tap-target check across all scenarios.

| # | Control | Measured size | Where | Status |
|---|---|---|---|---|
| S1 | Paywall footer links: "Restore purchase", "Terms of Use", "Privacy Policy" | 40 high; 23.8 high in one layout | `pebble_paywall.dart` (footer links, about line 2148-2233) | Not fixed. Layout only, purchase code untouched, but not attempted. |
| S2 | "Back up with Premium" link | 117 x 14 | Account / backup screens (exact line not located) | Not fixed. Smallest target found. |
| S3 | Composer step options: "Require photo", "Required"/"Optional", "Voice tip" | 104 x 36 | `routine_composer_step_row.dart` (about line 374) | Not fixed. |
| S4 | Composer delete-step button | 36 x 36 | `routine_composer_step_row.dart:155-167` | Not fixed. |
| S5 | Composer step-name and routine-name text fields | 36 to 36.6 high | `routine_composer_screen.dart`, `routine_composer_step_row.dart` | Not fixed. |
| S6 | History "Timeline" / "Photo Vault" tabs | 168 x 30 | `styled_history_screen.dart` (about line 889-982) | Not fixed. |
| S7 | Reminder day-of-week circles; "Every day" / "Weekdays" chips | 40 x 40; 37 high | `reminder_editor_sheet.dart:191-317` | Not fixed. |
| S8 | Round glass buttons (back, settings, account, "About themes") and all "tertiary" text buttons ("Skip for now", "Not now", "I'll decide later", "See details", "Back to Home" and similar) | 44 x 44 / 44 high | `pebble_navigation.dart:74`; `pebble_buttons.dart:109` | Needs owner decision. 44 is the documented design size and meets Apple's guideline, but is under Android's 48. |
| S9 | Compact pill buttons | 40 high | `pebble_buttons.dart:110` | Needs owner decision (documented design size). |
| S10 | One unlabelled 24 x 24 control and several unlabelled 40 x 40 controls | 24 x 24; 40 x 40 | Not traced to a file | Not verified. |

### Screen-reader labels

| # | Finding | Where | Status |
|---|---|---|---|
| L1 | **Close button on the history "choose a photo" sheet has no label** (an "X" icon with no tooltip). | `routine_run_detail_screen.dart:294-297` | Not fixed. One-line fix: add `tooltip: 'Close'`. Found by reading the code. |
| L2 | Flutter's "tappable thing without a label" check failed on 25 captures: the Home routines sheet, the composer (all variants), global and per-routine reminders, settings, the style studio, the email contact screen, the pending-purchase screen and the lapsed-routines sheet. | Individual controls not traced | Not verified. The list of screens is measured; which control on each screen is at fault was not worked out. |
| L3 | Photos (`Image.file`) carry no description of their own in the history list, run detail, gallery viewer and player thumbnails. Some are wrapped in a labelled parent (for example "Photo 1 of 3" on the completion screen); the others were not checked. | `pebble_photo_gallery_viewer.dart:267`; `styled_history_screen.dart:1829`; `routine_run_detail_screen.dart:1149`; `routine_player_screen.dart:1988` | Not verified. |
| L4 | Icon buttons that do have labels (checked in code): back, settings, account, search, delete reminder, clear all, show/hide steps, About themes. | | Passed. |

### Reduce motion

| # | Finding | Where | Status |
|---|---|---|---|
| M1 | "Reduce motion" is respected by the button press animation, the routine player, the completion screen, onboarding and the Home hero. | `pebble_buttons.dart:282`; `routine_player_screen.dart:190, 751, 1368, 1432, 1703, 2319`; `routine_complete_screen.dart:151`; `onboarding_screen.dart:718`; `routine_list_screen.dart:2123` | Passed, by reading the code. Not run with the setting on. |
| M2 | Other animations were not reviewed: the animated background, toast notifications, the bounce button, the routine card press, the "show steps" chevron. | `core/ui_kit/animated_background.dart`; `core/ui/zen_notifications.dart`; `core/ui/zen_components.dart:111`; `routine_card.dart:264`; `routine_list_screen.dart:2398` | Not verified. |

## What was not done

- No fixes and no new tests. `flutter analyze` and the full `flutter test` run
  were not run on this branch, because the only change is this document.
- Reading order for screen readers on the player, completion, paywall, sign-in,
  backup and reminders screens was not assessed.
- Only about 16 of the 235 screenshots were viewed. Sign-in, backup, reminders,
  completion, settings, templates and the small-device captures were not viewed
  by eye (they were covered by the automated tap-target and label checks).
- Flutter's automated on-screen contrast check was also run, but its numbers
  are unreliable for thin text, so none of them are quoted here. All contrast
  figures above come from the theme colour values.

## Suggested order for a follow-up

1. L1 (one line), C3, C4 and C7 (small, contained, use existing helpers).
2. C2 and C6 (swap to `readableSecondaryText`, screen by screen, re-running the harness).
3. S1 to S7 (raise tap targets to 48).
4. Owner decisions: C1, C5, C9, C10, T1, S8, S9.
