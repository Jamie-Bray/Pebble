import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/creator/ui/create_routine_hub_sheet.dart';

import '../composer/fake_routine_composer_draft_repository.dart';

void main() {
  Future<void> pumpCreateHubApp(
    WidgetTester tester,
    FakeRoutineComposerDraftRepository repository,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => CreateHubSheet.show(context),
                  child: const Text('Open create'),
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/creator',
          builder: (context, state) {
            final isFresh = state.uri.queryParameters['fresh'] == '1';
            return Scaffold(
              body: Center(
                child: Text(isFresh ? 'Fresh composer' : 'Resume composer'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/templates',
          builder: (context, state) {
            return const Scaffold(body: Center(child: Text('Templates')));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineComposerDraftRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.fromId(ThemeId.nordicNight),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedMeaningfulDraft(
    FakeRoutineComposerDraftRepository repository,
  ) async {
    await repository.createDraft(
      seedData: const RoutineComposerSeedData(
        title: 'School morning',
        iconKey: 'sparkles',
        colorHex: null,
        steps: [
          RoutineComposerStepDraft(
            id: 'step-1',
            text: 'Pack bag',
            requiresPhoto: false,
            allowSkip: false,
            sortOrder: 0,
          ),
        ],
      ),
    );
  }

  testWidgets(
    'Create sheet shows Resume draft when a meaningful draft exists',
    (tester) async {
      final repository = FakeRoutineComposerDraftRepository();
      await seedMeaningfulDraft(repository);
      await pumpCreateHubApp(tester, repository);

      await tester.tap(find.text('Open create'));
      await tester.pumpAndSettle();

      expect(find.text('Resume draft'), findsOneWidget);
      expect(find.textContaining('School morning'), findsOneWidget);
    },
  );

  testWidgets('Blank routine with a draft opens the draft choice sheet', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    await seedMeaningfulDraft(repository);
    await pumpCreateHubApp(tester, repository);

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank routine'));
    await tester.pumpAndSettle();

    expect(find.text('Resume draft?'), findsOneWidget);
    expect(find.text('Start fresh'), findsOneWidget);
    expect(find.text('Discard draft'), findsOneWidget);
  });

  testWidgets('Start fresh clears the old draft and opens a fresh composer', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    await seedMeaningfulDraft(repository);
    await pumpCreateHubApp(tester, repository);

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start fresh'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh composer'), findsOneWidget);
    expect(await repository.latestCreateDraft(), isNull);
    expect(repository.clearCreateDraftsCallCount, 1);
  });

  testWidgets('Discard draft removes the resume option from Create', (
    tester,
  ) async {
    final repository = FakeRoutineComposerDraftRepository();
    await seedMeaningfulDraft(repository);
    await pumpCreateHubApp(tester, repository);

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blank routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(await repository.latestCreateDraft(), isNull);
    expect(find.text('Blank routine'), findsOneWidget);
    expect(find.text('Resume draft'), findsNothing);
  });
}
