import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_list_screen.dart';

void main() {
  group('selectHomeSpotlightRoutine', () {
    test('uses last-run routine first', () {
      final newest = _routine(id: 1, title: 'Newest');
      final lastRun = _routine(id: 2, title: 'Last Run');
      final pinned = _routine(id: 3, title: 'Pinned', isPinned: true);

      final selected = selectHomeSpotlightRoutine(
        routines: [newest, lastRun, pinned],
        runs: [
          _run(routineId: 1, finishedAt: DateTime(2026, 4, 1)),
          _run(routineId: 2, finishedAt: DateTime(2026, 4, 2)),
        ],
      );

      expect(selected?.title, 'Last Run');
    });

    test('falls back to pinned routine', () {
      final newest = _routine(id: 1, title: 'Newest');
      final pinned = _routine(id: 2, title: 'Pinned', isPinned: true);

      final selected = selectHomeSpotlightRoutine(
        routines: [newest, pinned],
        runs: const [],
      );

      expect(selected?.title, 'Pinned');
    });

    test('falls back to newest routine from the provided list', () {
      final newest = _routine(id: 1, title: 'Newest');
      final older = _routine(id: 2, title: 'Older');

      final selected = selectHomeSpotlightRoutine(
        routines: [newest, older],
        runs: const [],
      );

      expect(selected?.title, 'Newest');
    });
  });

  testWidgets('empty home shows calm create and template actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(routines: const [], runs: const []),
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const RoutineListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Start with one routine.'), findsOneWidget);
    expect(find.text('Create routine'), findsOneWidget);
    expect(find.text('Use template'), findsOneWidget);
    expect(find.text('Life flows better\nwith routines'), findsNothing);
    expect(find.textContaining('organized humans'), findsNothing);
  });

  testWidgets('non-empty home spotlights last-run routine', (tester) async {
    final routines = [
      _routine(id: 1, title: 'Newest'),
      _routine(id: 2, title: 'Last Run'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(
          routines: routines,
          runs: [_run(routineId: 2, finishedAt: DateTime(2026, 4, 2))],
        ),
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const RoutineListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Your Next Ripple'), findsOneWidget);
    expect(find.text('Begin Routine'), findsOneWidget);
    expect(find.text('Last Run.'), findsOneWidget);
    expect(find.text('Your routines'), findsOneWidget);
    expect(find.text('Last Run'), findsNothing);
    expect(find.text('Newest'), findsNothing);
    await tester.tap(find.text('Your routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('Last Run'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);

    await tester.drag(find.text('Your Routines'), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Your routines'), findsOneWidget);
    expect(find.text('Your Routines'), findsNothing);

    await tester.tap(find.text('Your routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Newest.'), findsOneWidget);
    expect(find.text('Your routines'), findsOneWidget);
  });

  testWidgets('template handoff highlights the new routine on Home', (
    tester,
  ) async {
    final routines = [
      _routine(id: 1, title: 'Last Run'),
      _routine(id: 9, title: 'Leaving Home'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(
          routines: routines,
          runs: [_run(routineId: 1, finishedAt: DateTime(2026, 4, 2))],
          highlight: const HomeRoutineHighlight(
            routineId: 9,
            message: 'Leaving Home is ready',
          ),
        ),
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const RoutineListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Small steps, big ripples'), findsOneWidget);
    expect(find.text('Leaving Home is ready'), findsNothing);
    expect(find.text('Leaving Home.'), findsOneWidget);
    expect(find.text('Begin Routine'), findsOneWidget);
    expect(find.text('Your routines'), findsOneWidget);
    expect(find.text('Leaving Home'), findsNothing);
    expect(find.text('Add step'), findsNothing);
    expect(find.text('Style'), findsNothing);

    await tester.tap(find.text('Your routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Your Routines'), findsOneWidget);
  });

  testWidgets('routine library scrolls beyond four routines', (tester) async {
    final routines = List.generate(
      7,
      (index) => _routine(id: index + 1, title: 'Routine ${index + 1}'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(routines: routines, runs: const []),
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const RoutineListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Routine 1.'), findsOneWidget);
    expect(find.text('Routine 1'), findsNothing);
    expect(find.text('Ready when you are'), findsNothing);
    expect(find.text('Your routines'), findsOneWidget);

    await tester.tap(find.text('Your routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -420),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Routine 7'), findsOneWidget);
  });

  testWidgets(
    'hero handles long routine titles while keeping the selected row visible',
    (tester) async {
      final routines = [
        _routine(id: 1, title: 'The Anxiety-Free Departure'),
        _routine(id: 2, title: 'Car Security & Parking Peace'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: _homeOverrides(routines: routines, runs: const []),
          child: MaterialApp(
            theme: AppTheme.fromId(ThemeId.highNoon),
            home: const RoutineListScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The Anxiety-Free Departure.'), findsOneWidget);
      expect(find.text('The Anxiety-Free Departure'), findsNothing);
      expect(find.text('Car Security & Parking Peace'), findsNothing);

      await tester.tap(find.text('Your routines'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('The Anxiety-Free Departure'), findsOneWidget);
      expect(find.text('Car Security & Parking Peace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hero handles large accessibility text without overflow', (
    tester,
  ) async {
    final routines = [
      _routine(id: 1, title: 'Morning Reset'),
      _routine(id: 2, title: 'Evening Wind Down'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: _homeOverrides(routines: routines, runs: const []),
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.4)),
            child: RoutineListScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Your Next Ripple'), findsOneWidget);
    expect(find.text('Morning Reset.'), findsOneWidget);
    expect(find.text('Begin Routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<Override> _homeOverrides({
  required List<Routine> routines,
  required List<RoutineRun> runs,
  HomeRoutineHighlight? highlight,
}) {
  return [
    currentThemeDataProvider.overrideWithValue(
      AppTheme.fromId(ThemeId.highNoon),
    ),
    currentColorThemeProvider.overrideWithValue(ThemeId.highNoon),
    routineListProvider.overrideWith((ref) => Stream.value(routines)),
    routineHistoryVmProvider.overrideWith((ref) => Stream.value(runs)),
    activeRoutineSessionsProvider.overrideWith((ref) => Stream.value(const [])),
    latestRoutineRunProvider.overrideWith(
      (ref, routineId) => Stream.value(null),
    ),
    homeRoutineHighlightProvider.overrideWith((ref) => highlight),
    accountBackupRingStateProvider.overrideWithValue(
      const AccountBackupRingState(
        variant: AccountBackupRingVariant.none,
        showRing: false,
        semanticsLabel: 'Account and backup',
        semanticsHint: null,
      ),
    ),
  ];
}

Routine _routine({
  required int id,
  required String title,
  bool isPinned = false,
}) {
  final createdAt = DateTime(2026, 4, id);
  return Routine(
    id: id,
    title: title,
    stepsJson: '[]',
    createdAt: createdAt,
    emoji: 'list-check',
    colorHex: null,
    isPinned: isPinned,
    pinnedAt: isPinned ? createdAt : null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: createdAt,
    cloudId: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

RoutineRun _run({required int routineId, required DateTime finishedAt}) {
  return RoutineRun(
    id: 'run-$routineId-${finishedAt.millisecondsSinceEpoch}',
    routineId: routineId.toString(),
    routineTitle: 'Routine $routineId',
    finishedAt: finishedAt,
    stepCompletionData: null,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: finishedAt,
  );
}
