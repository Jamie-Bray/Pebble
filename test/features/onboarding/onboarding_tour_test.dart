import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/features/onboarding/data/onboarding_tour.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/routines/list/ui/reminder_editor_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingTour', () {
    test('shows no hints to people who never saw the new onboarding', () async {
      SharedPreferences.setMockInitialValues({});
      final tour = OnboardingTour(await SharedPreferences.getInstance());

      expect(tour.hintsEnabled, isFalse);
      for (final hint in PebbleHint.values) {
        expect(tour.shouldShow(hint), isFalse);
      }
    });

    test('shows each hint once after onboarding starts the tour', () async {
      SharedPreferences.setMockInitialValues({});
      final tour = OnboardingTour(await SharedPreferences.getInstance());
      await tour.start();

      expect(tour.shouldShow(PebbleHint.routineSettings), isTrue);
      await tour.markSeen(PebbleHint.routineSettings);
      expect(tour.shouldShow(PebbleHint.routineSettings), isFalse);
      expect(tour.shouldShow(PebbleHint.playerTick), isTrue);

      // Replaying the intro brings every hint back.
      await tour.start();
      expect(tour.shouldShow(PebbleHint.routineSettings), isTrue);
    });

    test('suggests Style only after three checks', () async {
      SharedPreferences.setMockInitialValues({});
      final tour = OnboardingTour(await SharedPreferences.getInstance());
      await tour.start();

      for (var i = 0; i < OnboardingTour.checksBeforeStyleCard - 1; i++) {
        await tour.recordCompletedCheck();
      }
      expect(tour.shouldShowStyleCard, isFalse);
      await tour.recordCompletedCheck();
      expect(tour.shouldShowStyleCard, isTrue);
      await tour.markSeen(PebbleHint.styleCard);
      expect(tour.shouldShowStyleCard, isFalse);
    });

    test('remembers the practice run until it ends', () async {
      SharedPreferences.setMockInitialValues({});
      final tour = OnboardingTour(await SharedPreferences.getInstance());

      await tour.startPracticeRun(42);
      expect(tour.isPracticeRun(42), isTrue);
      expect(tour.isPracticeRun(7), isFalse);
      await tour.endPracticeRun();
      expect(tour.isPracticeRun(42), isFalse);
    });

    test('works without preferences', () {
      final tour = OnboardingTour(null);
      expect(tour.shouldShow(PebbleHint.playerTick), isFalse);
      expect(tour.isPracticeRun(1), isFalse);
    });
  });

  test('the practice reminder starts at the nearest quarter hour', () {
    expect(
      roundedReminderTime(DateTime(2026, 10, 8, 8, 7)),
      const TimeOfDay(hour: 8, minute: 0),
    );
    expect(
      roundedReminderTime(DateTime(2026, 10, 8, 8, 8)),
      const TimeOfDay(hour: 8, minute: 15),
    );
    expect(
      roundedReminderTime(DateTime(2026, 10, 8, 23, 55)),
      const TimeOfDay(hour: 0, minute: 0),
    );
  });

  testWidgets('the practice run ends by offering a reminder', (tester) async {
    var reminders = 0;
    var home = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: RoutineCompleteScreen(
              routineName: 'Quick departure check',
              totalStepsCompleted: 4,
              totalPhotosSaved: 0,
              onBackToHome: () => home++,
              onSetReminder: () => reminders++,
              onReviewRoutine: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.text('This check is in History now. Want a reminder for it?'),
      findsOneWidget,
    );
    expect(find.text('Done'), findsNothing);
    await tester.tap(find.text('Set a reminder'));
    await tester.tap(find.text('Not now'));
    expect(reminders, 1);
    expect(home, 1);
  });
}
