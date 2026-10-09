import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/core/home_widget/home_widget_setup.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/history/domain/checked_window.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/routines/list/providers/home_hero_state_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/ui/home_hero_widgets.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_list_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../composer/fake_routine_composer_draft_repository.dart';

late SharedPreferences _prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

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

  testWidgets('empty home shows reliable create and template actions', (
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
    // AI is off here (no server), so scratch leads.
    expect(find.text('Build with AI'), findsNothing);
    expect(find.text('Start from scratch'), findsOneWidget);
    expect(find.text('Use a template'), findsOneWidget);
    expect(find.byTooltip('Reminders'), findsNothing);
    expect(find.text('Life flows better\nwith routines'), findsNothing);
    expect(find.textContaining('organized humans'), findsNothing);
  });

  testWidgets('empty home offers Build with AI when the server has it on', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._homeOverrides(routines: const [], runs: const []),
          routineAiClientProvider.overrideWithValue(_AiOn()),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const RoutineListScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Build with AI'), findsOneWidget);
    expect(find.text('Start from scratch'), findsOneWidget);
  });

  testWidgets('non-empty home spotlights last-run routine', (tester) async {
    final routines = [
      _routine(id: 1, title: 'Newest', steps: [_step('Open the curtains')]),
      _routine(
        id: 2,
        title: 'Last Run',
        steps: [_step('Check the doors'), _step('Settle the room')],
      ),
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

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Last Run.'), findsOneWidget);
    expect(find.byTooltip('App settings'), findsOneWidget);
    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Email'), findsNothing);
    // The unlabelled bell/mail/gear bar is gone: one Settings pill opens the
    // routine's actions instead.
    expect(find.byTooltip('Reminders'), findsNothing);
    expect(find.byTooltip('Email'), findsNothing);
    expect(find.byTooltip('Routine settings'), findsOneWidget);
    expect(find.text('2 steps'), findsWidgets);
    // The featured routine stays in the hero, and the other is below.
    expect(find.text('More routines'), findsOneWidget);
    expect(find.text('1 routine'), findsOneWidget);
    expect(find.text('Last Run'), findsNothing);
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Not checked yet'), findsWidgets);

    await tester.ensureVisible(find.text('Newest'));
    await tester.pump();
    await tester.tap(find.text('Newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Newest.'), findsOneWidget);
    expect(find.text('Last Run.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the routine list shows when each routine was last checked', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 8, 18);
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1400),
      clock: () => now,
      routines: [
        _routine(id: 1, title: 'Front door'),
        _routine(id: 2, title: 'Hob'),
        _routine(id: 3, title: 'Car'),
      ],
      runs: [
        _run(routineId: 1, finishedAt: DateTime(2026, 10, 8, 8, 2)),
        _run(routineId: 2, finishedAt: DateTime(2026, 10, 7, 21)),
      ],
      latestRun: _run(
        routineId: 1,
        finishedAt: DateTime(2026, 10, 8, 8, 2),
      ),
    );

    expect(find.text('2 routines'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home_hero_status_text'))).data,
      contains('8:02'),
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Hold a routine to reorder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Free does not show a check hidden from History', (tester) async {
    final oldRun = DateTime.now().subtract(const Duration(days: 4));
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1400),
      routines: [_routine(id: 1, title: 'Front door')],
      runs: [_run(routineId: 1, finishedAt: oldRun)],
      historyWindow: const Duration(hours: 48),
    );

    expect(find.text('Not checked yet'), findsWidgets);
    expect(tester.takeException(), isNull);
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

    expect(find.text('pebble.'), findsOneWidget);
    expect(find.text('Leaving Home is ready'), findsNothing);
    expect(find.text('Leaving Home.'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('More routines'), findsOneWidget);
    expect(find.text('Add step'), findsNothing);
    expect(find.text('Style'), findsNothing);
  });

  testWidgets('routine list scrolls beyond four routines', (tester) async {
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
    expect(find.text('Ready when you are'), findsNothing);
    expect(find.text('More routines'), findsOneWidget);
    expect(find.text('6 routines'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Routine 7'),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(find.text('Routine 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero layout is ordered and sits above the routine list', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      routines: [
        _routine(
          id: 1,
          title: 'Morning Reset',
          steps: [
            _step('Open the curtains'),
            _step('Start the kettle'),
            _step('Pack the bag'),
            _step('Lock the door'),
          ],
        ),
        _routine(id: 2, title: 'Evening Reset'),
      ],
    );

    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    double bottom(String key) =>
        tester.getBottomLeft(find.byKey(ValueKey(key))).dy;

    final headerBottom = tester.getBottomLeft(find.text('pebble.')).dy;
    expect(top('home_hero_title'), greaterThan(headerBottom));
    expect(find.byKey(const ValueKey('home_hero_action_strip')), findsNothing);
    // "4 steps" is the meta line, between the title and the steps.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home_hero_routine_meta')))
          .data,
      '4 steps',
    );
    expect(
      top('home_hero_routine_meta'),
      greaterThan(bottom('home_hero_title')),
    );
    expect(
      top('home_hero_preview_list'),
      greaterThan(bottom('home_hero_routine_meta')),
    );
    // The settings pill sits in the card's top row, not among the steps.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home_hero_preview_list')),
        matching: find.byTooltip('Routine settings'),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home_hero_status')), findsOneWidget);
    expect(
      top('home_hero_cta_box'),
      greaterThan(bottom('home_hero_preview_list')),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home_hero_cta_box'))).height,
      greaterThanOrEqualTo(48),
    );

    final listTop = tester.getTopLeft(find.text('More routines')).dy;
    expect(bottom('home_hero_cta_box'), lessThan(listTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Up next lists three steps and opens the rest in place', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1600),
      routines: [
        _routine(
          id: 1,
          title: 'Long Routine',
          steps: List.generate(12, (index) => _step('Long step ${index + 1}')),
        ),
      ],
    );

    expect(find.text('Long step 3'), findsOneWidget);
    expect(find.text('Long step 4'), findsNothing);
    expect(find.text('Show all 12 steps'), findsOneWidget);

    await tester.tap(find.text('Show all 12 steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Long step 12'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home Steps collapses and expands', (tester) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1200),
      routines: [
        _routine(
          id: 1,
          title: 'Departure Check',
          steps: [
            _step('Check windows'),
            _step('Pack wallet'),
            _step('Lock door'),
            _step('Keys in hand'),
          ],
        ),
      ],
    );

    expect(find.text('Check windows'), findsOneWidget);
    expect(find.text('Keys in hand'), findsNothing);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.text('Show all 4 steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Keys in hand'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.text('Show fewer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Keys in hand'), findsNothing);
    expect(find.text('Show all 4 steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a routine of three steps or fewer has nothing to expand', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      routines: [
        _routine(
          id: 1,
          title: 'Departure Check',
          steps: [_step('Check windows'), _step('Pack wallet')],
        ),
      ],
    );

    expect(find.text('Check windows'), findsOneWidget);
    expect(find.text('Pack wallet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_hero_preview_toggle')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded home Steps persists after rebuild', (tester) async {
    final routines = [
      _routine(
        id: 1,
        title: 'Departure Check',
        steps: List.generate(5, (i) => _step('Step ${i + 1}')),
      ),
    ];

    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1200),
      routines: routines,
    );
    expect(find.text('Step 5'), findsNothing);

    await tester.tap(find.text('Show all 5 steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('Step 5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 1200),
      routines: routines,
    );

    expect(find.text('Step 5'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview steps are read-only and edit is explicit', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      routines: [
        _routine(
          id: 1,
          title: 'Departure Check',
          steps: [
            _step('Check windows'),
            _step('Pack wallet'),
            _step('Lock door'),
          ],
        ),
      ],
    );

    expect(find.text('Pack wallet'), findsOneWidget);

    await tester.tap(find.text('Pack wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RoutineComposerScreen), findsNothing);
    expect(find.byType(RoutinePlayerScreen), findsNothing);
    expect(find.byTooltip('Routine settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded step list remains read-only', (tester) async {
    await _pumpHome(
      tester,
      routines: [
        _routine(
          id: 1,
          title: 'Long Departure',
          steps: List.generate(12, (index) => _step('Long step ${index + 1}')),
        ),
      ],
    );

    await tester.tap(find.text('Show all 12 steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    final target = find.text('Long step 8');
    await tester.dragUntilVisible(
      target,
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -80),
      maxIteration: 20,
    );
    await tester.pump();

    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RoutineComposerScreen), findsNothing);
    expect(find.byType(RoutinePlayerScreen), findsNothing);
    expect(tester.takeException(), isNull);
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

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Morning Reset.'), findsOneWidget);
    expect(find.byTooltip('App settings'), findsOneWidget);
    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(find.byTooltip('Routine settings'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long steps truncate at large text without hiding controls', (
    tester,
  ) async {
    const longStep =
        'Check every downstairs window and the back door before leaving the house';
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      textScale: 2.4,
      routines: [
        _routine(id: 1, title: 'Leaving the house', steps: [_step(longStep)]),
      ],
    );

    final label = tester.widget<Text>(find.text(longStep));
    expect(label.maxLines, 2);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(find.byTooltip('Routine settings'), findsOneWidget);
    await tester.ensureVisible(find.text('Start'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero keeps CTA visible on a short phone surface', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 680),
      routines: [
        _routine(
          id: 1,
          title: 'The Anxiety-Free Departure',
          steps: List.generate(8, (index) => _step('Short screen step $index')),
        ),
        _routine(id: 2, title: 'Evening Reset'),
      ],
    );

    expect(find.text('Start'), findsOneWidget);
    final ctaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    final shelfTop = tester.getTopLeft(find.text('More routines')).dy;
    expect(ctaBottom, lessThan(shelfTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('routine settings exposes widget pin action', (tester) async {
    final repo = _FakeRoutineRepository([
      _routine(id: 1, title: 'Morning Reset'),
    ]);

    await _pumpHome(
      tester,
      routines: repo._routines.values.toList(),
      routineRepository: repo,
    );

    await tester.tap(find.byTooltip('Routine settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Show on widget'), findsOneWidget);
    expect(find.text('Start it from your home screen'), findsOneWidget);

    await tester.ensureVisible(find.text('Show on widget'));
    await tester.pump();
    await tester.tap(find.text('Show on widget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.pinnedUpdates, equals([(1, true)]));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // No widget on the home screen yet, so Pebble explains how to add it.
    expect(find.text('Add Pebble to your home screen'), findsOneWidget);
    expect(
      find.text('Touch and hold an empty spot on your home screen.'),
      findsOneWidget,
    );
  });

  testWidgets('only the newest pin is tagged as shown on the widget', (
    tester,
  ) async {
    final repo = _FakeRoutineRepository([
      _routine(id: 1, title: 'Morning Reset', isPinned: true),
      _routine(id: 2, title: 'Leaving the house', isPinned: true),
    ]);

    await _pumpHome(
      tester,
      routines: repo._routines.values.toList(),
      routineRepository: repo,
    );

    await tester.tap(find.text('More routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Routine 2 was pinned last, so it is the widget routine.
    expect(find.textContaining('Shown on widget'), findsOneWidget);
    expect(find.textContaining('Pinned'), findsNothing);
  });

  testWidgets('library reorder moves a routine to the dropped position', (
    tester,
  ) async {
    final repo = _FakeRoutineRepository(
      List.generate(
        5,
        (index) => _routine(id: index + 1, title: 'Routine ${index + 1}'),
      ),
    );

    await _pumpHome(
      tester,
      routines: repo._routines.values.toList(),
      routineRepository: repo,
    );
    await tester.tap(find.text('More routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final list = tester.widget<SliverReorderableList>(
      find.byType(SliverReorderableList),
    );
    expect(list.itemCount, 4);

    // onReorderItem reports the final index: first row dropped in third
    // place is exactly two single-step moves down.
    list.onReorderItem!(0, 2);
    await tester.pump();
    expect(repo.moves, hasLength(2));
    expect(
      repo.moves.map((move) => move.$2),
      everyElement(RoutineMoveDirection.down),
    );
    expect(repo.moves.map((move) => move.$1).toSet(), hasLength(1));

    repo.moves.clear();
    list.onReorderItem!(3, 1);
    await tester.pump();
    expect(repo.moves, hasLength(2));
    expect(
      repo.moves.map((move) => move.$2),
      everyElement(RoutineMoveDirection.up),
    );
  });

  testWidgets('routine settings hides the widget pin action on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final repo = _FakeRoutineRepository([
        _routine(id: 1, title: 'Morning Reset', isPinned: true),
      ]);

      await _pumpHome(
        tester,
        routines: repo._routines.values.toList(),
        routineRepository: repo,
      );

      await tester.tap(find.byTooltip('Routine settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Show on widget'), findsNothing);
      expect(find.text('Remove from widget'), findsNothing);
      expect(find.textContaining('home widget'), findsNothing);
      expect(find.textContaining('Pinned'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('home at 2.0x text on an iPhone keeps Start and the header '
      'intact', (tester) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      textScale: 2.0,
      routines: [
        _routine(
          id: 1,
          title: 'Leaving the house',
          isPinned: true,
          steps: List.generate(5, (i) => _step('Step $i')),
        ),
        _routine(id: 2, title: 'Morning reset'),
        _routine(id: 3, title: 'Wind down'),
      ],
    );

    expect(tester.takeException(), isNull);

    // The wordmark stays on one line instead of breaking per letter.
    final wordmark = find.text('pebble.');
    expect(wordmark, findsOneWidget);
    expect(tester.getSize(wordmark).height, lessThan(60));

    // Start is reachable and comes before the routine list.
    final cta = find.byKey(const ValueKey('home_hero_cta_box'));
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pump();
    expect(tester.getTopLeft(cta).dy, greaterThanOrEqualTo(0));

    // The routine list grows its rows instead of clipping them.
    await tester.dragUntilVisible(
      find.text('Morning reset'),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('More routines')).dy,
      greaterThan(tester.getBottomLeft(cta).dy),
    );
    expect(find.text('Morning reset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone keeps Start visible while a routine is in '
      'progress', (tester) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(360, 640),
      viewPadding: const EdgeInsets.only(top: 24),
      routines: [
        _routine(
          id: 1,
          title: 'Leaving the house',
          steps: List.generate(5, (i) => _step('Step $i')),
        ),
        _routine(id: 2, title: 'Wind down'),
      ],
      resumeSessions: [
        RoutineSessionResumeSummary(
          sessionId: 's1',
          routineId: 2,
          routineTitleSnapshot: 'Wind down',
          currentStepIndex: 1,
          totalStepCount: 4,
          updatedAt: DateTime(2026, 10, 3),
        ),
      ],
      latestRun: _run(routineId: 1, finishedAt: DateTime(2026, 10, 3)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home_resume_card')), findsOneWidget);
    final cta = find.byKey(const ValueKey('home_hero_cta_box'));
    await tester.ensureVisible(cta);
    await tester.pump();
    expect(tester.getTopLeft(cta).dy, greaterThanOrEqualTo(0));
    await tester.dragUntilVisible(
      find.text('More routines'),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -160),
    );
    expect(find.text('More routines'), findsOneWidget);
  });

  testWidgets('home last-run line reports skipped steps', (tester) async {
    final finishedAt = DateTime(2026, 10, 3, 13, 27);
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      // Past the Checked window, so the hero is back to Start.
      clock: () => DateTime(2026, 10, 4, 9),
      routines: [
        _routine(
          id: 1,
          title: 'Morning reset',
          steps: List.generate(4, (i) => _step('Step $i')),
        ),
      ],
      latestRun: RoutineRun(
        id: 'run-1',
        routineId: '1',
        routineTitle: 'Morning reset',
        finishedAt: finishedAt,
        stepCompletionData: jsonEncode({
          'steps': [
            for (var i = 0; i < 4; i++)
              {'stepIndex': i, 'completed': i != 3, 'skipped': i == 3},
          ],
        }),
        ownerUserId: null,
        syncStatus: 'localOnly',
        lastSyncedAt: null,
        syncMetadataJson: null,
        updatedAt: finishedAt,
      ),
    );

    expect(find.textContaining('Last checked yesterday'), findsOneWidget);
    expect(find.textContaining('3 of 4 steps · 1 skipped'), findsNothing);
    expect(find.textContaining('4 of 4 steps'), findsNothing);
  });

  _checkedTests();
}

void _checkedTests() {
  group('checkedUntil (the Checked reset rule)', () {
    final at = DateTime(2026, 10, 3, 8, 4);

    test('with no reminder, a check stays Checked until 4am next day', () {
      expect(
        checkedUntil(at, DateTime(2026, 10, 3, 9)),
        DateTime(2026, 10, 4, 4),
      );
      expect(checkedUntil(at, DateTime(2026, 10, 3, 20)), isNotNull);
      expect(checkedUntil(at, DateTime(2026, 10, 4, 3, 59)), isNotNull);
      expect(checkedUntil(at, DateTime(2026, 10, 4, 4)), isNull);
    });

    test('the next reminder ends Checked: the routine is due again', () {
      final reminder = DateTime(2026, 10, 3, 18);
      expect(
        checkedUntil(at, DateTime(2026, 10, 3, 17), nextReminder: reminder),
        reminder,
      );
      expect(
        checkedUntil(at, DateTime(2026, 10, 3, 18), nextReminder: reminder),
        isNull,
      );
    });

    test('a reminder after the day boundary does not extend Checked', () {
      expect(
        checkedUntil(
          at,
          DateTime(2026, 10, 3, 9),
          nextReminder: DateTime(2026, 10, 4, 8),
        ),
        DateTime(2026, 10, 4, 4),
      );
    });

    test('a late check carries over to the small hours, not the morning', () {
      final late = DateTime(2026, 10, 3, 23, 30);
      expect(
        checkedUntil(late, DateTime(2026, 10, 4, 0, 10)),
        DateTime(2026, 10, 4, 4),
      );
      expect(checkedUntil(late, DateTime(2026, 10, 4, 8)), isNull);
    });

    test('nextReminderAt skips a reminder inside the grace period', () {
      // Done at 07:55 for an 08:00 reminder: Checked lasts until the
      // next one, not five minutes.
      final done = DateTime(2026, 10, 5, 7, 55); // a Monday
      final next = nextReminderAt([
        (1, '8:00 AM'),
        (1, '6:00 PM'),
      ], done.add(kCheckedReminderGrace));
      expect(next, DateTime(2026, 10, 5, 18));
    });
  });

  testWidgets('Home shows Checked with the time after a run', (tester) async {
    final finishedAt = DateTime(2026, 10, 3, 8, 4);
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      clock: () => DateTime(2026, 10, 3, 8, 30),
      routines: [
        _routine(
          id: 1,
          title: 'Leaving the house',
          steps: List.generate(5, (i) => _step('Step $i')),
        ),
      ],
      latestRun: _runWithSteps(routineId: 1, finishedAt: finishedAt, total: 5),
    );

    expect(find.byKey(const ValueKey('home_hero_status')), findsOneWidget);
    expect(find.textContaining('Checked today'), findsOneWidget);
    expect(find.text('Step 0'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
    // The status opens the check while the steps stay visible.
    await tester.tap(find.byKey(const ValueKey('home_hero_status')));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineRunDetailScreen), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Steps'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Checked names skipped steps', (tester) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      clock: () => DateTime(2026, 10, 3, 9),
      routines: [
        _routine(
          id: 1,
          title: 'Morning reset',
          steps: List.generate(4, (i) => _step('Step $i')),
        ),
      ],
      latestRun: _runWithSteps(
        routineId: 1,
        finishedAt: DateTime(2026, 10, 3, 8, 4),
        total: 4,
        skipped: {3},
      ),
    );

    expect(find.textContaining('Checked 3 of 4 · 1 skipped'), findsOneWidget);
    expect(find.text('Step 0'), findsOneWidget);
  });

  testWidgets('Checked goes back to Start at the cut-off while Home is open', (
    tester,
  ) async {
    final finishedAt = DateTime(2026, 10, 3, 8, 4);
    var now = DateTime(2026, 10, 4, 3, 55);
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      clock: () => now,
      routines: [
        _routine(id: 1, title: 'Leaving the house', steps: [_step('Door')]),
      ],
      latestRun: _runWithSteps(routineId: 1, finishedAt: finishedAt, total: 1),
    );
    expect(find.text('Run again'), findsOneWidget);

    now = DateTime(2026, 10, 4, 4);
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Run again'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
  });

  testWidgets('a saved run of the hero routine shows Resume, not Checked', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      clock: () => DateTime(2026, 10, 3, 9),
      routines: [
        _routine(
          id: 1,
          title: 'Leaving the house',
          steps: List.generate(5, (i) => _step('Step $i')),
        ),
      ],
      latestRun: _runWithSteps(
        routineId: 1,
        finishedAt: DateTime(2026, 10, 3, 8, 4),
        total: 5,
      ),
      resumeSessions: [
        RoutineSessionResumeSummary(
          sessionId: 's1',
          routineId: 1,
          routineTitleSnapshot: 'Leaving the house',
          currentStepIndex: 2,
          totalStepCount: 5,
          updatedAt: DateTime(2026, 10, 3, 8, 50),
        ),
      ],
    );

    expect(find.byKey(const ValueKey('home_hero_status')), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Saved at step 3 of 5'), findsOneWidget);
    // Its own run is in the hero, so no separate resume card.
    expect(find.byKey(const ValueKey('home_resume_card')), findsNothing);
  });

  testWidgets('the meta line names photos and the next reminder', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      routines: [
        _routine(
          id: 1,
          title: 'Leaving the house',
          steps: [
            _step('Stove off'),
            const RoutineStep.check(label: 'Back door', requiresPhoto: true),
          ],
        ),
      ],
      nextReminder: DateTime(2026, 10, 6, 8, 15),
    );

    expect(find.text('2 steps · 1 photo · Reminder 8:15 AM'), findsOneWidget);
  });

  test('backup shows as a dot on the avatar, none when off', () {
    HomeBackupDot dot(BackupPhase phase, {bool offline = false}) =>
        homeBackupDotFor(BackupStatus(phase: phase, offline: offline));
    expect(dot(BackupPhase.notIncluded), HomeBackupDot.none);
    expect(dot(BackupPhase.off), HomeBackupDot.none);
    expect(dot(BackupPhase.checking), HomeBackupDot.none);
    expect(dot(BackupPhase.upToDate), HomeBackupDot.backedUp);
    expect(dot(BackupPhase.waiting, offline: true), HomeBackupDot.none);
    expect(dot(BackupPhase.needsAttention), HomeBackupDot.paused);
    expect(dot(BackupPhase.paused), HomeBackupDot.paused);
  });

  test('next reminder picks the soonest enabled time', () {
    // Saturday 3 Oct 2026, 09:00.
    final now = DateTime(2026, 10, 3, 9);
    expect(
      nextReminderAt([(1, '8:15 AM'), (6, '10:00 PM'), (6, '8:15 AM')], now),
      DateTime(2026, 10, 3, 22),
    );
    expect(
      nextReminderAt([(1, '8:15 AM'), (5, '10:00 PM')], now),
      DateTime(2026, 10, 5, 8, 15),
    );
    expect(nextReminderAt(const [], now), isNull);
    expect(parseReminderTime('12:05 AM'), (0, 5));
    expect(parseReminderTime('20:15'), (20, 15));
  });
}

RoutineRun _runWithSteps({
  required int routineId,
  required DateTime finishedAt,
  required int total,
  Set<int> skipped = const {},
}) {
  return RoutineRun(
    id: 'run-$routineId',
    routineId: '$routineId',
    routineTitle: 'Routine $routineId',
    finishedAt: finishedAt,
    stepCompletionData: jsonEncode({
      'steps': [
        for (var i = 0; i < total; i++)
          {
            'stepIndex': i,
            'completed': !skipped.contains(i),
            'skipped': skipped.contains(i),
            'photos': <String>[],
          },
      ],
    }),
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: finishedAt,
  );
}

List<Override> _homeOverrides({
  required List<Routine> routines,
  required List<RoutineRun> runs,
  HomeRoutineHighlight? highlight,
  RoutineRepository? routineRepository,
  List<RoutineSessionResumeSummary> resumeSessions = const [],
  RoutineRun? latestRun,
  DateTime Function()? clock,
  DateTime? nextReminder,
  Duration? historyWindow,
}) {
  final repository = routineRepository ?? _FakeRoutineRepository(routines);
  return [
    if (clock != null) homeClockProvider.overrideWithValue(clock),
    routineNextReminderProvider.overrideWith(
      (ref, routineId) => Stream.value(nextReminder),
    ),
    currentThemeDataProvider.overrideWithValue(
      AppTheme.fromId(ThemeId.highNoon),
    ),
    currentColorThemeProvider.overrideWithValue(ThemeId.highNoon),
    routineListProvider.overrideWith((ref) => Stream.value(routines)),
    routineRepositoryProvider.overrideWithValue(repository),
    storedRoutineRunsProvider.overrideWith((ref) => Stream.value(runs)),
    if (historyWindow != null)
      accountHistoryRetentionProvider.overrideWithValue(historyWindow),
    activeRoutineSessionsProvider.overrideWith(
      (ref) => Stream.value(resumeSessions),
    ),
    latestRoutineRunProvider.overrideWith(
      (ref, routineId) => Stream.value(latestRun),
    ),
    sharedPreferencesProvider.overrideWithValue(_prefs),
    routineComposerDraftRepositoryProvider.overrideWithValue(
      FakeRoutineComposerDraftRepository(),
    ),
    homeRoutineHighlightProvider.overrideWith((ref) => highlight),
    accountBackupChipStateProvider.overrideWithValue(
      const AccountBackupChipState.hidden(),
    ),
    homeWidgetHostProvider.overrideWithValue(const _NoWidgetsHost()),
  ];
}

/// A launcher with no Pebble widget placed and no "Add widget" prompt.
class _NoWidgetsHost extends HomeWidgetHost {
  const _NoWidgetsHost();

  @override
  Future<int?> installedWidgetCount() async => 0;

  @override
  Future<bool> canRequestPinWidget() async => false;
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Routine> routines,
  List<RoutineRun> runs = const [],
  HomeRoutineHighlight? highlight,
  Size? surfaceSize,
  double textScale = 1,
  RoutineRepository? routineRepository,
  List<RoutineSessionResumeSummary> resumeSessions = const [],
  RoutineRun? latestRun,
  EdgeInsets viewPadding = EdgeInsets.zero,
  DateTime Function()? clock,
  DateTime? nextReminder,
  Duration? historyWindow,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget home = const RoutineListScreen();
  if (textScale != 1 || viewPadding != EdgeInsets.zero) {
    home = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: viewPadding,
          viewPadding: viewPadding,
        ),
        child: const RoutineListScreen(),
      ),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: _homeOverrides(
        routines: routines,
        runs: runs,
        highlight: highlight,
        routineRepository: routineRepository,
        resumeSessions: resumeSessions,
        latestRun: latestRun,
        clock: clock,
        nextReminder: nextReminder,
        historyWindow: historyWindow,
      ),
      child: MaterialApp(theme: AppTheme.fromId(ThemeId.highNoon), home: home),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(List<Routine> routines)
    : _routines = {for (final routine in routines) routine.id: routine};

  final Map<int, Routine> _routines;
  final List<(int, bool)> pinnedUpdates = [];
  final List<(int, RoutineMoveDirection)> moves = [];

  @override
  Stream<List<Routine>> watchRoutines() =>
      Stream.value(_routines.values.toList());

  @override
  Future<void> normalizeLegacyRoutineIcons() async {}

  @override
  Future<Routine?> getRoutineById(int id) async => _routines[id];

  @override
  Future<void> saveRoutine(Routine routine) async {
    _routines[routine.id] = routine;
  }

  @override
  Future<void> deleteRoutine(int id) async {
    _routines.remove(id);
  }

  @override
  Future<void> deleteRoutineReminder(RoutineReminder reminder) async {}

  @override
  Future<void> deleteRoutineRemindersForRoutine(int routineId) async {}

  @override
  Future<void> deleteAllRoutineReminders() async {}

  @override
  Future<Routine> duplicateRoutine(int id) async => _routines[id]!;

  @override
  Future<(int?, String?)> getRoutineReminder(int id) async {
    final routine = _routines[id];
    return (routine?.reminderDay, routine?.reminderTime);
  }

  @override
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async {
    moves.add((id, direction));
    return true;
  }

  @override
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {}

  @override
  Future<void> updateRoutinePinned(int id, bool isPinned) async {
    pinnedUpdates.add((id, isPinned));
    final routine = _routines[id];
    if (routine == null) return;
    _routines[id] = routine.copyWith(
      isPinned: isPinned,
      pinnedAt: Value(isPinned ? DateTime(2026, 6, 11) : null),
    );
  }

  @override
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  }) async {}

  @override
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId) {
    return Stream.value(null);
  }
}

Routine _routine({
  required int id,
  required String title,
  bool isPinned = false,
  List<RoutineStep> steps = const [],
}) {
  final createdAt = DateTime(2026, 4, id);
  return Routine(
    id: id,
    title: title,
    stepsJson: jsonEncode(steps.map((step) => step.toJson()).toList()),
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

RoutineStep _step(String label) => RoutineStep.check(label: label);

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

class _AiOn implements RoutineAiClient {
  @override
  Future<RoutineAiStatus> status() async =>
      const RoutineAiStatus(enabled: true);

  @override
  Future<RoutineAiReply> build({
    required String buildKey,
    required String description,
    List<RoutineAiAnswer> answers = const [],
    bool askQuestions = false,
  }) async => const RoutineAiReply.refused('featureOff');
}
