import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one-time hints that teach Pebble after onboarding. Each shows once
/// and never comes back.
enum PebbleHint {
  /// Practice run: "Do the step for real, then tap below."
  playerTick,

  /// Practice run, on a photo step.
  playerPhoto,

  /// The first time a routine's settings open.
  routineSettings,

  /// A "Make it yours" card on Home after a few checks.
  styleCard,
}

/// The practice run and the hints that follow it.
///
/// Only installs that go through the new onboarding (or replay it) see the
/// hints, so people who already know Pebble are never taught it again.
class OnboardingTour {
  OnboardingTour(this._prefs);

  final SharedPreferences? _prefs;

  static const practiceRoutineKey = 'pebble.tour.practice_routine_id';
  static const hintsEnabledKey = 'pebble.tour.hints_enabled';
  static const completedChecksKey = 'pebble.tour.completed_checks';

  /// Checks before Home suggests Style.
  static const checksBeforeStyleCard = 3;

  static String _seenKey(PebbleHint hint) => 'pebble.tour.seen.${hint.name}';

  bool get hintsEnabled => _prefs?.getBool(hintsEnabledKey) ?? false;

  bool shouldShow(PebbleHint hint) =>
      hintsEnabled && !(_prefs?.getBool(_seenKey(hint)) ?? false);

  Future<void> markSeen(PebbleHint hint) async {
    await _prefs?.setBool(_seenKey(hint), true);
  }

  /// Starts the tour: hints on, none seen yet, no checks counted.
  Future<void> start() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(hintsEnabledKey, true);
    await prefs.remove(completedChecksKey);
    for (final hint in PebbleHint.values) {
      await prefs.remove(_seenKey(hint));
    }
  }

  /// The routine being tried in the practice run, if one is running.
  int? get practiceRoutineId => _prefs?.getInt(practiceRoutineKey);

  bool isPracticeRun(int routineId) => practiceRoutineId == routineId;

  Future<void> startPracticeRun(int routineId) async {
    await _prefs?.setInt(practiceRoutineKey, routineId);
  }

  Future<void> endPracticeRun() async {
    await _prefs?.remove(practiceRoutineKey);
  }

  int get completedChecks => _prefs?.getInt(completedChecksKey) ?? 0;

  Future<void> recordCompletedCheck() async {
    if (!hintsEnabled) return;
    await _prefs?.setInt(completedChecksKey, completedChecks + 1);
  }

  bool get shouldShowStyleCard =>
      completedChecks >= checksBeforeStyleCard &&
      shouldShow(PebbleHint.styleCard);
}

final onboardingTourProvider = Provider<OnboardingTour>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Some tests run screens without preferences; the tour just stays off.
    prefs = null;
  }
  return OnboardingTour(prefs);
});
