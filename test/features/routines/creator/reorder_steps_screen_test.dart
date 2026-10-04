import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routines/creator/ui/reorder_steps_screen.dart';

Routine _routine(List<String> labels) {
  return Routine(
    id: 1,
    title: 'Morning',
    stepsJson: jsonEncode(
      labels.map((label) => RoutineStep.check(label: label).toJson()).toList(),
    ),
    createdAt: DateTime(2026, 4, 1),
    emoji: 'list-check',
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: DateTime(2026, 4, 1),
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

List<String> _visibleOrder(WidgetTester tester, List<String> labels) {
  final positioned = [
    for (final label in labels) (label, tester.getTopLeft(find.text(label)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final entry in positioned) entry.$1];
}

void main() {
  const labels = ['Kettle on', 'Open curtains', 'Water plants'];

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: ReorderStepsScreen(routine: _routine(labels)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('dragging the first step to the bottom moves it last', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(_visibleOrder(tester, labels), labels);

    final itemHeight =
        tester.getTopLeft(find.text('Open curtains')).dy -
        tester.getTopLeft(find.text('Kettle on')).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Kettle on')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, itemHeight * 0.25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_visibleOrder(tester, labels), [
      'Open curtains',
      'Water plants',
      'Kettle on',
    ]);
  });

  testWidgets('onReorderItem indexes are final positions, no off-by-one', (
    tester,
  ) async {
    await pumpScreen(tester);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );

    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester, labels), [
      'Open curtains',
      'Kettle on',
      'Water plants',
    ]);

    list.onReorderItem!(2, 0);
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester, labels), [
      'Water plants',
      'Open curtains',
      'Kettle on',
    ]);
  });
}
