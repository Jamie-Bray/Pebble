import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/features/settings/data/player_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('step-complete feedback is off by default and persists when set', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final settings = PlayerSettingsController(prefs);

    expect(settings.stepCompleteHaptic, isFalse);
    expect(settings.stepCompleteSound, isFalse);

    settings.stepCompleteHaptic = true;
    settings.stepCompleteSound = true;

    expect(PlayerSettingsController(prefs).stepCompleteHaptic, isTrue);
    expect(PlayerSettingsController(prefs).stepCompleteSound, isTrue);
  });
}
