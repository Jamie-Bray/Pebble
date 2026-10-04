import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_screen.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_player_screen.dart';
import 'package:pebble_routines/features/history/domain/checked_window.dart';
import 'package:pebble_routines/features/routines/list/providers/home_hero_state_provider.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/list/ui/home_hero_widgets.dart';
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
    // The unlabelled bell/mail/gear bar is gone: a meta line opens the
    // routine's actions instead.
    expect(find.byTooltip('Reminders'), findsNothing);
    expect(find.byTooltip('Email'), findsNothing);
    expect(find.byTooltip('Routine settings'), findsOneWidget);
    expect(find.text('2 steps'), findsOneWidget);
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
    // "4 steps" is the meta line, between the title and the steps preview.
    expect(find.text('4 steps'), findsOneWidget);
    final metaLineTop = tester
        .getTopLeft(find.byKey(const ValueKey('home_hero_routine_meta')))
        .dy;
    expect(metaLineTop, greaterThan(titleBottom));

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
    expect(
      metaLineTop,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('home_hero_preview_card')))
            .dy,
      ),
    );
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
    expect(settingsCog, findsNothing);
    expect(previewHeaderReminders, findsNothing);
    expect(previewHeaderEmail, findsNothing);
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
    expect(find.byTooltip('Routine settings'), findsOneWidget);
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

    await tester.ensureVisible(find.text('Pin to Widget'));
    await tester.pump();
    await tester.tap(find.text('Pin to Widget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.pinnedUpdates, equals([(1, true)]));
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
    await tester.tap(find.text('Your Routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final list = tester.widget<SliverReorderableList>(
      find.byType(SliverReorderableList),
    );
    expect(list.itemCount, 5);

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
      expect(find.text('Pin to Widget'), findsNothing);
      expect(find.text('Unpin from Widget'), findsNothing);
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
    expect(tester.getSize(wordmark).height, lessThan(40));

    // Start is on screen, above the routine shelf, without scrolling.
    final cta = find.byKey(const ValueKey('home_hero_cta_box'));
    expect(cta, findsOneWidget);
    final ctaBottom = tester.getBottomLeft(cta).dy;
    final shelfTop = tester.getTopLeft(find.text('Your Routines')).dy;
    expect(ctaBottom, lessThan(shelfTop));
    expect(tester.getTopLeft(cta).dy, greaterThan(0));

    // The expanded routine list grows its rows instead of clipping them.
    await tester.tap(find.text('Your Routines'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
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
    final ctaBottom = tester.getBottomLeft(cta).dy;
    final shelfTop = tester.getTopLeft(find.text('Your Routines')).dy;
    expect(ctaBottom, lessThan(shelfTop));
    final metaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('home_hero_meta_row')))
        .dy;
    expect(metaBottom, lessThanOrEqualTo(shelfTop));
  });

  testWidgets('home last-run line reports skipped steps', (tester) async {
    final finishedAt = DateTime.now().subtract(const Duration(hours: 3));
    await _pumpHome(
      tester,
      surfaceSize: const Size(390, 844),
      // Past the Checked window, so the hero is back to Start.
      clock: () => finishedAt.add(const Duration(days: 1)),
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

    expect(find.text('Last completed 3h ago'), findsOneWidget);
    expect(find.text('3 of 4 steps · 1 skipped'), findsOneWidget);
    expect(find.text('4 of 4 steps'), findsNothing);
  });

  _checkedTests();
}


void _checkedTests() {
  group('checkedUntil (the Checked reset rule)', () {
    final at = DateTime(2026, 10, 3, 8, 4);

    test('a run from earlier today, under six hours ago, is Checked', () {
      expect(checkedUntil(at, DateTime(2026, 10, 3, 9)), at.add(kCheckedWindow));
      expect(checkedUntil(at, DateTime(2026, 10, 3, 14, 3)), isNotNull);
    });

    test('six hours after the run it is back to Start', () {
      expect(checkedUntil(at, DateTime(2026, 10, 3, 14, 4)), isNull);
      expect(checkedUntil(at, DateTime(2026, 10, 3, 20)), isNull);
    });

    test('a late check never carries over past midnight', () {
      final late = DateTime(2026, 10, 3, 23, 30);
      expect(checkedUntil(late, DateTime(2026, 10, 3, 23, 50)),
          DateTime(2026, 10, 4));
      expect(checkedUntil(late, DateTime(2026, 10, 4, 0, 10)), isNull);
    });

    test('a run from another day is never Checked', () {
      expect(checkedUntil(at, DateTime(2026, 10, 4, 8)), isNull);
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

    expect(find.byKey(const ValueKey('home_hero_checked_card')), findsOneWidget);
    expect(find.text('CHECKED'), findsOneWidget);
    // The time is the hero, in the big serif.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PebbleBigTime && widget.at == finishedAt,
      ),
      findsOneWidget,
    );
    expect(find.text('Leaving the house · all 5 steps'), findsOneWidget);
    // Run again is tonal: no filled Start competing with the answer.
    expect(find.text('Run again'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.text('YOUR NEXT RIPPLE'), findsNothing);
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

    expect(find.text('CHECKED · 1 SKIPPED'), findsOneWidget);
    expect(find.text('Morning reset · 3 of 4 steps'), findsOneWidget);
  });

  testWidgets('Checked goes back to Start at the cut-off while Home is open', (
    tester,
  ) async {
    final finishedAt = DateTime(2026, 10, 3, 8, 4);
    var now = DateTime(2026, 10, 3, 14);
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

    now = DateTime(2026, 10, 3, 14, 5);
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Run again'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('YOUR NEXT RIPPLE'), findsOneWidget);
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

    expect(find.byKey(const ValueKey('home_hero_checked_card')), findsNothing);
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
    AccountBackupChipState chip(String label, AccountBackupChipTone tone) =>
        AccountBackupChipState(
          show: true,
          label: label,
          tone: tone,
          semanticsHint: '',
        );
    expect(
      homeBackupDotFor(const AccountBackupChipState.hidden()),
      HomeBackupDot.none,
    );
    expect(
      homeBackupDotFor(chip('Backup off', AccountBackupChipTone.neutral)),
      HomeBackupDot.none,
    );
    expect(
      homeBackupDotFor(chip('Checking backup', AccountBackupChipTone.neutral)),
      HomeBackupDot.none,
    );
    expect(
      homeBackupDotFor(chip('Backed up · 4m', AccountBackupChipTone.positive)),
      HomeBackupDot.backedUp,
    );
    expect(
      homeBackupDotFor(chip('Offline', AccountBackupChipTone.neutral)),
      HomeBackupDot.paused,
    );
    expect(
      homeBackupDotFor(chip('Needs attention', AccountBackupChipTone.attention)),
      HomeBackupDot.paused,
    );
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
    routineHistoryVmProvider.overrideWith((ref) => Stream.value(runs)),
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
  List<RoutineSessionResumeSummary> resumeSessions = const [],
  RoutineRun? latestRun,
  EdgeInsets viewPadding = EdgeInsets.zero,
  DateTime Function()? clock,
  DateTime? nextReminder,
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
