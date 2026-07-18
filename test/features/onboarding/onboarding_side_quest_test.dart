import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/onboarding/ui/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'welcome side quest continues to theme without completing setup',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.fromId(ThemeId.highNoon),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('What can Pebble do?'));
      // The explainer has a continuously pulsing "current step" indicator, so
      // pumpAndSettle would never settle. Pump fixed frames instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Step out the door with total confidence.'),
        findsOneWidget,
      );
      expect(prefs.getBool('has_completed_onboarding'), isFalse);

      await tester.tap(find.text('Continue onboarding'));
      await tester.pump();
      // Let the route pop and PageView transition run; once the explainer is
      // disposed the looping animation is gone and we can settle the rest.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Choose a look\nthat works for you.'), findsOneWidget);
      expect(prefs.getBool('has_completed_onboarding'), isFalse);
    },
  );

  testWidgets(
    'tapping a starter card opens its preview without completing setup',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.fromId(ThemeId.highNoon),
            home: const OnboardingScreen(initialPage: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick a routine\nto start with.'), findsOneWidget);

      await tester.tap(find.text('Medication Check'));
      await tester.pumpAndSettle();

      expect(find.text("Here's how this could work"), findsOneWidget);
      expect(find.text('Use this starter routine'), findsOneWidget);
      expect(find.text('Pick another starting point'), findsOneWidget);
      expect(prefs.getBool('has_completed_onboarding'), isFalse);

      await tester.tap(find.text('Pick another starting point'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a routine\nto start with.'), findsOneWidget);
    },
  );

  testWidgets('start from scratch is part of the scrollable choice list', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const OnboardingScreen(initialPage: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scratch = find.text('Start from scratch');
    expect(scratch, findsOneWidget);
    expect(find.text('Start from scratch instead'), findsNothing);
    expect(
      find.ancestor(of: scratch, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );

    await tester.ensureVisible(scratch);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
