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

  bool get enableHaptics => prefs.getBool('enableHaptics') ?? true;
  set enableHaptics(bool value) => prefs.setBool('enableHaptics', value);
}
