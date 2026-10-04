import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';

void main() {
  group('RunStepTally', () {
    test('a skipped step is never counted as done', () {
      final tally = RunStepTally.fromCompletionData(
        _completionData(skipped: const {3}),
      );

      expect(tally.done, 3);
      expect(tally.skipped, 1);
      expect(tally.total, 4);
      expect(tally.isComplete, isFalse);
      expect(tally.summary, '3 of 4 steps · 1 skipped');
    });

    test('a fully completed run reads as complete', () {
      final tally = RunStepTally.fromCompletionData(_completionData());

      expect(tally.done, 4);
      expect(tally.skipped, 0);
      expect(tally.isComplete, isTrue);
      expect(tally.summary, '4 of 4 steps');
    });

    test('runs saved without per-step records count as done', () {
      final tally = RunStepTally.fromCompletionData({
        'effectiveSteps': [for (final step in _steps) step.toJson()],
      });

      expect(tally.done, 4);
      expect(tally.total, 4);
    });

    test('malformed payloads read as an empty run', () {
      final tally = RunStepTally.fromRun(_run('{not json'));

      expect(tally.done, 0);
      expect(tally.total, 0);
    });
  });

  testWidgets(
    'run detail reports skipped steps instead of counting them done',
    (tester) async {
      final run = _run(jsonEncode(_completionData(skipped: const {3})));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineSessionProofStorageProvider.overrideWithValue(
              _NoopProofStorage(),
            ),
            accountStatusPresentationProvider.overrideWithValue(_presentation),
          ],
          child: MaterialApp(
            theme: AppTheme.fromId(ThemeId.highNoon),
            home: RoutineRunDetailScreen(run: run),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3 of 4'), findsOneWidget);
      expect(find.text('Done · 1 skipped'), findsOneWidget);
      expect(find.text('4 / 4'), findsNothing);
      expect(find.text('Step 4 · Skipped'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(
        find.bySemanticsLabel('3 of 4 steps done · 1 skipped'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('run detail keeps "Steps done" for a complete run', (
    tester,
  ) async {
    final run = _run(jsonEncode(_completionData()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineSessionProofStorageProvider.overrideWithValue(
            _NoopProofStorage(),
          ),
          accountStatusPresentationProvider.overrideWithValue(_presentation),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: RoutineRunDetailScreen(run: run),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Steps done'), findsOneWidget);
    expect(find.textContaining('Skipped'), findsNothing);
  });
}

const _steps = <RoutineStep>[
  RoutineStep.check(label: 'Open the curtains'),
  RoutineStep.check(label: 'Glass of water'),
  RoutineStep.check(label: 'Take morning medication'),
  RoutineStep.check(label: 'Make the bed', allowSkip: true),
];

Map<String, dynamic> _completionData({Set<int> skipped = const {}}) {
  final start = DateTime(2026, 10, 3, 8);
  return {
    'startTime': start.toIso8601String(),
    'endTime': start.add(const Duration(minutes: 6)).toIso8601String(),
    'effectiveSteps': [for (final step in _steps) step.toJson()],
    'steps': [
      for (var i = 0; i < _steps.length; i++)
        {
          'stepIndex': i,
          'completedAt': skipped.contains(i)
              ? null
              : start.add(Duration(minutes: i + 1)).toIso8601String(),
          'completed': !skipped.contains(i),
          'skipped': skipped.contains(i),
          'photos': <String>[],
          'proofAssets': <Object>[],
        },
    ],
  };
}

RoutineRun _run(String? completionData) {
  final finishedAt = DateTime(2026, 10, 3, 8, 6);
  return RoutineRun(
    id: 'run-1',
    routineId: '1',
    routineTitle: 'Morning reset',
    finishedAt: finishedAt,
    stepCompletionData: completionData,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: finishedAt,
  );
}

const _presentation = AccountStatusPresentation(
  planLabel: 'Free',
  title: 'Saved on this device',
  body: '',
  statusLabel: 'Backup is off',
  historyLabel: '2 days',
  limitChips: [],
  featureHighlights: [],
  primaryAction: AccountStatusAction.none,
  primaryActionLabel: null,
  secondaryAction: AccountStatusAction.none,
  secondaryActionLabel: null,
  supportingDetail: null,
  tone: AccountStatusTone.neutral,
  icon: LucideIcons.cloudOff,
  isSyncRunning: false,
  showRunSyncState: false,
  showPremiumNote: false,
);

class _NoopProofStorage implements RoutineSessionProofStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
