import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

class _FakeProofStorage implements RoutineSessionProofStorage {
  final Set<String> deletedSessions = <String>{};
  final Set<String> deletedProofs = <String>{};

  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  Future<void> deleteSessionProofs(String sessionId) async {
    deletedSessions.add(sessionId);
  }

  @override
  Future<void> deleteStoredProof(String storedPath) async {
    deletedProofs.add(storedPath);
  }

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    return RoutineSessionProofAsset(
      proofId: 'proof-$sessionId',
      localRelativePath: sourcePath,
      remoteObjectKey: null,
      uploadStatus: ProofUploadStatus.localOnly,
      capturedAt: DateTime.now(),
    );
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async {
    return null;
  }

  @override
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset) async {
    return null;
  }

  @override
  Future<String> resolveStoredPath(String storedPath) async {
    return storedPath;
  }

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    return asset.copyWith(
      remoteObjectKey:
          'users/$ownerUserId/$entityType/$entityId/${asset.proofId}.jpg',
      uploadStatus: ProofUploadStatus.uploaded,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutineSessionRepository', () {
    late LocalDb database;
    late _FakeProofStorage proofStorage;
    late RoutineSessionRepository repository;
    late ProviderContainer container;
    late Routine routine;

    setUp(() async {
      database = LocalDb.forTesting(NativeDatabase.memory());
      proofStorage = _FakeProofStorage();
      container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => SubscriptionAccountController(database, loadOnInit: false),
          ),
        ],
      );
      repository = container.read(routineSessionRepositoryProvider);

      final steps = [
        const RoutineStep.check(label: 'Lock the door', allowSkip: false),
        const RoutineStep.check(
          label: 'Take a photo',
          requiresPhoto: true,
          allowSkip: true,
        ),
      ];

      routine = Routine(
        id: 1,
        title: 'Closing Rundown',
        stepsJson: jsonEncode(steps.map((step) => step.toJson()).toList()),
        createdAt: DateTime(2026, 1, 1),
        emoji: null,
        colorHex: null,
        isPinned: false,
        pinnedAt: null,
        reminderDay: null,
        reminderTime: null,
        version: 1,
        updatedAt: DateTime(2026, 1, 1),
        cloudId: null,
        ownerUserId: null,
        syncStatus: 'localOnly',
        lastSyncedAt: null,
      );

      await database.routineDao.insertOrUpdateRoutine(routine);
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('startOrResumeSession returns the same active session', () async {
      const routing = SessionRoutingContext(
        storageScope: SessionStorageScope.localOnly,
      );

      final first = await repository.startOrResumeSession(
        routine: routine,
        routingContext: routing,
      );

      final updated = await repository.saveSessionSnapshot(
        first.copyWith(
          currentStepIndex: 1,
          stepStates: [
            first.stepStates[0].copyWith(
              status: SessionStepStatus.completed,
              completedAt: DateTime(2026, 1, 1, 9, 0),
            ),
            first.stepStates[1],
          ],
        ),
      );

      final resumed = await repository.startOrResumeSession(
        routine: routine,
        routingContext: routing,
      );

      expect(resumed.sessionId, first.sessionId);
      expect(resumed.currentStepIndex, 1);
      expect(resumed.stepStates.first.status, SessionStepStatus.completed);
      expect(updated.sessionId, resumed.sessionId);
    });

    test(
      'completeSessionAndWriteRun writes history and clears active session',
      () async {
        final session = await repository.startOrResumeSession(
          routine: routine,
          routingContext: const SessionRoutingContext(
            storageScope: SessionStorageScope.personalCloud,
          ),
        );

        final proofAsset = RoutineSessionProofAsset(
          proofId: 'proof-1',
          localRelativePath:
              'routine_session_proofs/${session.sessionId}/proof-1.jpg',
          remoteObjectKey: null,
          uploadStatus: ProofUploadStatus.localOnly,
          capturedAt: DateTime(2026, 1, 1, 9, 5),
        );

        final terminalSession = session.copyWith(
          currentStepIndex: 1,
          stepStates: [
            session.stepStates[0].copyWith(
              status: SessionStepStatus.completed,
              completedAt: DateTime(2026, 1, 1, 9, 1),
            ),
            session.stepStates[1].copyWith(
              status: SessionStepStatus.completed,
              completedAt: DateTime(2026, 1, 1, 9, 5),
              proofAssets: [proofAsset],
            ),
          ],
        );

        final run = await repository.completeSessionAndWriteRun(
          terminalSession,
        );
        final activeSession = await repository.getActiveSessionForRoutine(
          routine.id,
        );
        final runs = await database.routineRunDao.watchAllRuns().first;
        final repeatRun = await repository.completeSessionAndWriteRun(
          terminalSession,
        );

        expect(run.routineTitle, routine.title);
        expect(activeSession, isNull);
        expect(runs, hasLength(1));
        expect(runs.single.id, run.id);
        expect(repeatRun.id, run.id);
        expect(runs.single.stepCompletionData, contains('proofAssets'));
        expect(runs.single.stepCompletionData, contains('effectiveSteps'));
        expect(runs.single.stepCompletionData, contains(session.sessionId));
      },
    );

    test(
      'discardSession removes active session and deletes local proof folder',
      () async {
        final session = await repository.startOrResumeSession(
          routine: routine,
          routingContext: const SessionRoutingContext(
            storageScope: SessionStorageScope.localOnly,
          ),
        );

        await repository.discardSession(session.sessionId);

        final activeSession = await repository.getActiveSessionForRoutine(
          routine.id,
        );
        final discardedSession = await repository.getSessionById(
          session.sessionId,
        );

        expect(activeSession, isNull);
        expect(discardedSession?.status, RoutineSessionStatus.discarded);
        expect(proofStorage.deletedSessions, contains(session.sessionId));
      },
    );

    test('reopening after discard starts a fresh session at step 1', () async {
      final first = await repository.startOrResumeSession(
        routine: routine,
        routingContext: const SessionRoutingContext(
          storageScope: SessionStorageScope.localOnly,
        ),
      );

      await repository.discardSession(first.sessionId);

      final next = await repository.startOrResumeSession(
        routine: routine,
        routingContext: const SessionRoutingContext(
          storageScope: SessionStorageScope.localOnly,
        ),
      );

      expect(next.sessionId, isNot(first.sessionId));
      expect(next.currentStepIndex, 0);
      expect(next.status, RoutineSessionStatus.active);
    });
  });
}
