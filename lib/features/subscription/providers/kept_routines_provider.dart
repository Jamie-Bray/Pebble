import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';

/// The routines a lapsed subscriber chose to keep using on Free limits.
///
/// Stored on this phone only. It never deletes or hides anything: it only
/// decides which routines stay unlocked while Premium is off.
class KeptRoutinesController extends StateNotifier<Set<int>> {
  KeptRoutinesController(this._prefs) : super(_read(_prefs));

  static const storageKey = 'pebble.lapse.kept_routine_ids';

  final SharedPreferences? _prefs;

  static Set<int> _read(SharedPreferences? prefs) {
    try {
      final raw = prefs?.getString(storageKey);
      if (raw == null || raw.isEmpty) return const <int>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <int>{};
      return decoded.whereType<num>().map((value) => value.toInt()).toSet();
    } catch (_) {
      return const <int>{};
    }
  }

  Future<void> keep(Set<int> routineIds) async {
    state = Set<int>.unmodifiable(routineIds);
    await _prefs?.setString(storageKey, jsonEncode(routineIds.toList()));
  }
}

final keptRoutinesProvider =
    StateNotifierProvider<KeptRoutinesController, Set<int>>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {
        prefs = null;
      }
      return KeptRoutinesController(prefs);
    });
