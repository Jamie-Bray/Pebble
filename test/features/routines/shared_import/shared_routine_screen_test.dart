import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/share/shared_routine_link.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/shared_import/shared_routine_screen.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/premium_policy_test_utils.dart';

const _shared = SharedRoutine(
  title: 'House sitter handover',
  steps: [
    RoutineStep.check(label: 'Water the plants'),
    RoutineStep.info(message: 'Spare key is under the blue pot'),
    RoutineStep.check(label: 'Lock the back door', requiresPhoto: true),
  ],
);

Future<_FakeRoutineRepository> _pump(
  WidgetTester tester, {
  required String location,
  bool onboarded = true,
  UserTier tier = UserTier.personalPremium,
  int existingRoutines = 0,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_completed_onboarding': onboarded,
  });
  final prefs = await SharedPreferences.getInstance();
  final repository = _FakeRoutineRepository();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Text(
              ref.watch(homeRoutineHighlightProvider)?.message ?? 'Home',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const Scaffold(body: Text('Onboarding')),
      ),
      GoRoute(
        path: sharedRoutinePath,
        builder: (context, state) =>
            SharedRoutineScreen(data: state.uri.queryParameters['d']),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routineRepositoryProvider.overrideWithValue(repository),
        routineListProvider.overrideWith(
          (ref) => Stream.value([
            for (var i = 0; i < existingRoutines; i++)
              Routine(
                id: i,
                title: 'R$i',
                stepsJson: '[]',
                createdAt: DateTime(2026),
                isPinned: false,
                version: 1,
                updatedAt: DateTime(2026),
                syncStatus: 'localOnly',
              ),
          ]),
        ),
        subscriptionProvider.overrideWithValue(tier),
        premiumFeaturePolicyProvider.overrideWithValue(
          premiumFeaturePolicyForTier(tier),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.fromId(ThemeId.highNoon),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('shows the shared steps and adds the routine', (tester) async {
    final repository = await _pump(
      tester,
      location: sharedRoutineLocation(_shared),
    );

    expect(find.text('SHARED WITH YOU'), findsOneWidget);
    expect(find.text('House sitter handover'), findsOneWidget);
    expect(find.text('Water the plants'), findsOneWidget);
    expect(find.text('Spare key is under the blue pot'), findsOneWidget);
    expect(find.text('With a photo'), findsOneWidget);
    expect(repository.saved, isEmpty);

    await tester.tap(find.byKey(const ValueKey('shared_routine_add')));
    await tester.pumpAndSettle();

    expect(find.text('House sitter handover is ready'), findsOneWidget);
    final saved = repository.saved.single;
    expect(saved.title, 'House sitter handover');
    final steps = [
      for (final raw in jsonDecode(saved.stepsJson) as List)
        RoutineStep.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    expect(steps, _shared.steps);
  });

  testWidgets('a new install can add it before onboarding', (tester) async {
    final repository = await _pump(
      tester,
      location: sharedRoutineLocation(_shared),
      onboarded: false,
    );
    await tester.tap(find.byKey(const ValueKey('shared_routine_add')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_completed_onboarding'), isTrue);
  });

  testWidgets('"Not now" saves nothing', (tester) async {
    final repository = await _pump(
      tester,
      location: sharedRoutineLocation(_shared),
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('the free routine limit still applies', (tester) async {
    final repository = await _pump(
      tester,
      location: sharedRoutineLocation(_shared),
      tier: UserTier.personalFree,
      existingRoutines: 2,
    );
    await tester.tap(find.byKey(const ValueKey('shared_routine_add')));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
  });

  testWidgets('a broken link explains itself', (tester) async {
    await _pump(tester, location: '$sharedRoutinePath?d=broken');
    expect(find.text("This link doesn't work"), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  final saved = <Routine>[];

  @override
  Future<void> saveRoutine(Routine routine) async => saved.add(routine);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
