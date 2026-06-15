import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_management_provider.dart';

void main() {
  test(
    'deleteRoutine discards active progress before deleting routine',
    () async {
      final calls = <String>[];
      final routineRepository = _FakeRoutineRepository(calls);
      final sessionRepository = _FakeRoutineSessionRepository(
        calls,
        activeSession: _activeSession(),
      );
      final actions = RoutineManagementActions(
        routineRepository,
        sessionRepository,
      );

      await actions.deleteRoutine(42);

      expect(calls, <String>['discard:session-1', 'delete:42']);
    },
  );
}

RoutineSession _activeSession() {
  final now = DateTime(2026, 1, 1, 9);
  return RoutineSession(
    sessionId: 'session-1',
    routineId: 42,
    routineTitleSnapshot: 'Leaving Home',
    workspaceId: null,
    ownerUserId: null,
    storageScope: SessionStorageScope.localOnly,
    startedAt: now,
    updatedAt: now,
    status: RoutineSessionStatus.active,
    currentStepIndex: 0,
    totalStepCount: 1,
    baseRoutineVersion: 1,
    routineSnapshotSteps: const <RoutineStep>[
      RoutineStep.check(label: 'Lock the door'),
    ],
    stepStates: const <RoutineSessionStepState>[
      RoutineSessionStepState(
        stepIndex: 0,
        status: SessionStepStatus.pending,
        completedAt: null,
        proofAssets: <RoutineSessionProofAsset>[],
      ),
    ],
    syncMetadata: null,
    completedAt: null,
    discardedAt: null,
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(this.calls);

  final List<String> calls;

  @override
  Future<void> deleteRoutine(int id) async {
    calls.add('delete:$id');
  }

  @override
  Future<void> deleteRoutineReminder(RoutineReminder reminder) async {
    calls.add('deleteReminder:${reminder.id}');
  }

  @override
  Future<void> deleteRoutineRemindersForRoutine(int routineId) async {
    calls.add('deleteRemindersForRoutine:$routineId');
  }

  @override
  Future<void> deleteAllRoutineReminders() async {
    calls.add('deleteAllReminders');
  }

  @override
  Future<Routine> duplicateRoutine(int id) {
    throw UnimplementedError();
  }

  @override
  Future<Routine?> getRoutineById(int id) async => null;

  @override
  Future<(int?, String?)> getRoutineReminder(int id) async => (null, null);

  @override
  Future<void> saveRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {}

  @override
  Future<void> updateRoutinePinned(int id, bool isPinned) async {}

  @override
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async {
    calls.add('move:$id:${direction.name}');
    return true;
  }

  @override
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  }) async {}

  @override
  Stream<List<Routine>> watchRoutines() => const Stream<List<Routine>>.empty();

  @override
  Future<void> normalizeLegacyRoutineIcons() async {}

  @override
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId) {
    return const Stream<RoutineRun?>.empty();
  }
}

class _FakeRoutineSessionRepository implements RoutineSessionRepository {
  _FakeRoutineSessionRepository(this.calls, {this.activeSession});

  final List<String> calls;
  final RoutineSession? activeSession;

  @override
  Future<void> discardSession(String sessionId) async {
    calls.add('discard:$sessionId');
  }

  @override
  Future<RoutineSession?> getActiveSessionForRoutine(int routineId) async {
    return activeSession?.routineId == routineId ? activeSession : null;
  }

  @override
  Future<RoutineRun> completeSessionAndWriteRun(
    RoutineSession sessionSnapshot,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<RoutineSession?> getSessionById(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<RoutineSessionResumeSummary>> listActiveSessionsForHomeResume() {
    throw UnimplementedError();
  }

  @override
  Future<RoutineSession> saveSessionSnapshot(RoutineSession session) {
    throw UnimplementedError();
  }

  @override
  Future<RoutineSession> startOrResumeSession({
    required Routine routine,
    required SessionRoutingContext routingContext,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<RoutineSessionResumeSummary>> watchActiveSessionsForHomeResume() {
    return const Stream<List<RoutineSessionResumeSummary>>.empty();
  }

  @override
  Stream<RoutineSession?> watchSession(String sessionId) {
    return const Stream<RoutineSession?>.empty();
  }
}
