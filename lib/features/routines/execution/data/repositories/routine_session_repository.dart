import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

abstract class RoutineSessionRepository {
  Future<RoutineSession> startOrResumeSession({
    required Routine routine,
    required SessionRoutingContext routingContext,
  });

  Future<RoutineSession?> getSessionById(String sessionId);
  Future<RoutineSession?> getActiveSessionForRoutine(int routineId);

  Future<RoutineSession> saveSessionSnapshot(RoutineSession session);
  Future<void> discardSession(String sessionId);
  Future<RoutineRun> completeSessionAndWriteRun(RoutineSession sessionSnapshot);

  Future<List<RoutineSessionResumeSummary>> listActiveSessionsForHomeResume();

  Stream<RoutineSession?> watchSession(String sessionId);
  Stream<List<RoutineSessionResumeSummary>> watchActiveSessionsForHomeResume();
}

class RoutineSessionRepositoryImpl implements RoutineSessionRepository {
  RoutineSessionRepositoryImpl({
    required Ref ref,
    required LocalDb database,
    required RoutineSessionProofStorage proofStorage,
  }) : _ref = ref,
       _database = database,
       _proofStorage = proofStorage;

  static const _uuid = Uuid();

  final Ref _ref;
  final LocalDb _database;
  final RoutineSessionProofStorage _proofStorage;

  @override
  Future<RoutineSession> startOrResumeSession({
    required Routine routine,
    required SessionRoutingContext routingContext,
  }) async {
    final existing = await _database.routineSessionDao
        .getActiveSessionForRoutine(routine.id);
    if (existing != null) {
      final existingSession = _mapRowToEntity(existing);
      if (_shouldAutoFinalize(existingSession)) {
        await completeSessionAndWriteRun(existingSession);
      } else if (_isSessionSnapshotStaleForRoutine(existingSession, routine)) {
        await discardSession(existingSession.sessionId);
      } else {
        return existingSession;
      }
    }

    return _database.transaction(() async {
      final snapshotSteps = _parseSteps(routine.stepsJson);
      final stepStates = List.generate(
        snapshotSteps.length,
        RoutineSessionStepState.initial,
      );
      final now = DateTime.now();
      final session = RoutineSession(
        sessionId: _uuid.v4(),
        routineId: routine.id,
        routineTitleSnapshot: routine.title,
        workspaceId: routingContext.workspaceId,
        ownerUserId: routingContext.ownerUserId,
        storageScope: routingContext.storageScope,
        startedAt: now,
        updatedAt: now,
        status: RoutineSessionStatus.active,
        currentStepIndex: 0,
        totalStepCount: snapshotSteps.length,
        baseRoutineVersion: routine.version,
        routineSnapshotSteps: snapshotSteps,
        stepStates: stepStates,
        syncMetadata: _buildSyncMetadataForSave(
          session: null,
          storageScope: routingContext.storageScope,
        ),
        completedAt: null,
        discardedAt: null,
      );

      await _database.routineSessionDao.insertOrUpdateSession(
        _mapEntityToRow(session),
      );
      await _enqueueSessionSync(session, SyncOperation.upsert);
      return session;
    });
  }

  @override
  Future<RoutineSession?> getSessionById(String sessionId) async {
    final row = await _database.routineSessionDao.getSessionById(sessionId);
    return row == null ? null : _mapRowToEntity(row);
  }

  @override
  Future<RoutineSession?> getActiveSessionForRoutine(int routineId) async {
    final row = await _database.routineSessionDao.getActiveSessionForRoutine(
      routineId,
    );
    if (row == null) {
      return null;
    }
    final session = _mapRowToEntity(row);
    if (_shouldAutoFinalize(session)) {
      await completeSessionAndWriteRun(session);
      return null;
    }
    return session;
  }

  @override
  Future<RoutineSession> saveSessionSnapshot(RoutineSession session) async {
    final now = DateTime.now();
    final normalized = session.copyWith(
      updatedAt: now,
      syncMetadata: _buildSyncMetadataForSave(
        session: session,
        storageScope: session.storageScope,
      ),
    );
    await _database.routineSessionDao.insertOrUpdateSession(
      _mapEntityToRow(normalized),
    );
    await _enqueueSessionSync(normalized, SyncOperation.upsert);
    return normalized;
  }

  @override
  Future<void> discardSession(String sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) {
      return;
    }

