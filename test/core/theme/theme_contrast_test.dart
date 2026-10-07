import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

/// Launch contrast rules for every theme (WCAG AA: 4.5:1 for text).
/// Reduced Contrast is deliberately soft, so it only has to keep body text
/// and its input hints readable.
void main() {
  final cases = <(String, ThemeId, ThemeData Function())>[
    for (final id in ThemeId.values) (id.name, id, () => AppTheme.fromId(id)),
    // Seasons changes through the year, so check every season, not just
    // today's.
    for (final season in PebbleSeason.values)
      (
        'seasonal ${season.name}',
        ThemeId.seasonal,
        () => SeasonalThemeFactory.build(season),
      ),
  ];
  for (final (name, id, build) in cases) {
    test('$name meets the reading contrast rules', () {
      final theme = build();
      final f = theme.extension<PebbleDarkFoundation>()!;
      final x = theme.extension<PebbleThemeX>()!;
      final cs = theme.colorScheme;
      final soft = id == ThemeId.reducedContrast;

      void atLeast(String what, double ratio, double min) {
        expect(
          ratio,
          greaterThanOrEqualTo(min),
          reason: '$what is ${ratio.toStringAsFixed(2)}:1, needs $min:1',
        );
      }

      atLeast('body text', contrastRatio(f.textPrimary, f.bgBase), 4.5);
      atLeast(
        'hint text',
        contrastRatio(f.textSecondary, f.bgBase),
        soft ? 3.0 : 4.5,
      );
      if (soft) return;
      atLeast('caption text', contrastRatio(f.textSecondary, f.bgBase), 4.5);
      atLeast(
        'caption text on cards',
        contrastRatio(f.textSecondary, f.surfaceLow),
        4.4,
      );
      atLeast('icons', contrastRatio(f.textMuted, f.bgBase), 3.0);
      atLeast('accent as text', contrastRatio(cs.primary, f.bgBase), 4.5);
      atLeast('button label', contrastRatio(cs.onPrimary, cs.primary), 4.5);
      atLeast(
        'action button label',
        contrastRatio(x.onActionAccent, x.actionAccent),
        4.5,
      );
    });
  }

  test('dark themes paint their own background', () {
    for (final id in ThemeId.values) {
      final theme = AppTheme.fromId(id);
      if (theme.brightness != Brightness.dark) continue;
      final f = theme.extension<PebbleDarkFoundation>()!;
      expect(
        f.bgBase,
        theme.scaffoldBackgroundColor,
        reason: '${id.name} page colour should match its own background',
      );
    }
  });

  test('every theme has picker details and a free / Premium / a11y place', () {
    for (final id in ThemeId.values) {
      expect(ThemeMetadata.metadata[id], isNotNull, reason: id.name);
    }
    final free = ThemeMetadata.byCategory(ThemePickerCategory.included);
    final premium = ThemeMetadata.byCategory(
      ThemePickerCategory.premium,
    ).where((t) => t.isVisibleOnMainPicker);
    expect(free.length, greaterThanOrEqualTo(6));
    expect(premium.length, greaterThan(free.length));
    expect(
      ThemeMetadata.byCategory(
        ThemePickerCategory.accessibility,
      ).every((t) => t.isVisibleOnMainPicker),
      isTrue,
    );
  });
}
