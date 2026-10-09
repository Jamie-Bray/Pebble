import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/onboarding/ui/first_routine_screen.dart';
import 'package:pebble_routines/features/onboarding/ui/onboarding_screen.dart';
import 'package:pebble_routines/features/routine_ai/routine_ai_service.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAi implements RoutineAiClient {
  _FakeAi(this._status);

  final RoutineAiStatus _status;

  @override
  Future<RoutineAiStatus> status() async => _status;

  @override
  Future<RoutineAiReply> build({
    required String buildKey,
    required String description,
    List<RoutineAiAnswer> answers = const [],
    bool askQuestions = false,
  }) async => const RoutineAiReply.refused('featureOff');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'welcome side quest continues to how a check works without completing setup',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineAiClientProvider.overrideWithValue(
              _FakeAi(RoutineAiStatus.off),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.fromId(ThemeId.highNoon),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('See what Pebble can do'));
      // The explainer has a continuously pulsing "current step" indicator, so
      // pumpAndSettle would never settle. Pump fixed frames instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Every check is saved with the time.'), findsOneWidget);
      expect(prefs.getBool('has_completed_onboarding'), isFalse);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // No theme step and no practice run: one example step with circles.
      expect(find.text('One step at a time'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Stove and oven dials off'), findsOneWidget);
      expect(prefs.getBool('has_completed_onboarding'), isFalse);
    },
  );

  testWidgets('three taps through the circles go to "Time to build your own"', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': false});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(initialPage: 1),
        ),
        GoRoute(
          path: '/first-routine',
          builder: (context, state) => const FirstRoutineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routineAiClientProvider.overrideWithValue(
            _FakeAi(const RoutineAiStatus(enabled: true)),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.fromId(ThemeId.highNoon),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One step at a time'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Photo steps'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Tick it off'), findsOneWidget);
    expect(prefs.getBool('has_completed_onboarding'), isFalse);
    await tester.tap(find.text('Build your first routine'));
    await tester.pumpAndSettle();

    expect(prefs.getBool('has_completed_onboarding'), isTrue);
    expect(find.text('Time to build\nyour own.'), findsOneWidget);
  });

  testWidgets('skipping the circles goes to "Time to build your own"', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': false});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(initialPage: 1),
        ),
        GoRoute(
          path: '/first-routine',
          builder: (context, state) => const FirstRoutineScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routineAiClientProvider.overrideWithValue(
            _FakeAi(const RoutineAiStatus(enabled: true)),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.fromId(ThemeId.highNoon),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(prefs.getBool('has_completed_onboarding'), isTrue);
    expect(find.text('Time to build\nyour own.'), findsOneWidget);
    expect(find.text('Build it with AI'), findsOneWidget);
    expect(find.textContaining('free'), findsNothing);
    expect(find.text('Pick a template'), findsOneWidget);
    expect(find.text('Start from scratch'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('with AI switched off, only template and scratch are offered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineAiClientProvider.overrideWithValue(
            _FakeAi(RoutineAiStatus.off),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const FirstRoutineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Build it with AI'), findsNothing);
    expect(find.text('Pick a template'), findsOneWidget);
    expect(find.text('Start from scratch'), findsOneWidget);
  });

  testWidgets('a used free build points to Personal Premium', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineAiClientProvider.overrideWithValue(
            _FakeAi(const RoutineAiStatus(enabled: true, freeBuildUsed: true)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const FirstRoutineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Build more routines with AI with Personal Premium.'),
      findsOneWidget,
    );
  });
}
