# Accessibility and colour contrast audit

Date: 4 October 2026. Branch: `fix/accessibility-pass` (PR #10).

This is an audit of every theme and every screen the screenshot harness covers,
plus four small fixes. Each finding is marked **Fixed**, **Not fixed** (with the
reason), **Needs owner decision**, or **Not verified**.

## How this was checked

- **Screenshots.** The screenshot harness renders 120 scenarios into 235
  screenshots. It passed 120 of 120 before and after the fixes, with no
  overflow or clipping errors in `_layout_errors.txt` (only a harmless
  "ListTile ink may be invisible" notice on the reminders screens). About 25
  screenshots were looked at by eye.
- **Contrast numbers.** Calculated from the real colour values in
  `lib/core/theme/colors.dart` for all 22 themes, using the app's own
  `contrastRatio` helper (`lib/core/ui/readable_colors.dart`). The rule
  (WCAG AA): 4.5:1 for normal text, 3:1 for large text and icons.
- **Tap targets and screen-reader labels.** Flutter's built-in checks (48x48
  tap target; "every tappable thing has a name") were run on every screenshot
  scenario, before and after the fixes, using a temporary hook in the harness
  that is not committed.
- **Not checked:** a real phone with TalkBack or VoiceOver, and reading order
  on the player, completion, paywall, sign-in and backup screens.

## What was fixed

### 1. Main button label contrast (Fixed)

The label on the main button (Start, Continue, Complete step) was too faint in
six themes. The button fill is now darkened (lightened in Deep Glacier) only as
far as needed, using the existing `ensureContrast` helper. Themes that already
passed are untouched. Reduced Contrast is left alone on purpose, as
`DESIGN_DIRECTION.md` says not to add contrast there.

Code: `lib/core/ui/readable_colors.dart` (`readableActionFill`),
`lib/core/ui/pebble_buttons.dart:149`. Test: `test/core/ui/pebble_buttons_test.dart`
builds the button in all 22 themes and fails if any drops below 4.5:1.

| Theme | Before | After |
|---|---|---|
| Rose Quartz | 3.41 | 4.65 |
| Matcha | 3.66 | 4.55 |
| Oatmeal & Walnut | 3.82 | 4.56 |
| Parchment | 4.00 | 4.60 |
| Soft Pink | 4.10 | 4.60 |
| Deep Glacier | 4.37 | 4.73 |
| Reduced Contrast | 4.35 | 4.35 (deliberately soft) |
| High Noon | 7.08 | 7.08 |
| Pebble Dark | 6.57 | 6.57 |
| Paper & Ink | 4.88 | 4.88 |
| Amber Resin | 5.59 | 5.59 |
| Terracotta | 4.86 | 4.86 |
| Lavender Ash | 4.86 | 4.86 |
| Graphite | 6.60 | 6.60 |
| Canopy | 4.58 | 4.58 |
| Dusk | 6.74 | 6.74 |
| Still | 7.17 | 7.17 |
| High Contrast Dark | 15.59 | 15.59 |
| Warm Sepia | 5.06 | 5.06 |
| Colour Blind Safe | 6.60 | 6.60 |
| Sage Mist | 4.71 | 4.71 |
| Sandstone | 7.26 | 7.26 |

What you will notice: the main button is a slightly deeper shade in Rose
Quartz, Matcha, Oatmeal & Walnut, Parchment and Soft Pink, and slightly lighter
in Deep Glacier. Other things that use the accent colour (the "+" button, the
progress bar, links) are unchanged.

### 2. Faint "muted" text (Fixed where it was real text)

The "muted" colour is far too faint for reading (1.98 in Pebble Dark and Colour
Blind Safe, 2.38 to 2.80 in the light themes, against a need of 4.5). Fourteen
places that used it for real words now use the existing readable secondary
colour, which measures 4.51 to 14.45 on the page in every theme. The muted
colour itself is unchanged and still used for decorative icons and dividers.

