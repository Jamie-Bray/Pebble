import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/home_widget/home_widget_setup.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';

Routine _routine(int id, {bool isPinned = false, DateTime? pinnedAt}) {
  return Routine(
    id: id,
    title: 'Routine $id',
    stepsJson: jsonEncode(const []),
    createdAt: DateTime(2026, 1, 1),
    emoji: 'check',
    colorHex: null,
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

class _FakeHost extends HomeWidgetHost {
  _FakeHost({this.canPin = false});

  final bool canPin;
  int pinRequests = 0;

  @override
  Future<int?> installedWidgetCount() async => 0;

  @override
  Future<bool> canRequestPinWidget() async => canPin;

  @override
  Future<void> requestPinWidget() async => pinRequests++;
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required HomeWidgetHost host,
  List<Routine> routines = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeWidgetHostProvider.overrideWithValue(host),
        routineListProvider.overrideWith((ref) => Stream.value(routines)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showHomeWidgetSetupSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('chooseWidgetRoutine', () {
    test('pins the chosen routine first, then unpins the others', () async {
      final calls = <(int, bool)>[];
      await chooseWidgetRoutine(
        routine: _routine(3),
        routines: [
          _routine(1, isPinned: true),
          _routine(2),
          _routine(3),
          _routine(4, isPinned: true),
        ],
        setPinned: (id, pinned) async => calls.add((id, pinned)),
      );
      expect(calls, [(3, true), (1, false), (4, false)]);
    });

    test('re-choosing an older pin makes it the newest', () async {
      final calls = <(int, bool)>[];
      await chooseWidgetRoutine(
        routine: _routine(1, isPinned: true),
        routines: [_routine(1, isPinned: true), _routine(2, isPinned: true)],
        setPinned: (id, pinned) async => calls.add((id, pinned)),
      );
      expect(calls, [(1, true), (2, false)]);
    });
  });

  test('clearWidgetRoutine unpins every pinned routine', () async {
    final calls = <(int, bool)>[];
    await clearWidgetRoutine(
      routines: [
        _routine(1, isPinned: true),
        _routine(2),
        _routine(3, isPinned: true),
      ],
      setPinned: (id, pinned) async => calls.add((id, pinned)),
    );
    expect(calls, [(1, false), (3, false)]);
  });

  test('setup steps are three short lines on each platform', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final steps = homeWidgetSetupSteps(platform);
      expect(steps, hasLength(3));
      for (final step in steps) {
        expect(step.length, lessThan(60));
        expect(step, isNot(contains('!')));
      }
    }
  });

  group('setup sheet', () {
    testWidgets('shows the steps and how to choose a routine', (tester) async {
      await _pumpSheet(tester, host: _FakeHost());

      expect(find.text('Add Pebble to your home screen'), findsOneWidget);
      expect(find.textContaining('Show on widget'), findsOneWidget);
      expect(
        find.text('Touch and hold an empty spot on your home screen.'),
        findsOneWidget,
      );
      expect(
        find.text('Tap Widgets and find Pebble Routines.'),
        findsOneWidget,
      );
      // This launcher can't add widgets for the app.
      expect(find.text('Add widget'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Add Pebble to your home screen'), findsNothing);
    });

    testWidgets('names the routine the widget shows', (tester) async {
      await _pumpSheet(
        tester,
        host: _FakeHost(),
        routines: [_routine(5, isPinned: true, pinnedAt: DateTime(2026, 6))],
      );

      expect(find.textContaining('"Routine 5"'), findsOneWidget);
    });

    testWidgets('offers Add widget where the launcher supports it', (
      tester,
    ) async {
      final host = _FakeHost(canPin: true);
      await _pumpSheet(tester, host: host);

      await tester.tap(find.text('Add widget'));
      await tester.pumpAndSettle();

      expect(host.pinRequests, 1);
      expect(find.text('Add Pebble to your home screen'), findsNothing);
    });
  });
}
