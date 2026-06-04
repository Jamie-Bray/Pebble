import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';

void main() {
  test('player state soft-locks steps from index 10 onward', () {
    const policy = RoutineLimitPolicy(
      hasPremiumRoutineAccess: false,
      isInGrace: false,
    );
    final session = _session(stepCount: 12, currentStepIndex: 10);
    final state = RoutinePlayerUiState(
      screenPhase: RoutinePlayerScreenPhase.ready,
      maxProofPhotosPerStep: 1,
      routineLimitPolicy: policy,
      session: session,
    );

    expect(state.isCurrentStepLocked, isTrue);
    expect(state.lockedStepCount, 2);
    expect(state.isPrimaryEnabled, isFalse);
    expect(state.canSkip, isFalse);
    expect(state.canAddMorePhotos, isFalse);
  });
}

RoutineSession _session({
  required int stepCount,
  required int currentStepIndex,
}) {
  final now = DateTime.utc(2026, 6, 1);
  final steps = [
    for (var index = 0; index < stepCount; index++)
      RoutineStep.check(label: 'Step ${index + 1}'),
  ];
  return RoutineSession(
    sessionId: 'session-1',
    routineId: 1,
    routineTitleSnapshot: 'Routine',
    workspaceId: null,
    ownerUserId: null,
    storageScope: SessionStorageScope.localOnly,
    startedAt: now,
    updatedAt: now,
    status: RoutineSessionStatus.active,
    currentStepIndex: currentStepIndex,
    totalStepCount: stepCount,
    baseRoutineVersion: 1,
    routineSnapshotSteps: steps,
    stepStates: List.generate(stepCount, RoutineSessionStepState.initial),
    syncMetadata: null,
    completedAt: null,
    discardedAt: null,
  );
}
