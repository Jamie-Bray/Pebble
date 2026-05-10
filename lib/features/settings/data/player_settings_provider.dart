import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_settings_controller.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // injected at app init
});

final playerSettingsControllerProvider = Provider<PlayerSettingsController>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PlayerSettingsController(prefs);
});
