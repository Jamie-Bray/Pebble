import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/share/share_messages.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';

String _hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

void main() {
  group('runSummary', () {
    test('lists each step with its time, and marks skipped steps', () {
      final text = ShareMessages.runSummary(
        routineTitle: ' Bedtime house check ',
        finishedAt: DateTime(2026, 10, 6, 22, 14),
        steps: [
          SharedRunStep(
            label: 'Back door locked',
            completedAt: DateTime(2026, 10, 6, 22, 2),
          ),
          const SharedRunStep(label: 'Windows shut', skipped: true),
          const SharedRunStep(label: 'Hob off'),
        ],
        formatTime: _hhmm,
      );

      expect(
        text,
        'Bedtime house check\n'
        'Completed at 22:14 on Tuesday, October 6\n'
        '\n'
        '✓ Back door locked, 22:02\n'
        '– Windows shut, skipped\n'
        '✓ Hob off\n'
        '\n'
        'Recorded in Pebble',
      );
    });

    test('an empty title reads as "Routine"', () {
      final text = ShareMessages.runSummary(
        routineTitle: '  ',
        finishedAt: DateTime(2026, 10, 6, 8),
        steps: const [],
        formatTime: _hhmm,
      );
      expect(text.split('\n').first, 'Routine');
      expect(text, isNot(contains('\n\n\n')));
    });
  });

  group('stepsFromRun', () {
    test('reads labels, times and skips, and leaves out notes', () {
      final steps = ShareMessages.stepsFromRun(
        _run({
          'effectiveSteps': [
            const RoutineStep.check(label: 'Lock the door').toJson(),
            const RoutineStep.info(message: 'Key is in the bowl').toJson(),
            const RoutineStep.timer(duration: 300).toJson(),
            const RoutineStep.check(label: 'Hob off').toJson(),
            const RoutineStep.check(label: 'Plants').toJson(),
          ],
          'steps': [
            {'completed': true, 'completedAt': '2026-10-06T08:02:00'},
            {'completed': true, 'completedAt': '2026-10-06T08:03:00'},
            {'completed': true, 'completedAt': '2026-10-06T08:08:00'},
            {'skipped': true},
            {'completed': false},
          ],
        }),
      );

      expect(
        [for (final s in steps) s.label],
        ['Lock the door', 'Wait 5 minutes', 'Hob off'],
      );
      expect(steps.first.completedAt, DateTime(2026, 10, 6, 8, 2));
      expect(steps[2].skipped, isTrue);
      expect(steps[2].completedAt, isNull);
    });

    test('older runs without step records read as done', () {
      final steps = ShareMessages.stepsFromRun(
        _run({
          'effectiveSteps': [
            const RoutineStep.check(label: 'One').toJson(),
            const RoutineStep.check(label: 'Two').toJson(),
          ],
        }),
      );
      expect(steps.map((s) => s.label), ['One', 'Two']);
      expect(steps.every((s) => !s.skipped), isTrue);
    });

    test('a malformed record shares no steps instead of failing', () {
      final run = RoutineRun(
        id: 'r',
        routineId: '1',
        routineTitle: 'Morning',
        finishedAt: DateTime(2026, 10, 6),
        stepCompletionData: '{not json',
        syncStatus: 'localOnly',
        updatedAt: DateTime(2026, 10, 6),
      );
      expect(ShareMessages.stepsFromRun(run), isEmpty);
    });
  });

  group('routineChecklist', () {
    test('numbers the steps and keeps notes unnumbered', () {
      final text = ShareMessages.routineChecklist(
        routineTitle: 'House sitter handover',
        steps: const [
          RoutineStep.check(label: 'Water the plants'),
          RoutineStep.info(message: 'Spare key is under the blue pot'),
          RoutineStep.check(label: 'Lock the back door', requiresPhoto: true),
          RoutineStep.timer(duration: 90),
        ],
      );

      expect(
        text,
        'House sitter handover\n'
        '\n'
        '1. Water the plants\n'
        'Note: Spare key is under the blue pot\n'
        '2. Lock the back door\n'
        '3. Wait 1 min 30 sec\n'
        '\n'
        'Made in Pebble, a checklist app: pebbleroutines.com',
      );
    });

    test('reads a saved routine, including the older step shape', () {
      final routine = Routine(
        id: 1,
        title: 'Leaving the house',
        stepsJson: jsonEncode([
          const RoutineStep.check(label: 'Lights off').toJson(),
          {'label': 'Back door', 'requirePhoto': true},
        ]),
        createdAt: DateTime(2026),
        isPinned: false,
        version: 1,
        updatedAt: DateTime(2026),
        syncStatus: 'localOnly',
      );
      expect(
        ShareMessages.routineChecklistFor(routine),
        contains('1. Lights off\n2. Back door\n'),
      );
    });
  });

  test('the app invite links to the website', () {
    expect(ShareMessages.appInvite, contains('pebbleroutines.com'));
    expect(ShareMessages.appInvite, isNot(contains('!')));
  });

  group('completion screen', () {
    Future<void> pump(
      WidgetTester tester, {
      void Function(BuildContext)? onShare,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: RoutineCompleteScreen(
                routineName: 'Leaving the house',
                totalStepsCompleted: 2,
                totalPhotosSaved: 0,
                onBackToHome: () {},
                onReviewRoutine: () {},
                onShare: onShare,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows Share next to See details', (tester) async {
      var shared = 0;
      await pump(tester, onShare: (_) => shared++);
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('See details'), findsOneWidget);
      await tester.tap(find.text('Share'));
      expect(shared, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides Share when there is nothing to share', (tester) async {
      await pump(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Share'), findsNothing);
      expect(find.text('See details'), findsOneWidget);
    });
  });
}

RoutineRun _run(Map<String, dynamic> data) {
  return RoutineRun(
    id: 'run-1',
    routineId: '1',
    routineTitle: 'Leaving the house',
    finishedAt: DateTime(2026, 10, 6, 8, 10),
    stepCompletionData: jsonEncode(data),
    syncStatus: 'localOnly',
    updatedAt: DateTime(2026, 10, 6, 8, 10),
  );
}