| Where | File |
|---|---|
| Paywall: "You can sign in later...", section headings, "FREE" tier label | `pebble_paywall.dart:948, 1467, 1759` |
| Home routines sheet: routine details line, section headings, action subtitles, "Its history and photos stay in History.", step numbers and step names in the preview | `routine_list_screen.dart:1739, 1757, 1837, 1893, 2679, 2697` |
| History: search box placeholder | `styled_history_screen.dart:803` |
| Run detail: step numbers | `routine_run_detail_screen.dart:425` |
| Appearance: section headings and inactive chips | `appearance_screen.dart:293, 751` |
| Onboarding: ticked-off checklist items | `onboarding_screen.dart:1154` |

Test: `test/features/subscription/pebble_paywall_test.dart` checks the paywall
labels reach 4.5:1 in Pebble Dark. The other call sites use the same helper but
do not each have their own test.

Not changed: `routine_card.dart:168, 190` uses the muted colour for text, but
that widget is not used anywhere in the app.

### 3. Controls with no spoken name (Fixed)

A screen reader announced these only as "button" or "switch". Each now has a
name. Before the fix Flutter's check failed on 25 captures; after, on 7 (see
L3 below).

| Control | Now announced as | File |
|---|---|---|
| Composer delete-step button | "Delete step" | `routine_composer_step_row.dart:154` |
| Settings switches | the row's title, e.g. "Buzz on step complete" | `settings_screen.dart:394` |
| Each reminder's on/off switch | "Reminder at 8:15 AM, Weekdays" | `routine_reminders_screen.dart:560, 2156` |
| Completion-email switches | "Completion emails", "Show the routine name" | `routine_reminders_screen.dart:1252, 1307` |
| Routine style icon tiles | the icon's name, plus "Premium" when locked, and whether it is selected | `routine_style_picker_sheet.dart:396` |
| Routine style colour swatches | "Colour 1", "Colour 2", ... and whether selected | `routine_style_picker_sheet.dart:491` |
| Close button on the history photo sheet | "Close" | `routine_run_detail_screen.dart:295` |

Tests: `routine_composer_screen_test.dart`, `settings_screen_test.dart` and the
new `test/features/routines/creator/routine_style_picker_sheet_test.dart` run
Flutter's "every tappable thing has a name" check. The reminder switches have
no unit test; they were confirmed by the harness re-run (the reminders and
email-contact captures no longer fail the check).

### 4. Paywall footer links (Fixed)

"Restore purchase", "Terms of Use" and "Privacy Policy" were 40 high. They are
now 48 high, the Android minimum. Layout only: purchase and restore code is
untouched. Code: `pebble_paywall.dart:2223`. Test: `pebble_paywall_test.dart`.

## Findings not fixed

### Colour contrast

| # | Finding | Measured | Where | Status |
|---|---|---|---|---|
| C3 | Secondary button and small pill labels are slightly under on their own tinted fill in seven light themes. | Warm Sepia 4.05, Soft Pink 4.06, Matcha 4.12, Oatmeal 4.15, Parchment 4.20, Rose Quartz 4.23, Paper & Ink 4.31 (need 4.5) | `pebble_buttons.dart:139, 154-155, 175-176` | Not fixed: outside the four agreed fixes. Small follow-up using the same helper. |
| C4 | Red filled "delete" button label too faint in two themes. | Pebble Dark 3.91, Colour Blind Safe 3.98 | `colors.dart:83, 266, 550` | Not fixed: outside the agreed fixes. |
| C5 | Placeholder text in text boxes (theme default: text colour at 50%). | Fails in 19 of 22 themes, e.g. Matcha 2.45, Soft Pink 2.59, Sandstone 2.64, High Noon 2.73 | `colors.dart:182-184` | Needs owner decision. One-line theme change that affects every text box and may change the Sandstone golden image. |
| C6 | The raw "secondary" text colour is used directly in places instead of the readable helper. | Matcha 3.74, Soft Pink 4.09, Sandstone 4.19, Oatmeal 4.20, High Noon 4.44; Pebble Dark 3.83 on raised cards | e.g. `styled_history_screen.dart:850`; `zen_components.dart:28`; `pebble_paywall.dart:2198` (renewal terms) | Not fixed. Call sites not all reviewed. |
| C7 | The readable secondary colour is only guaranteed on the page and low cards; on raised cards in Pebble Dark and Colour Blind Safe it is just under. | 4.41 | `readable_colors.dart` (`_textBackgrounds`) | Not fixed. |
| C8 | The accent colour used directly as small text fails in several themes. | Rose Quartz 3.05, Oatmeal 3.33, Matcha 3.39, Parchment 3.48, Soft Pink 3.73, Warm Sepia 4.15 | `colors.dart:199` (outlined button text); other direct uses not listed | Not fixed. Call sites not reviewed. |
| C9 | Sandstone's terracotta "action" colour. | Terracotta on page 3.10; cream on terracotta 3.36. Fine for the "+" icon (needs 3.0), not for body text. Step badge tints: sage 2.41, tan 1.86 | `colors.dart:336-348` | Needs owner decision. Where it is used as text was not checked. |
| C10 | Text-box and card outlines are nearly invisible as a boundary. | 1.23 to 1.67 in every theme (guideline 3.0) | `colors.dart:87, 174-177` | Needs owner decision: this is the app's soft visual style. |
| C11 | In the High Contrast Dark composer, the "STEPS" heading, step-number badges and "Require photo" look faint. | Seen by eye only | `routine_composer_screen.dart`, `routine_composer_step_row.dart` | Not verified. |
| C12 | Decorative uses of the muted colour (chevrons, small icons, the "\|" between paywall links, empty-state icons) remain below 3:1 in most themes. | 1.98 to 3.33 | `styled_history_screen.dart:518, 800, 1446`; `pebble_paywall.dart:1705, 2233`; `routine_creation_choice_sheet.dart:191`; `zen_notifications.dart:384` (toast close icon) | Not fixed. All but the toast close icon are decoration next to a label. |