    final now = DateTime.now();
    final discarded = session.copyWith(
      status: RoutineSessionStatus.discarded,
      updatedAt: now,
      discardedAt: now,
      syncMetadata: _buildSyncMetadataForSave(
        session: session,
        storageScope: session.storageScope,
      ),
    );

    await _database.transaction(() async {
      await _database.routineSessionDao.insertOrUpdateSession(
        _mapEntityToRow(discarded),
      );
    });
    await _enqueueSessionSync(discarded, SyncOperation.upsert);
    for (final stepState in session.stepStates) {
      for (final proofAsset in stepState.proofAssets) {
        await _proofStorage.deleteProofAsset(proofAsset);
      }
    }
    await _proofStorage.deleteSessionProofs(sessionId);
  }

  @override
  Future<RoutineRun> completeSessionAndWriteRun(
    RoutineSession sessionSnapshot,
  ) async {
    final run = await _database.transaction(() async {
      final row = await _database.routineSessionDao.getSessionById(
        sessionSnapshot.sessionId,
      );
      if (row == null) {
        throw StateError(
          'Routine session not found: ${sessionSnapshot.sessionId}',
        );
      }

      final session = _mapRowToEntity(row);
      final completedRunId = session.syncMetadata?.completedRunId;
      if (session.status == RoutineSessionStatus.completed &&
          completedRunId != null) {
        final existingRun = await _database.routineRunDao.getRunById(
          completedRunId,
        );
        if (existingRun != null) {
          return existingRun;
        }
      }
      if (session.status == RoutineSessionStatus.discarded) {
        throw StateError('Discarded sessions cannot be completed.');
      }

      final now = DateTime.now();
      final terminalSession = sessionSnapshot.copyWith(
        status: RoutineSessionStatus.active,
      );
      final runId = completedRunId ?? _uuid.v4();
      final completedSession = terminalSession.copyWith(
        status: RoutineSessionStatus.completed,
        updatedAt: now,
        completedAt: now,
        syncMetadata: _buildSyncMetadataForSave(
          session: terminalSession,
          storageScope: terminalSession.storageScope,
        )?.copyWith(completedRunId: runId),
      );

      final stepCompletionData = {
        'sessionId': completedSession.sessionId,
        'startTime': completedSession.startedAt.toIso8601String(),
        'endTime': now.toIso8601String(),
        'baseRoutineId': completedSession.routineId,
        'baseRoutineVersion': completedSession.baseRoutineVersion,
        'effectiveSteps': completedSession.routineSnapshotSteps
            .map((step) => step.toJson())
            .toList(),
        'steps': completedSession.stepStates.map((stepState) {
          final snapshotStep =
              stepState.stepIndex >= 0 &&
                  stepState.stepIndex <
                      completedSession.routineSnapshotSteps.length
              ? completedSession.routineSnapshotSteps[stepState.stepIndex]
              : null;
          return {
            'stepIndex': stepState.stepIndex,
            'label': snapshotStep?.maybeWhen(
              check: (label, _, _, _, _, _, _) => label,
              orElse: () => 'Step',
            ),
            'completedAt': stepState.completedAt?.toIso8601String(),
            'completed': stepState.status == SessionStepStatus.completed,
            'skipped': stepState.status == SessionStepStatus.skipped,
            'photos': stepState.proofAssets
                .map((asset) => asset.localRelativePath)
                .toList(),
            'proofAssets': stepState.proofAssets
                .map((asset) => asset.toJson())
                .toList(),
          };
        }).toList(),
      };

      final run = RoutineRun(
        id: runId,
        routineId: completedSession.routineId.toString(),
        routineTitle: completedSession.routineTitleSnapshot,
        finishedAt: now,
        stepCompletionData: jsonEncode(stepCompletionData),
        ownerUserId: completedSession.ownerUserId,
        syncStatus: completedSession.ownerUserId == null
            ? 'localOnly'
            : 'pendingUpload',
        lastSyncedAt: null,
        syncMetadataJson: null,
        updatedAt: now,
      );

      await _database.routineRunDao.insertOrUpdateRun(run);
      await _database.routineSessionDao.insertOrUpdateSession(
        _mapEntityToRow(completedSession),
      );
      await _enqueueSessionSync(completedSession, SyncOperation.upsert);
      if (completedSession.ownerUserId != null &&
          completedSession.ownerUserId!.isNotEmpty &&
          _ref.read(cloudAccessPolicyProvider).canQueuePersonalSync) {
        await _ref
            .read(syncOutboxRepositoryProvider)
            .enqueue(
              entityType: SyncEntityType.run,
              entityId: run.id,
              operation: SyncOperation.upsert,
            );
      }
      return run;
    });
    await _scheduleCloudSync();
    return run;
  }

  @override
  Future<List<RoutineSessionResumeSummary>>
  listActiveSessionsForHomeResume() async {
    final rows = await _database.routineSessionDao.listActiveSessions();
    return _normalizeActiveResumeSummaries(rows);
  }

  @override
  Stream<RoutineSession?> watchSession(String sessionId) {
    return _database.routineSessionDao.watchSession(sessionId).map((row) {
      return row == null ? null : _mapRowToEntity(row);
    });
  }

  @override
  Stream<List<RoutineSessionResumeSummary>> watchActiveSessionsForHomeResume() {
    return _database.routineSessionDao.watchActiveSessions().asyncMap(
      _normalizeActiveResumeSummaries,
    );
  }

  RoutineSession _mapRowToEntity(RoutineSessionRow row) {
    return RoutineSession(
      sessionId: row.sessionId,
      routineId: row.routineId,
      routineTitleSnapshot: row.routineTitleSnapshot,
      workspaceId: row.workspaceId,
      ownerUserId: row.ownerUserId,
      storageScope: _storageScopeFromString(row.storageScope),
      startedAt: row.startedAt,
      updatedAt: row.updatedAt,
      status: _routineSessionStatusFromString(row.status),
      currentStepIndex: row.currentStepIndex,
      totalStepCount: row.totalStepCount,
      baseRoutineVersion: row.baseRoutineVersion,
      routineSnapshotSteps: _decodeStepSnapshot(row.routineSnapshotJson),
      stepStates: _decodeStepStates(row.stepStatesJson),
      syncMetadata: _decodeSyncMetadata(row.syncMetadataJson),
      completedAt: row.completedAt,
      discardedAt: row.discardedAt,
    ).normalized();
  }

  RoutineSessionRow _mapEntityToRow(RoutineSession session) {
    final normalized = session.normalized();
    return RoutineSessionRow(
      sessionId: normalized.sessionId,
      routineId: normalized.routineId,
      routineTitleSnapshot: normalized.routineTitleSnapshot,
      workspaceId: normalized.workspaceId,
      ownerUserId: normalized.ownerUserId,
      storageScope: normalized.storageScope.name,
      startedAt: normalized.startedAt,
      updatedAt: normalized.updatedAt,
      status: normalized.status.name,
      currentStepIndex: normalized.currentStepIndex,
      totalStepCount: normalized.totalStepCount,
      baseRoutineVersion: normalized.baseRoutineVersion,
      stepStatesJson: jsonEncode(
        normalized.stepStates.map((state) => state.toJson()).toList(),
      ),
      routineSnapshotJson: jsonEncode(
        normalized.routineSnapshotSteps.map((step) => step.toJson()).toList(),
      ),
      syncMetadataJson: normalized.syncMetadata == null
          ? null
          : jsonEncode(normalized.syncMetadata!.toJson()),
      completedAt: normalized.completedAt,
      discardedAt: normalized.discardedAt,
    );
  }

  List<RoutineStep> _parseSteps(String stepsJson) {
    try {
      if (stepsJson.isEmpty) {
        return const <RoutineStep>[];
      }
      final decoded = jsonDecode(stepsJson);
      if (decoded is! List) {
        return const <RoutineStep>[];
      }
      return decoded.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final runtimeType = map['runtimeType'];
        if (runtimeType != null) {
          return RoutineStep.fromJson(map);
        }
        return RoutineStep.check(
          label: map['label']?.toString() ?? 'Untitled',
          requiresPhoto: (map['requirePhoto'] ?? map['requiresPhoto']) == true,
          photoCount: (map['photoCount'] as num?)?.toInt() ?? 1,
          photoPrompt: map['photoPrompt']?.toString(),
          allowSkip: (map['allowSkip'] ?? map['skippable']) == true,
        );
      }).toList();
    } catch (_) {
      return const <RoutineStep>[];
    }
  }

  List<RoutineStep> _decodeStepSnapshot(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <RoutineStep>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(RoutineStep.fromJson)
          .toList();
    } catch (_) {
      return const <RoutineStep>[];
    }
  }

  List<RoutineSessionStepState> _decodeStepStates(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        return const <RoutineSessionStepState>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(RoutineSessionStepState.fromJson)
          .toList();
    } catch (_) {
      return const <RoutineSessionStepState>[];
    }
  }

  RoutineSessionSyncMetadata? _decodeSyncMetadata(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) {
        return RoutineSessionSyncMetadata.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  RoutineSessionSyncMetadata? _buildSyncMetadataForSave({
    required RoutineSession? session,
    required SessionStorageScope storageScope,
  }) {
    if (storageScope == SessionStorageScope.localOnly) {
      return session?.syncMetadata;
    }

    return (session?.syncMetadata ??
            const RoutineSessionSyncMetadata(needsSync: true))
        .copyWith(needsSync: true);
  }

  bool _shouldAutoFinalize(RoutineSession session) {
    return session.isActive &&
        session.isFinalStep &&
        (session.currentStepState?.status == SessionStepStatus.completed ||
            session.currentStepState?.status == SessionStepStatus.skipped ||
            session.isTerminal);
  }

  bool _isSessionSnapshotStaleForRoutine(
    RoutineSession session,
    Routine routine,
  ) {
    if (session.routineTitleSnapshot != routine.title) {
      return true;
    }

    final currentSteps = _parseSteps(routine.stepsJson);
    if (currentSteps.length != session.routineSnapshotSteps.length) {
      return true;
    }

    for (var index = 0; index < currentSteps.length; index += 1) {
      if (currentSteps[index] != session.routineSnapshotSteps[index]) {
        return true;
      }
    }
    return false;
  }

  Future<List<RoutineSessionResumeSummary>> _normalizeActiveResumeSummaries(
    List<RoutineSessionRow> rows,
  ) async {
    final summaries = <RoutineSessionResumeSummary>[];
    for (final row in rows) {
      final session = _mapRowToEntity(row);
      if (_shouldAutoFinalize(session)) {
        await completeSessionAndWriteRun(session);
        continue;
      }
      summaries.add(session.toResumeSummary());
    }
    return summaries;
  }

  Future<void> _enqueueSessionSync(
    RoutineSession session,
    SyncOperation operation,
  ) async {
    if (session.storageScope == SessionStorageScope.localOnly ||
        session.ownerUserId == null ||
        session.ownerUserId!.isEmpty) {
      return;
    }
    await _ref
        .read(syncOutboxRepositoryProvider)
        .enqueue(
          entityType: SyncEntityType.session,
          entityId: session.sessionId,
          operation: operation,
        );
  }

  Future<void> _scheduleCloudSync() async {
    await _ref.read(cloudSyncCoordinatorProvider).kick();
  }
}

