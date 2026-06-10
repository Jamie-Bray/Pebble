import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/home_widget/home_widget_publisher.dart';

Routine _routine({
  required int id,
  bool isPinned = false,
  DateTime? pinnedAt,
  int? colorHex,
}) {
  return Routine(
    id: id,
    title: 'Routine $id',
    stepsJson: jsonEncode(const []),
    createdAt: DateTime(2026, 1, 1),
    emoji: 'check',
    colorHex: colorHex,
    isPinned: isPinned,
    pinnedAt: pinnedAt,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: DateTime(2026, 1, 1),
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

void main() {
  group('selectWidgetRoutine', () {
    test('returns null when nothing is pinned', () {
      expect(selectWidgetRoutine([_routine(id: 1), _routine(id: 2)]), isNull);
    });

    test('returns the most recently pinned routine', () {
      final selected = selectWidgetRoutine([
        _routine(id: 1, isPinned: true, pinnedAt: DateTime(2026, 6, 1)),
        _routine(id: 2, isPinned: true, pinnedAt: DateTime(2026, 6, 9)),
        _routine(id: 3),
        _routine(id: 4, isPinned: true, pinnedAt: DateTime(2026, 5, 1)),
      ]);
      expect(selected?.id, 2);
    });

    test('pinned without timestamp loses to pinned with timestamp', () {
      final selected = selectWidgetRoutine([
        _routine(id: 1, isPinned: true),
        _routine(id: 2, isPinned: true, pinnedAt: DateTime(2026, 6, 9)),
      ]);
      expect(selected?.id, 2);
    });

    test('a single pinned routine without timestamp still wins', () {
      final selected = selectWidgetRoutine([
        _routine(id: 1),
        _routine(id: 2, isPinned: true),
      ]);
      expect(selected?.id, 2);
    });
  });

  group('routineIdFromWidgetUri', () {
    test('parses the launch uri', () {
      expect(routineIdFromWidgetUri(Uri.parse('pebble://play/42')), 42);
    });

    test('rejects foreign schemes, hosts, and junk ids', () {
      expect(routineIdFromWidgetUri(null), isNull);
      expect(routineIdFromWidgetUri(Uri.parse('https://play/42')), isNull);
      expect(routineIdFromWidgetUri(Uri.parse('pebble://settings/42')), isNull);
      expect(routineIdFromWidgetUri(Uri.parse('pebble://play')), isNull);
      expect(routineIdFromWidgetUri(Uri.parse('pebble://play/abc')), isNull);
    });
  });

  group('widgetColorHex', () {
    test('formats ARGB ints and passes null through', () {
      expect(widgetColorHex(0xFF8A6F5C), '#ff8a6f5c');
      expect(widgetColorHex(null), isNull);
    });
  });
}
