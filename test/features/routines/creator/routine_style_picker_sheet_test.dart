import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routines/creator/ui/routine_style_picker_sheet.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

void main() {
  testWidgets('icon and colour tiles are named for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.fromId(ThemeId.highNoon),
        home: const Scaffold(
          body: RoutineStylePickerSheet(
            initialIconKey: RoutineIconCatalog.defaultKey,
            initialColor: Color(0xFF4A5D4E),
            iconChoices: RoutineIconCatalog.all,
            hasPremiumIconAccess: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Pebble'), findsWidgets);
    expect(find.bySemanticsLabel('Shield, Premium'), findsWidgets);
    expect(find.bySemanticsLabel('Colour 1'), findsWidgets);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