final routineSessionRepositoryProvider = Provider<RoutineSessionRepository>((
  ref,
) {
  final database = ref.read(localDbProvider);
  final proofStorage = ref.read(routineSessionProofStorageProvider);
  return RoutineSessionRepositoryImpl(
    ref: ref,
    database: database,
    proofStorage: proofStorage,
  );
});

final sessionRoutingContextProvider = Provider<SessionRoutingContext>((ref) {
  final tier = ref.watch(subscriptionProvider);
  final policy = ref.watch(cloudAccessPolicyProvider);
  final workspace = ref.watch(workspaceAccessProvider);
  final account = ref.watch(subscriptionAccountControllerProvider);
  return SessionRoutingContext(
    storageScope: _storageScopeForContext(
      tier: tier,
      personalCloudEnabled: policy.personalCloudEnabled,
      workspaceCloudEnabled: workspace.isCloudEnabled,
    ),
    ownerUserId: policy.cachedOwnerUserId ?? account.userId,
  );
});

final activeRoutineSessionsProvider =
    StreamProvider.autoDispose<List<RoutineSessionResumeSummary>>((ref) {
      final repository = ref.watch(routineSessionRepositoryProvider);
      return repository.watchActiveSessionsForHomeResume();
    });

SessionStorageScope _storageScopeForContext({
  required UserTier tier,
  required bool personalCloudEnabled,
  required bool workspaceCloudEnabled,
}) {
  if (tier.isBusiness && workspaceCloudEnabled) {
    return SessionStorageScope.workspaceCloud;
  }
  if (personalCloudEnabled) {
    return SessionStorageScope.personalCloud;
  }
  return SessionStorageScope.localOnly;
}

RoutineSessionStatus _routineSessionStatusFromString(String value) {
  return RoutineSessionStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => RoutineSessionStatus.active,
  );
}

SessionStorageScope _storageScopeFromString(String value) {
  return SessionStorageScope.values.firstWhere(
    (scope) => scope.name == value,
    orElse: () => SessionStorageScope.localOnly,
  );
}