What passes in every theme: main text on the page (7.39 to 21.0), the "done"
green on the page (4.81 and up; Reduced Contrast 4.35 by design), red error
text on the page (5.29 and up), and the readable secondary colour on the page
and low cards.

### Text size

| # | Finding | Evidence | Where | Status |
|---|---|---|---|---|
| T1 | **The app caps text enlargement at 1.6x.** Someone who sets their phone to 2x gets 1.6x. | With the cap in place, the "2.0x" captures match the 1.6x ones. | `lib/main.dart:741-747` | **Needs owner decision.** Not changed. See below. |
| T2 | The Home header only grows to 1.3x and the tagline fades out under the settings button. | `iphone__a11y1.6x_home_populated.png` | `routine_list_screen.dart:684-735` | Not fixed. Cosmetic: the tagline is decorative. |
| T3 | Bottom navigation labels grow to 1.3x, sub-page headers to 1.5x, button labels to 1.6x. | Code | `app_shell.dart:117`; `pebble_navigation.dart:296`; `pebble_buttons.dart:117` | Needs owner decision (deliberate). |

**What happens above 1.6x.** To inform the decision, the ten large-text
scenarios were rendered once with the cap temporarily lifted to a true 2.0x
(the change was not committed). Nothing overflowed or overlapped, and the
harness logged no layout errors. What did happen is that names get cut short:

- Home routines sheet: "Leaving the house" becomes "Leaving the h..."
  (`accessibility/text_2.0x_uncapped_home_routines_sheet_open.png`).
- Player: the last completed step becomes "Windows l..." beside its time
  (`accessibility/text_2.0x_uncapped_player_photo_step.png`).
- Onboarding theme cards: "Amber Resin" becomes "Amber Re..."
  (`accessibility/text_2.0x_uncapped_onboarding_theme.png`).
- Paywall: readable, but the plan cards and the buy button are pushed below
  the first screen (`accessibility/text_2.0x_uncapped_paywall.png`).

This covers only Home, the player, the paywall and onboarding. History,
reminders, the composer, settings and the account screens have no large-text
scenario in the harness, so how they behave at 2.0x is unknown. The code
comment at `lib/main.dart:742` says fixed-height cards and the navigation bar
overflow above 1.6x; that was not reproduced on the screens tested.

### Tap targets under 48x48

Measured by Flutter's Android tap-target check, after the fixes.

