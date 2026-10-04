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

  // Step-complete feedback. The stored default stays off, so anyone who
  // installed before Moment 1 keeps exactly what they had; new installs get
  // the buzz on through [applyNewInstallDefaults]. Sound is always opt-in.
  bool get stepCompleteHaptic => prefs.getBool('stepCompleteHaptic') ?? false;
  set stepCompleteHaptic(bool value) =>
      prefs.setBool('stepCompleteHaptic', value);

  bool get stepCompleteSound => prefs.getBool('stepCompleteSound') ?? false;
  set stepCompleteSound(bool value) =>
      prefs.setBool('stepCompleteSound', value);

  /// Defaults for a new install, written once when onboarding finishes
  /// (DESIGN_DIRECTION.md Moment 1): "Buzz on step complete" on. Only fills
  /// in a value the person has never set, so an existing choice is never
  /// overwritten.
  static Future<void> applyNewInstallDefaults(SharedPreferences prefs) async {
    if (!prefs.containsKey('stepCompleteHaptic')) {
      await prefs.setBool('stepCompleteHaptic', true);
    }
  }
}
