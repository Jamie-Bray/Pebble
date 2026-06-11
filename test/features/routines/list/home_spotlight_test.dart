import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/ui/routine_list_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
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
    expect(find.text('Create routine'), findsOneWidget);
    expect(find.text('Use template'), findsOneWidget);
    expect(find.byTooltip('Reminders'), findsNothing);
    expect(find.text('Life flows better\nwith routines'), findsNothing);
    expect(find.textContaining('organized humans'), findsNothing);
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

    expect(find.text('YOUR NEXT RIPPLE'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Last Run.'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.byTooltip('App settings'), findsOneWidget);
    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(find.byTooltip('Reminders'), findsOneWidget);
    expect(find.byTooltip('Email'), findsOneWidget);
    expect(find.text('2 steps'), findsNothing);
    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('2 routines'), findsOneWidget);
    expect(find.text('Last Run'), findsNothing);
    expect(find.text('Newest'), findsNothing);
    await tester.tap(find.text('Your Routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('Last Run'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);

    await tester.drag(find.text('Your Routines'), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('Newest'), findsNothing);

    await tester.drag(find.text('Your Routines'), const Offset(0, -90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Newest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Newest.'), findsOneWidget);
    expect(find.text('Your Routines'), findsWidgets);
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
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('Leaving Home'), findsNothing);
    expect(find.text('Add step'), findsNothing);
    expect(find.text('Style'), findsNothing);

    await tester.tap(find.text('Your Routines'));
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
    expect(find.text('Your Routines'), findsOneWidget);
    expect(find.text('7 routines'), findsOneWidget);

    await tester.tap(find.text('Your Routines'));
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

  testWidgets('hero layout is ordered, stable, and above the routine shelf', (
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
      ],
    );

    final headerBottom = tester
        .getBottomLeft(find.text('Small steps, big ripples'))
        .dy;
    final overlineTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_overline')))
        .dy;
    expect(overlineTop - headerBottom, greaterThanOrEqualTo(16));

    final overlineBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_overline')))
        .dy;
    final titleTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_title')))
        .dy;
    expect(titleTop - overlineBottom, closeTo(10, 1));

    final titleBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_title')))
        .dy;
    expect(find.text('Settings'), findsNothing);
    expect(find.byKey(const ValueKey('home_hero_action_strip')), findsNothing);
    expect(find.text('4 steps'), findsNothing);

    final previewTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_preview_card')))
        .dy;
    expect(previewTop, greaterThan(titleBottom));

    final headerTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_preview_header')))
        .dy;
    final metaTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_meta_row')))
        .dy;
    final settingsCog = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_header')),
      matching: find.byTooltip('Routine settings'),
    );
    final previewHeaderReminders = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_header')),
      matching: find.byTooltip('Reminders'),
    );
    final previewHeaderEmail = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_header')),
      matching: find.byTooltip('Email'),
    );
    final previewCardReminders = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_card')),
      matching: find.text('Reminders'),
    );
    final previewCardEmail = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_card')),
      matching: find.text('Email'),
    );
    final previewMask = find.descendant(
      of: find.byKey(const ValueKey('home_hero_preview_card')),
      matching: find.byType(ShaderMask),
    );
    expect(find.text('Steps'), findsOneWidget);
    expect(settingsCog, findsOneWidget);
    expect(previewHeaderReminders, findsOneWidget);
    expect(previewHeaderEmail, findsOneWidget);
    expect(previewCardReminders, findsNothing);
    expect(previewCardEmail, findsNothing);
    expect(previewMask, findsNothing);
    expect(headerTop, greaterThanOrEqualTo(previewTop));

    final previewBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_preview_card')))
        .dy;
    expect(metaTop, greaterThan(previewBottom));

    final ctaTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    expect(ctaTop, greaterThan(previewBottom));
    expect(metaTop, greaterThan(ctaTop));

    final ctaSize = tester.getSize(
      find.byKey(const ValueKey('home_hero_cta_box')),
    );
    expect(ctaSize.height, greaterThanOrEqualTo(56));

    final ctaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    final shelfTop = tester.getTopLeft(find.text('Your Routines')).dy;
    expect(ctaBottom, lessThan(shelfTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero preview viewport height is stable for long routines', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      routines: [
        _routine(id: 1, title: 'Short Routine', steps: [_step('One thing')]),
      ],
    );

    await tester.tap(find.byTooltip('Show steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final shortHeight = tester
        .getSize(find.byKey(const ValueKey('home_hero_preview_card')))
        .height;

    await _pumpHome(
      tester,
      routines: [
        _routine(
          id: 1,
          title: 'Long Routine',
          steps: List.generate(12, (index) => _step('Long step ${index + 1}')),
        ),
      ],
    );

    final longHeight = tester
        .getSize(find.byKey(const ValueKey('home_hero_preview_card')))
        .height;
    expect(longHeight, shortHeight);

    final ctaTopBefore = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    final headerTopBefore = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_preview_header')))
        .dy;
    final metaTopBefore = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_meta_row')))
        .dy;
    await tester.drag(
      find.byKey(const ValueKey('home_hero_preview_list')),
      const Offset(0, -420),
    );
    await tester.pump();

    final ctaTopAfter = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    final heightAfterScroll = tester
        .getSize(find.byKey(const ValueKey('home_hero_preview_card')))
        .height;
    final headerTopAfter = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_preview_header')))
        .dy;
    final metaTopAfter = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_meta_row')))
        .dy;
    expect(heightAfterScroll, longHeight);
    expect(ctaTopAfter, ctaTopBefore);
    expect(headerTopAfter, headerTopBefore);
    expect(metaTopAfter, metaTopBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home Steps collapses and expands', (tester) async {
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

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Check windows'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byTooltip('Show steps'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);

    await tester.tap(find.byTooltip('Show steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Check windows'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byTooltip('Hide steps'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.tap(find.byTooltip('Hide steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Check windows'), findsNothing);
    expect(find.byTooltip('Show steps'), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed home Steps persists after rebuild', (tester) async {
    final routines = [
      _routine(
        id: 1,
        title: 'Departure Check',
        steps: [_step('Check windows'), _step('Pack wallet')],
      ),
    ];

    await _pumpHome(tester, routines: routines);
    expect(find.text('Check windows'), findsNothing);

    await tester.tap(find.byTooltip('Show steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Check windows'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Check windows'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpHome(tester, routines: routines);

    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Check windows'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byTooltip('Show steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a preview step opens edit routine at that step', (
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

    await tester.tap(find.byTooltip('Show steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.drag(
      find.byKey(const ValueKey('home_hero_preview_list')),
      const Offset(0, -90),
    );
    await tester.pump();

    expect(find.byTooltip('Edit step: Pack wallet'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit step: Pack wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RoutineComposerScreen), findsOneWidget);
    expect(find.byType(RoutinePlayerScreen), findsNothing);

    final targetField = _composerStepField('Pack wallet');
    expect(targetField, findsOneWidget);
    expect(tester.widget<TextField>(targetField).focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long preview scrolls and tapped rows still deep-link', (
    tester,
  ) async {
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

    await tester.tap(find.byTooltip('Show steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final previewHeightBefore = tester
        .getSize(find.byKey(const ValueKey('home_hero_preview_card')))
        .height;

    final targetTooltip = find.byTooltip('Edit step: Long step 8');
    await tester.dragUntilVisible(
      targetTooltip,
      find.byKey(const ValueKey('home_hero_preview_list')),
      const Offset(0, -80),
      maxIteration: 20,
    );
    await tester.pump();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('home_hero_preview_card')))
          .height,
      previewHeightBefore,
    );

    expect(targetTooltip, findsOneWidget);

    await tester.tap(targetTooltip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(RoutineComposerScreen), findsOneWidget);
    expect(find.byType(RoutinePlayerScreen), findsNothing);

    final targetField = _composerStepField('Long step 8', skipOffstage: false);
    expect(targetField, findsOneWidget);
    expect(tester.widget<TextField>(targetField).focusNode?.hasFocus, isTrue);
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
      expect(find.text('Car Security & Parking Peace'), findsNothing);

      await tester.tap(find.text('Your Routines'));
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

    expect(find.text('YOUR NEXT RIPPLE'), findsOneWidget);
    expect(find.text('Morning Reset.'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.byTooltip('App settings'), findsOneWidget);
    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(find.byTooltip('Reminders'), findsOneWidget);
    expect(find.byTooltip('Email'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
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
      ],
    );

    expect(find.text('Start'), findsOneWidget);
    final ctaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_cta_box')))
        .dy;
    final shelfTop = tester.getTopLeft(find.text('Your Routines')).dy;
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

    expect(find.text('Pin to Widget'), findsOneWidget);
    expect(find.text('Show this routine on your home widget'), findsOneWidget);

    await tester.tap(find.text('Pin to Widget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.pinnedUpdates, equals([(1, true)]));
  });
}

List<Override> _homeOverrides({
  required List<Routine> routines,
  required List<RoutineRun> runs,
  HomeRoutineHighlight? highlight,
  RoutineRepository? routineRepository,
}) {
  final repository = routineRepository ?? _FakeRoutineRepository(routines);
  return [
    currentThemeDataProvider.overrideWithValue(
      AppTheme.fromId(ThemeId.highNoon),
    ),
    currentColorThemeProvider.overrideWithValue(ThemeId.highNoon),
    routineListProvider.overrideWith((ref) => Stream.value(routines)),
    routineRepositoryProvider.overrideWithValue(repository),
    routineHistoryVmProvider.overrideWith((ref) => Stream.value(runs)),
    activeRoutineSessionsProvider.overrideWith((ref) => Stream.value(const [])),
    latestRoutineRunProvider.overrideWith(
      (ref, routineId) => Stream.value(null),
    ),
    sharedPreferencesProvider.overrideWithValue(_prefs),
    routineComposerDraftRepositoryProvider.overrideWithValue(
      FakeRoutineComposerDraftRepository(),
    ),
    homeRoutineHighlightProvider.overrideWith((ref) => highlight),
    accountBackupChipStateProvider.overrideWithValue(
      const AccountBackupChipState.hidden(),
    ),
  ];
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Routine> routines,
  List<RoutineRun> runs = const [],
  HomeRoutineHighlight? highlight,
  Size? surfaceSize,
  double textScale = 1,
  RoutineRepository? routineRepository,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget home = const RoutineListScreen();
  if (textScale != 1) {
    home = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: home,
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: _homeOverrides(
        routines: routines,
        runs: runs,
        highlight: highlight,
        routineRepository: routineRepository,
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

  @override
  Stream<List<Routine>> watchRoutines() =>
      Stream.value(_routines.values.toList());

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
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async =>
      true;

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

Finder _composerStepField(String value, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller?.text == value,
    skipOffstage: skipOffstage,
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
