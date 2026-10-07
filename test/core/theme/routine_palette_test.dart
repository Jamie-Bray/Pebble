import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

void main() {
  test('free users keep free stones and lose Premium ones', () {
    final moss = RoutinePalette.stones.firstWhere((s) => s.key == 'moss');
    final heather = RoutinePalette.stones.firstWhere((s) => s.key == 'heather');
    expect(
      RoutinePalette.sanitizeForStorage(
        moss.storedHex,
        hasPremiumAccess: false,
      ),
      moss.storedHex,
    );
    expect(
      RoutinePalette.sanitizeForStorage(
        heather.storedHex,
        hasPremiumAccess: false,
      ),
      isNull,
    );
    expect(
      RoutinePalette.sanitizeForStorage(
        heather.storedHex,
        hasPremiumAccess: true,
      ),
      heather.storedHex,
    );
    // A colour picked before the stone palette is left alone.
    expect(
      RoutinePalette.sanitizeForStorage(0xFF1976D2, hasPremiumAccess: false),
      0xFF1976D2,
    );
  });

  test('free icons include the homely ones', () {
    final free = RoutineIconCatalog.all
        .where((icon) => !icon.isPremium)
        .map((icon) => icon.key);
    expect(free, containsAll(['house', 'door-closed', 'key', 'moon', 'sun']));
    expect(
      RoutineIconCatalog.all.map((icon) => icon.key).toSet().length,
      RoutineIconCatalog.all.length,
    );
  });

  for (final id in ThemeId.values) {
    testWidgets('every stone reads as text in ${id.name}', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.fromId(id),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );
      final f = ctx.darkFoundation;
      for (final stone in RoutinePalette.stones) {
        final accent = ctx.routineAccent(stone.storedHex);
        if (ThemeMetadata.get(id).isAccessibilityTheme) {
          expect(accent, isNull);
          continue;
        }
        expect(
          contrastRatio(accent!, f.bgBase),
          greaterThanOrEqualTo(kMinBodyTextContrast),
          reason: '${stone.name} on ${id.name}',
        );
      }
    });
  }
}
