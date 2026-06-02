import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

import '../../support/premium_policy_test_utils.dart';

void main() {
  test('nordicNight id is wired to the Pebble Dark palette constants', () {
    final source = File('lib/core/theme/colors.dart').readAsStringSync();

    expect(source, contains('id: ThemeId.nordicNight'));
    expect(source, contains('bg: const Color(0xFF1B1813)'));
    expect(source, contains('fg: const Color(0xFFF0E9D6)'));
    expect(source, contains('accent: const Color(0xFFC4946A)'));
    expect(source, contains('secondary: const Color(0xFF7FA87E)'));
    expect(source, contains('error: const Color(0xFFC07B68)'));
    expect(source, contains('surfaceLow: Color(0xFF232018)'));
    expect(source, contains('surfaceHigh: Color(0xFF2A2720)'));
    expect(source, contains('borderSubtle: Color(0xFF2E2922)'));
  });

  test('included and accessibility themes remain available to free users', () {
    final container = ProviderContainer(
      overrides: [
        subscriptionProvider.overrideWithValue(UserTier.personalFree),
        premiumFeaturePolicyProvider.overrideWithValue(
          premiumFeaturePolicyForTier(UserTier.personalFree),
        ),
      ],
    );
    addTearDown(container.dispose);

    final freeThemes = container.read(availableThemesProvider);
    final freeThemeIds = freeThemes.map((theme) => theme.id);

    expect(ThemeMetadata.get(ThemeId.amberResin).name, 'Amber Resin');
    expect(freeThemeIds, contains(ThemeId.highNoon));
    expect(freeThemeIds, contains(ThemeId.amberResin));
    expect(freeThemeIds, contains(ThemeId.highContrastDark));
    expect(freeThemeIds, contains(ThemeId.warmSepia));
    expect(freeThemeIds, isNot(contains(ThemeId.roseQuartz)));
    expect(freeThemeIds, isNot(contains(ThemeId.lavenderAsh)));
  });
}
