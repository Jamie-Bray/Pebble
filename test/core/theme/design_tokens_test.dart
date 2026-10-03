import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';

const _handPicked = {
  ThemeId.highNoon,
  ThemeId.sandstone,
  ThemeId.nordicNight,
  ThemeId.sageMist,
  ThemeId.highContrastDark,
  ThemeId.reducedContrast,
};

void main() {
  group('done colour role', () {
    for (final id in ThemeId.values) {
      test('${id.name}: done is legible on the page', () {
        final theme = AppTheme.fromId(id);
        final x = theme.extension<PebbleThemeX>()!;
        final f = theme.extension<PebbleDarkFoundation>()!;

        // Glyphs (check stroke, pebbles) need 3:1 on the page and on cards.
        expect(
          contrastRatio(x.done, f.bgBase),
          greaterThanOrEqualTo(kMinLargeTextContrast),
          reason: 'done glyph on bgBase',
        );
        expect(
          contrastRatio(x.done, f.surfaceLow),
          greaterThanOrEqualTo(kMinLargeTextContrast),
          reason: 'done glyph on surfaceLow',
        );

        // Used for text (the time chip) it needs 4.5:1 on the page. Reduced
        // Contrast is deliberately soft and only promises 3:1.
        final textMin = id == ThemeId.reducedContrast
            ? kMinLargeTextContrast
            : kMinBodyTextContrast;
        expect(
          contrastRatio(x.done, f.bgBase),
          greaterThanOrEqualTo(textMin),
          reason: 'done text on bgBase',
        );
        // On its own doneContainer fill: themes using the default reach
        // 4.5:1; the hand-picked colours (DESIGN_DIRECTION.md §3.5) at least
        // 3:1, so chip text in those themes should be 600 weight or larger.
        final chipFill = Color.alphaBlend(x.doneContainer, f.bgBase);
        expect(
          contrastRatio(x.done, chipFill),
          greaterThanOrEqualTo(
            _handPicked.contains(id) ? kMinLargeTextContrast : textMin,
          ),
          reason: 'done text on doneContainer',
        );

        expect(x.doneContainer.a, closeTo(0.10, 0.01));
      });
    }

    test('specified themes use the documented colours', () {
      Color done(ThemeId id) =>
          AppTheme.fromId(id).extension<PebbleThemeX>()!.done;
      expect(done(ThemeId.highNoon), const Color(0xFF4E7A58));
      expect(done(ThemeId.sandstone), const Color(0xFF3F6B4A));
      expect(done(ThemeId.nordicNight), const Color(0xFF8DB592));
      expect(done(ThemeId.sageMist), const Color(0xFF7FB08A));
      expect(done(ThemeId.highContrastDark), const Color(0xFFFFDD00));
      expect(
        done(ThemeId.reducedContrast),
        AppTheme.fromId(ThemeId.reducedContrast).colorScheme.primary,
      );
    });
  });

  group('PebbleType', () {
    test('every theme carries the type scale in its text colour', () {
      for (final id in ThemeId.values) {
        final theme = AppTheme.fromId(id);
        final type = theme.extension<PebbleType>();
        expect(type, isNotNull, reason: id.name);
        expect(
          type!.body.color,
          theme.extension<PebbleDarkFoundation>()!.textPrimary,
        );
      }
    });

    test('uses two families and only the bundled weights', () {
      final t = PebbleType.forColor(Colors.black);
      final styles = [
        t.displayXL,
        t.display,
        t.title1,
        t.title2,
        t.step,
        t.sheetTitle,
        t.headline,
        t.bodyLarge,
        t.body,
        t.caption,
        t.overline,
        t.button,
      ];
      for (final s in styles) {
        expect(
          s.fontFamily,
          anyOf(startsWith('DMSans_'), startsWith('DMSerifDisplay_')),
        );
        expect(s.fontWeight!.value, inInclusiveRange(400, 600));
      }
      expect(t.title1.fontSize, 34);
      expect(t.title1.height! * 34, closeTo(38, 0.01));
      expect(t.button.fontSize, 17);
      expect(t.button.fontWeight, FontWeight.w600);
    });
  });

  group('PebbleMotion', () {
    test('settle does not visibly overshoot; land bounces once', () {
      double peak(SpringDescription d) {
        final sim = SpringSimulation(d, 0, 1, 0);
        var max = 0.0;
        for (var t = 0.0; t < 1.5; t += 0.002) {
          final x = sim.x(t);
          if (x > max) max = x;
        }
        return max;
      }

      expect(peak(PebbleMotion.settle), lessThan(1.02));
      expect(peak(PebbleMotion.land), greaterThan(1.02));
      expect(PebbleMotion.settleCurve.transform(0), 0);
      expect(PebbleMotion.settleCurve.transform(1), 1);
      expect(PebbleMotion.settleCurve.transform(0.5), greaterThan(0.9));
    });
  });

  test('spacing and radius scales', () {
    expect(
      [
        PebbleSpacing.xxs,
        PebbleSpacing.xs,
        PebbleSpacing.sm,
        PebbleSpacing.md,
        PebbleSpacing.lg,
        PebbleSpacing.xl,
        PebbleSpacing.xxl,
        PebbleSpacing.x3,
        PebbleSpacing.x4,
      ],
      [4, 8, 12, 16, 20, 24, 32, 40, 56],
    );
    expect(PebbleSpacing.gutter(360), 20);
    expect(PebbleSpacing.gutter(390), 24);
    expect(
      [
        PebbleRadius.xs,
        PebbleRadius.sm,
        PebbleRadius.md,
        PebbleRadius.lg,
        PebbleRadius.pill,
      ],
      [8, 12, 16, 24, 999],
    );
  });
}
