import 'package:shared_preferences/shared_preferences.dart';

class PlayerSettingsController {
  final SharedPreferences prefs;

  PlayerSettingsController(this.prefs);

  bool get showStepCount => prefs.getBool('showStepCount') ?? true;
  set showStepCount(bool value) => prefs.setBool('showStepCount', value);

  bool get showProgressRing => prefs.getBool('showProgressRing') ?? true;
  set showProgressRing(bool value) => prefs.setBool('showProgressRing', value);

  bool get autoAdvanceTimers => prefs.getBool('autoAdvanceTimers') ?? true;
  set autoAdvanceTimers(bool value) =>
      prefs.setBool('autoAdvanceTimers', value);

  bool get enableTransitions => prefs.getBool('enableTransitions') ?? true;
  set enableTransitions(bool value) =>
      prefs.setBool('enableTransitions', value);

  bool get showVisualAnchor => prefs.getBool('showVisualAnchor') ?? true;
  set showVisualAnchor(bool value) => prefs.setBool('showVisualAnchor', value);

  // Step-complete reassurance feedback. Off by default: most users do not
  // expect their phone to buzz or chime, and those who want it opt in.
  bool get stepCompleteHaptic => prefs.getBool('stepCompleteHaptic') ?? false;
  set stepCompleteHaptic(bool value) =>
      prefs.setBool('stepCompleteHaptic', value);

  bool get stepCompleteSound => prefs.getBool('stepCompleteSound') ?? false;
  set stepCompleteSound(bool value) =>
      prefs.setBool('stepCompleteSound', value);
}