| # | Control | Measured | Where | Status |
|---|---|---|---|---|
| S2 | "Back up with Premium" link on the History list | 117 x 14 | `styled_history_screen.dart:1493` | Not fixed. Smallest target found. |
| S3 | Composer step options: "Require photo", "Required"/"Optional", "Voice tip" | 104 x 36 | `routine_composer_step_row.dart` | Not fixed. |
| S4 | Composer delete-step button | 36 x 36 | `routine_composer_step_row.dart:153-166` | Not fixed (now has a name; size unchanged). |
| S5 | Composer step-name and routine-name text fields | 36 to 36.6 high | `routine_composer_screen.dart`, `routine_composer_step_row.dart` | Not fixed. |
| S6 | History "Timeline" / "Photos" tabs | 168 x 30 | `styled_history_screen.dart` | Not fixed. |
| S7 | Reminder day circles; "Every day" / "Weekdays" chips | 40 x 40; 37 high | `reminder_editor_sheet.dart` | Not fixed. `DESIGN_DIRECTION.md` specifies 40 for the day circles. |
| S8 | Round glass buttons (back, settings, account) and "tertiary" text buttons ("Skip for now", "Not now", "See details" and similar) | 44 | `pebble_navigation.dart:74`; `pebble_buttons.dart:109` | Needs owner decision. 44 is the documented design size and meets Apple's guideline, but is under Android's 48. |
| S9 | Compact pill buttons; player "Back" | 40 high | `pebble_buttons.dart:110` | Needs owner decision (documented design size). |
| S10 | History search button | 40 x 40 | `styled_history_screen.dart:844-853` | Not fixed. |

### Screen-reader labels

| # | Finding | Where | Status |
|---|---|---|---|
| L3 | Still failing Flutter's name check after the fixes (7 captures): the dimmed background behind the Home routines sheet and the lapsed-routines sheet (a full-screen tappable area with no name), and one 24 x 24 control on the pending-purchase screen. | Sheet scrim in `routine_list_screen.dart`; the 24 x 24 control was not traced | Not fixed. The scrim only closes the sheet. |
| L4 | Photos (`Image.file`) carry no description of their own in the history list, run detail, gallery viewer and player thumbnails. Some sit inside a named parent (for example "Photo 1 of 3" on the completion screen); the rest were not checked. | `pebble_photo_gallery_viewer.dart:267`; `styled_history_screen.dart:1829`; `routine_run_detail_screen.dart:1149`; `routine_player_screen.dart:1988` | Not verified. |
| L5 | The Cloud backup switch was not rendered in any capture with the check running, so it is unconfirmed. | `cloud_backup_screen.dart:678` | Not verified. |
| L6 | Reading order on the player, completion screen, paywall, sign-in, backup and reminders screens. | | Not verified. Needs a real device with TalkBack or VoiceOver. |

### Reduce motion

| # | Finding | Where | Status |
|---|---|---|---|
| M1 | "Reduce motion" is respected by the button press animation, the routine player, the completion screen, onboarding and the Home hero. | `pebble_buttons.dart:282`; `routine_player_screen.dart:190`; `routine_complete_screen.dart:151`; `onboarding_screen.dart:718`; `routine_list_screen.dart:2123` | Passed by reading the code. Not run with the setting on. |
| M2 | Other animations were not reviewed: the animated background, toast notifications, the bounce button, the "show steps" chevron. | `core/ui_kit/animated_background.dart`; `core/ui/zen_notifications.dart`; `core/ui/zen_components.dart:111`; `routine_list_screen.dart:2398` | Not verified. |

## Check results

- `flutter analyze`: "No issues found!"
- `flutter test`: 413 passed, 1 failed. The one failure is the known Sandstone
  golden image, which differs by 0.41% on this Windows machine, the same figure
  as before these changes. It was not regenerated.
- Screenshot harness: 120 of 120 scenarios passed after the fixes, 235
  screenshots, no layout overflow errors.

## Suggested next steps

1. C3, C4, C7: small, contained, same helper as fix 1.
2. C6 and C8: swap direct colour uses for the readable helpers, screen by screen.
3. S2 to S6, S10: raise tap targets to 48.
4. Owner decisions: C5, C9, C10, T1, T3, S8, S9.
5. A TalkBack and VoiceOver pass on a real phone (L4, L5, L6).
