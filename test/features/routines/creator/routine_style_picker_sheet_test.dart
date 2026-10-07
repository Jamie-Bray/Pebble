import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_style_picker_sheet.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required bool premium,
    ValueChanged<RoutineStylePickerResult>? onChanged,
    VoidCallback? onPremiumTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromId(ThemeId.highNoon),
        home: Scaffold(
          body: RoutineStylePickerSheet(
            initialIconKey: RoutineIconCatalog.defaultKey,
            initialColorHex: null,
            routineTitle: 'Leaving the house',
            hasPremiumAccess: premium,
            onChanged: onChanged,
            onPremiumTap: onPremiumTap,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('icon and colour tiles are named for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSheet(tester, premium: false);

    expect(find.bySemanticsLabel('Pebble'), findsWidgets);
    expect(find.bySemanticsLabel('Home'), findsWidgets);
    expect(find.bySemanticsLabel('Pets, Premium'), findsWidgets);
    expect(find.bySemanticsLabel('Theme colour'), findsWidgets);
    expect(find.bySemanticsLabel('Moss'), findsWidgets);
    expect(find.bySemanticsLabel('Heather, Premium'), findsWidgets);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('free users can pick a free stone; locked ones open Premium', (
    tester,
  ) async {
    RoutineStylePickerResult? last;
    var premiumTaps = 0;
    await pumpSheet(
      tester,
      premium: false,
      onChanged: (value) => last = value,
      onPremiumTap: () => premiumTaps++,
    );

    await tester.tap(find.bySemanticsLabel('Clay'));
    await tester.pump();
    expect(last?.colorHex, RoutinePalette.match(last?.colorHex)?.storedHex);
    expect(RoutinePalette.match(last?.colorHex)?.key, 'clay');

    await tester.tap(find.bySemanticsLabel('Heather, Premium'));
    await tester.pump();
    expect(premiumTaps, 1);
    expect(RoutinePalette.match(last?.colorHex)?.key, 'clay');
  });
}
