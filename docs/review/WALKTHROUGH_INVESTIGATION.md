# Walkthrough Investigation

This document investigates the failures encountered when running the `walkthrough_screens_test.dart` harness locally.

## Execution Context

*   **Command:** `flutter test test/walkthrough/walkthrough_screens_test.dart`
*   **Environment Variables:** `WALKTHROUGH="1"`, `FLUTTER_TESTER_REAL_FONTS="1"`, `WALKTHROUGH_OUT="walkthrough_out"`
*   **Flutter Version:** 3.44.6 (Local Windows environment). Note: The project's required Flutter version in `codemagic.yaml` and `CLAUDE.md` is `3.47.6`.
*   **Total Tests Executed:** 120 captured scenes (approx).
*   **Failures Encountered:** 6.

## Failure Details

All six failures share the exact same root cause: the test harness attempts to tap a UI element that no longer exists with that specific text label.

### 1. Scenarios Failing
The following specific test scenarios failed with `StateError: Bad state: No element`:
1.  `home checked highNoon iphone 1.0`
2.  `home checked nordicNight iphone 1.0`
3.  `home checked highNoon small 1.0`
4.  `home checked highNoon iphone 2.0`
5.  `player complete photos highNoon`
6.  `player complete photos nordicNight`

### 2. Stack Trace and Traceback
The stack trace for all failures points to:
```
#5 WidgetController.ensureVisible (package:flutter_test/src/controller.dart:2389:32)
#6 _Env.tapText (test/walkthrough/walkthrough_screens_test.dart:836:18)
```
This is invoked from either:
*   `_runLeavingHouseToHome` at `walkthrough_screens_test.dart:1075`
*   The `player complete photos highNoon` closure at `walkthrough_screens_test.dart:1370`

### 3. Root Cause (Harness Defect)
In both failing methods, the harness executes:
```dart
await env.tapText('Add');
```
However, inspecting `lib/features/routines/execution/ui/routine_player_screen.dart` (lines ~106-111) reveals that the button text for capturing proof photos has been changed to:
*   `label: 'Add photo'` (for the first photo)
*   `label: 'Add more'` (for subsequent photos)

Because `tapText` relies on an exact string match (`find.text(text)`), it fails to find the element labeled exactly `'Add'`. 

This is a **harness problem**, not an application defect. The application correctly displays the expanded photo prompt buttons, but the screenshot script has fallen behind the UI copy updates.

## Proposed Correction

**Smallest next action:**
Update the `tapText` calls in `test/walkthrough/walkthrough_screens_test.dart` to match the current UI copy. 

In `_runLeavingHouseToHome` (line 1075):
```dart
// Change:
await env.tapText('Add');
// To:
await env.tapText('Add photo');
```

In the `player complete photos ...` scenarios (line 1370), where it iterates twice to capture two photos:
```dart
// Change:
for (var i = 0; i < 2; i++) {
  await env.tapText('Add');
  await env.realWait(12);
}
// To:
for (var i = 0; i < 2; i++) {
  await env.tapText(i == 0 ? 'Add photo' : 'Add more');
  await env.realWait(12);
}
```
*(Do not apply these fixes automatically; they are provided for Claude's implementation.)*
