import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

enum ManualSyncResultType {
  blockedSignedOut,
  blockedNoEntitlement,
  blockedConsentRequired,
  blockedOffline,
  noChanges,
  synced,
  partialRetryScheduled,
  failed,
}

class ManualSyncResult {
  const ManualSyncResult({required this.type, required this.message});

  final ManualSyncResultType type;
  final String message;
}

class CloudSyncRuntimeState {
  const CloudSyncRuntimeState({
    required this.isRunning,
    required this.pendingCount,
    required this.nextRetryAt,
  });

  const CloudSyncRuntimeState.idle()
    : isRunning = false,
      pendingCount = 0,
      nextRetryAt = null;

  final bool isRunning;
  final int pendingCount;
  final DateTime? nextRetryAt;
}

class CloudSyncCoordinator {
  CloudSyncCoordinator({
    required Ref ref,
    required LocalDb database,
    required SyncOutboxRepository outbox,
    required RemoteRoutineDataSource remoteRoutineDataSource,
    required RemoteRoutineReminderDataSource remoteReminderDataSource,
    required RemoteRoutineRunDataSource remoteRunDataSource,
    required RemoteRoutineSessionDataSource remoteSessionDataSource,
    required RoutineSessionProofStorage proofStorage,
  }) : _ref = ref,
       _database = database,
       _outbox = outbox,
       _remoteRoutineDataSource = remoteRoutineDataSource,
       _remoteReminderDataSource = remoteReminderDataSource,
       _remoteRunDataSource = remoteRunDataSource,
       _remoteSessionDataSource = remoteSessionDataSource,
       _proofStorage = proofStorage;

  final Ref _ref;
  final LocalDb _database;
  final SyncOutboxRepository _outbox;
  final RemoteRoutineDataSource _remoteRoutineDataSource;
  final RemoteRoutineReminderDataSource _remoteReminderDataSource;
  final RemoteRoutineRunDataSource _remoteRunDataSource;
  final RemoteRoutineSessionDataSource _remoteSessionDataSource;
  final RoutineSessionProofStorage _proofStorage;

  bool _isRunning = false;
  Timer? _retryTimer;
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  Future<void> kick() async {
    final entitlement = _ref.read(entitlementStateProvider);
    await _proofStorage.enforceRetentionPolicy(
      isPremium: entitlement.isPersonalPaid,
    );
    await _syncInternal(userInitiated: false);
  }

  Future<ManualSyncResult> runManualSync() {
    return _syncInternal(userInitiated: true);
  }

  Future<ManualSyncResult> _syncInternal({required bool userInitiated}) async {
    final auth = _ref.read(authSessionProvider);
    final entitlement = _ref.read(entitlementStateProvider);
    final policy = _ref.read(cloudAccessPolicyProvider);
    final userId = policy.cachedOwnerUserId;

    if (!entitlement.isPersonalPaid) {
      _setRuntimeState(const CloudSyncRuntimeState.idle());
      return const ManualSyncResult(
        type: ManualSyncResultType.blockedNoEntitlement,
        message: 'Upgrade to turn on backup and sync.',
      );
    }

    if (!auth.isSignedIn) {
      await _refreshRuntimeState();
      return const ManualSyncResult(
        type: ManualSyncResultType.blockedSignedOut,
        message: 'Sign in to resume backup and sync.',
      );
    }

    if (_isRunning) {
      await _refreshRuntimeState(isRunning: true);
      return const ManualSyncResult(
        type: ManualSyncResultType.synced,
        message: 'Pebble is already syncing your routines.',
      );
    }

    if (!policy.canUploadCloudChanges || userId == null || userId.isEmpty) {
      await _refreshRuntimeState();
      final access = _ref.read(personalCloudAccessProvider);
      if (access.status == PersonalCloudAccessStatus.consentRequired) {
        return const ManualSyncResult(
          type: ManualSyncResultType.blockedConsentRequired,
          message: 'Review and enable cloud backup before Pebble uploads data.',
        );
      }
      return const ManualSyncResult(
        type: ManualSyncResultType.failed,
        message: 'Pebble couldn\'t finish syncing everything. Try again.',
      );
    }

    var pendingItems = userInitiated
        ? await _outbox.pendingItems()
        : await _outbox.dueItems();
    if (pendingItems.isEmpty && (await _outbox.pendingItems()).isEmpty) {
      await _queueUnsyncedLocalBaseline();
      pendingItems = userInitiated
          ? await _outbox.pendingItems()
          : await _outbox.dueItems();
    }
    if (pendingItems.isEmpty) {
      _setRuntimeState(const CloudSyncRuntimeState.idle());
      return const ManualSyncResult(
        type: ManualSyncResultType.noChanges,
        message: 'Everything is up to date.',
      );
    }

    var syncedCount = 0;
    var failedCount = 0;
    var sawOfflineError = false;
    final prioritizedItems = [...pendingItems]..sort(_compareSyncPriority);

    _isRunning = true;
    _setRuntimeState(
      CloudSyncRuntimeState(
        isRunning: true,
        pendingCount: prioritizedItems.length,
        nextRetryAt: null,
      ),
    );
    try {
      for (final item in prioritizedItems) {
        try {
          await _processItem(item, userId);
          await _outbox.markComplete(item.id);
          syncedCount += 1;
          await _ref
              .read(subscriptionAccountControllerProvider.notifier)
              .noteSyncSuccess();
        } catch (error, stackTrace) {
          developer.log(
            'Sync failed for ${item.entityType.name}:${item.entityId}',
            name: 'CloudSyncCoordinator',
            error: error,
            stackTrace: stackTrace,
          );
          failedCount += 1;
          sawOfflineError = sawOfflineError || _looksOffline(error);
          await _outbox.markRetry(item.id, error, item.attemptCount + 1);
          await _ref
              .read(subscriptionAccountControllerProvider.notifier)
              .noteSyncFailure(_failureMessageForError(error));
        }
      }
    } finally {
      _isRunning = false;
      await _refreshRuntimeState();
    }

    if (failedCount == 0) {
      return ManualSyncResult(
        type: syncedCount > 0
            ? ManualSyncResultType.synced
            : ManualSyncResultType.noChanges,
        message: syncedCount > 0
            ? 'Everything is up to date.'
            : userInitiated
            ? 'No new changes to sync.'
            : 'Everything is up to date.',
      );
    }

    if (syncedCount > 0) {
      return const ManualSyncResult(
        type: ManualSyncResultType.partialRetryScheduled,
        message: 'Some items haven\'t synced yet. Pebble will keep trying.',
      );
    }

    if (sawOfflineError) {
      return const ManualSyncResult(
        type: ManualSyncResultType.blockedOffline,
        message: 'You\'re offline. Changes will sync later.',
      );
    }

    return const ManualSyncResult(
      type: ManualSyncResultType.failed,
      message: 'Pebble couldn\'t finish syncing everything. Try again.',
    );
  }

  String _toSupabaseUuid(String localId) {
    if (_looksLikeUuid(localId)) return localId.toLowerCase();
    return _uuid.v5(Namespace.url.value, 'vix.pebble/$localId');
  }

  int _compareSyncPriority(SyncOutboxItem a, SyncOutboxItem b) {
    final entityOrder = <SyncEntityType, int>{
      SyncEntityType.routine: 0,
      SyncEntityType.reminder: 1,
      SyncEntityType.run: 2,
      SyncEntityType.session: 3,
      SyncEntityType.proofAsset: 4,
    };
    final operationOrder = <SyncOperation, int>{
      SyncOperation.upsert: 0,
      SyncOperation.upload: 1,
      SyncOperation.delete: 2,
    };
    final entityCompare = (entityOrder[a.entityType] ?? 99).compareTo(
      entityOrder[b.entityType] ?? 99,
    );
    if (entityCompare != 0) {
      return entityCompare;
    }
    final operationCompare = (operationOrder[a.operation] ?? 99).compareTo(
      operationOrder[b.operation] ?? 99,
    );
    if (operationCompare != 0) {
      return operationCompare;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value.trim());

  Future<void> _queueUnsyncedLocalBaseline() async {
    final routines = await _database.routineDao.getAllRoutines();
    for (final routine in routines) {
      if (routine.syncStatus != 'synced' ||
          routine.cloudId == null ||
          routine.cloudId!.isEmpty ||
          routine.ownerUserId == null ||
          routine.ownerUserId!.isEmpty) {
        await _outbox.enqueue(
          entityType: SyncEntityType.routine,
          entityId: routine.id.toString(),
          operation: SyncOperation.upsert,
        );
      }
    }

    final reminders = await _database.routineReminderDao.getAllReminders();
    for (final reminder in reminders) {
      if (reminder.syncStatus != 'synced' ||
          reminder.cloudId == null ||
          reminder.cloudId!.isEmpty ||
          reminder.ownerUserId == null ||
          reminder.ownerUserId!.isEmpty) {
        await _outbox.enqueue(
          entityType: SyncEntityType.reminder,
          entityId: reminder.id.toString(),
          operation: SyncOperation.upsert,
        );
      }
    }

    final runs = await _database.routineRunDao.getAllRuns();
    for (final run in runs) {
      if (run.syncStatus != 'synced' ||
          run.ownerUserId == null ||
          run.ownerUserId!.isEmpty) {
        await _outbox.enqueue(
          entityType: SyncEntityType.run,
          entityId: run.id,
          operation: SyncOperation.upsert,
        );
      }
    }

    final sessions = await _database.routineSessionDao.getAllSessions();
    for (final session in sessions) {
      if (_sessionNeedsSync(session)) {
        await _outbox.enqueue(
          entityType: SyncEntityType.session,
          entityId: session.sessionId,
          operation: SyncOperation.upsert,
        );
      }
    }
  }

  bool _sessionNeedsSync(RoutineSessionRow session) {
    if (session.ownerUserId == null || session.ownerUserId!.isEmpty) {
      return true;
    }
    final metadataJson = session.syncMetadataJson;
    if (metadataJson == null || metadataJson.isEmpty) {
      return false;
    }
    try {
      final decoded = jsonDecode(metadataJson);
      return decoded is Map && decoded['needsSync'] == true;
    } catch (_) {
      return true;
    }
  }

  int? _toSignedInt32(int? value) {
    if (value == null) {
      return null;
    }
    return value.toUnsigned(32).toSigned(32);
  }

  String _stableRemoteId({
    required String entityKind,
    required String localEntityId,
    String? existingRemoteId,
  }) {
    final candidate = existingRemoteId?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return _toSupabaseUuid(candidate);
    }
    return _toSupabaseUuid('$entityKind/$localEntityId');
  }

  Future<Routine?> _resolveRoutineForRun(String routineReference) async {
    final localRoutineId = int.tryParse(routineReference);
    if (localRoutineId != null) {
      return _database.routineDao.getRoutineById(localRoutineId);
    }
    if (_looksLikeUuid(routineReference)) {
      return _database.routineDao.getRoutineByCloudId(routineReference);
    }
    return null;
  }

  Future<void> _processItem(SyncOutboxItem item, String ownerUserId) async {
    switch (item.entityType) {
      case SyncEntityType.routine:
        await _syncRoutineItem(item, ownerUserId);
        return;
      case SyncEntityType.reminder:
        await _syncReminderItem(item, ownerUserId);
        return;
      case SyncEntityType.run:
        await _syncRunItem(item, ownerUserId);
        return;
      case SyncEntityType.session:
        await _syncSessionItem(item, ownerUserId);
        return;
      case SyncEntityType.proofAsset:
        return;
    }
  }

  Future<void> _syncRoutineItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      final cloudId = item.payload?['cloudId']?.toString();
      if (cloudId != null && cloudId.isNotEmpty) {
        await _remoteRoutineDataSource.delete(_toSupabaseUuid(cloudId));
      }
      return;
    }

    final routineId = int.tryParse(item.entityId);
    if (routineId == null) return;
    final routine = await _database.routineDao.getRoutineById(routineId);
    if (routine == null) return;
    final cloudId = _stableRemoteId(
      entityKind: 'routine',
      localEntityId: routine.id.toString(),
      existingRemoteId: routine.cloudId,
    );
    final payload = {
      'id': cloudId,
      'owner_user_id': ownerUserId,
      'title': routine.title,
      'steps_json': routine.stepsJson,
      'icon_key': routine.emoji,
      'color_hex': _toSignedInt32(routine.colorHex),
      'is_pinned': routine.isPinned,
      'pinned_at': routine.pinnedAt?.toIso8601String(),
      'version': routine.version,
      'created_at': routine.createdAt.toIso8601String(),
      'updated_at': routine.updatedAt.toIso8601String(),
    };
    await _remoteRoutineDataSource.upsert(payload);
    await _database.routineDao.markRoutineSynced(
      id: routine.id,
      cloudId: cloudId,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> _syncReminderItem(
    SyncOutboxItem item,
    String ownerUserId,
  ) async {
    if (item.operation == SyncOperation.delete) {
      final cloudId = item.payload?['cloudId']?.toString();
      if (cloudId != null && cloudId.isNotEmpty) {
        await _remoteReminderDataSource.delete(_toSupabaseUuid(cloudId));
      }
      return;
    }

    final reminderId = int.tryParse(item.entityId);
    if (reminderId == null) return;
    final reminder = await _database.routineReminderDao.getReminderById(
      reminderId,
    );
    if (reminder == null) return;
    final routine = await _database.routineDao.getRoutineById(
      reminder.routineId,
    );
    if (routine == null) {
      // Routine no longer exists locally. The reminder can't be uploaded (FK),
      // and keeping it around will keep the outbox stuck.
      await _database.routineReminderDao.deleteReminder(reminder.id);
      return;
    }
    final routineCloudId = _stableRemoteId(
      entityKind: 'routine',
      localEntityId: routine.id.toString(),
      existingRemoteId: routine.cloudId,
    );
    if (routineCloudId.isEmpty) {
      throw StateError('Routine must sync before its reminders.');
    }
    final cloudId = _stableRemoteId(
      entityKind: 'reminder',
      localEntityId: reminder.id.toString(),
      existingRemoteId: reminder.cloudId,
    );
    await _remoteReminderDataSource.upsert({
      'id': cloudId,
      'owner_user_id': ownerUserId,
      'routine_id': routineCloudId,
      'day_of_week': reminder.dayOfWeek,
      'time': reminder.time,
      'is_enabled': reminder.isEnabled,
      'created_at': reminder.createdAt.toIso8601String(),
      'updated_at': reminder.updatedAt.toIso8601String(),
    });
    await _database.routineReminderDao.markReminderSynced(
      reminderId: reminder.id,
      cloudId: cloudId,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> _syncRunItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      await _remoteRunDataSource.delete(_toSupabaseUuid(item.entityId));
      return;
    }

    final run = await _database.routineRunDao.getRunById(item.entityId);
    if (run == null) return;

    final routine = await _resolveRoutineForRun(run.routineId);
    final routineCloudId = _routineCloudIdForRun(run.routineId, routine);

    final syncedRun = await _uploadRunProofs(run, ownerUserId);
    final payload = {
      'id': _toSupabaseUuid(syncedRun.id),
      'owner_user_id': ownerUserId,
      'routine_id': routineCloudId == null || routineCloudId.isEmpty
          ? null
          : routineCloudId,
      'routine_title': syncedRun.routineTitle,
      'finished_at': syncedRun.finishedAt.toIso8601String(),
      'step_completion_data': syncedRun.stepCompletionData,
      'updated_at': syncedRun.updatedAt.toIso8601String(),
    };
    await _remoteRunDataSource.upsert(payload);
    await _database.routineRunDao.markRunSynced(
      id: syncedRun.id,
      ownerUserId: ownerUserId,
      syncedAt: DateTime.now(),
      syncMetadataJson: syncedRun.syncMetadataJson,
    );
  }

  String? _routineCloudIdForRun(String routineReference, Routine? routine) {
    final trimmed = routineReference.trim();
    if (routine != null) {
      return _stableRemoteId(
        entityKind: 'routine',
        localEntityId: routine.id.toString(),
        existingRemoteId: routine.cloudId,
      );
    }
    if (trimmed.isEmpty) {
      return null;
    }
    if (_looksLikeUuid(trimmed)) {
      return _toSupabaseUuid(trimmed);
    }
    final parsedLocalId = int.tryParse(trimmed);
    return _stableRemoteId(
      entityKind: 'routine',
      localEntityId: (parsedLocalId ?? trimmed).toString(),
      existingRemoteId: null,
    );
  }

  Future<void> _syncSessionItem(SyncOutboxItem item, String ownerUserId) async {
    if (item.operation == SyncOperation.delete) {
      await _remoteSessionDataSource.delete(_toSupabaseUuid(item.entityId));
      return;
    }

    final row = await _database.routineSessionDao.getSessionById(item.entityId);
    if (row == null) return;
    final session = _sessionFromRow(row);
    final syncedSession = await _uploadSessionProofs(session, ownerUserId);
    final remotePayload = {
      'id': _toSupabaseUuid(syncedSession.sessionId),
      'owner_user_id': ownerUserId,
      'payload_json': syncedSession.toJson(),
      'updated_at': syncedSession.updatedAt.toIso8601String(),
    };
    await _remoteSessionDataSource.upsert(remotePayload);
    final syncedMetadata =
        (syncedSession.syncMetadata ??
                const RoutineSessionSyncMetadata(needsSync: false))
            .copyWith(
              needsSync: false,
              remoteSessionId: syncedSession.sessionId,
              lastSyncedAt: DateTime.now(),
              lastSyncAttemptAt: DateTime.now(),
            );
    await _database.routineSessionDao.insertOrUpdateSession(
      RoutineSessionRow(
        sessionId: row.sessionId,
        routineId: row.routineId,
        routineTitleSnapshot: row.routineTitleSnapshot,
        workspaceId: row.workspaceId,
        ownerUserId: ownerUserId,
        storageScope: row.storageScope,
        startedAt: row.startedAt,
        updatedAt: DateTime.now(),
        status: row.status,
        currentStepIndex: row.currentStepIndex,
        totalStepCount: row.totalStepCount,
        baseRoutineVersion: row.baseRoutineVersion,
        stepStatesJson: jsonEncode(
          syncedSession.stepStates.map((state) => state.toJson()).toList(),
        ),
        routineSnapshotJson: row.routineSnapshotJson,
        syncMetadataJson: jsonEncode(syncedMetadata.toJson()),
        completedAt: row.completedAt,
        discardedAt: row.discardedAt,
      ),
    );
  }

  Future<RoutineRun> _uploadRunProofs(
    RoutineRun run,
    String ownerUserId,
  ) async {
    final raw = run.stepCompletionData;
    if (raw == null || raw.isEmpty) {
      return run;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return run;
    }
    final steps = (decoded['steps'] as List<dynamic>? ?? const []);
    var changed = false;
    final updatedSteps = <Map<String, dynamic>>[];
    for (var index = 0; index < steps.length; index++) {
      final step = Map<String, dynamic>.from(steps[index] as Map);
      final proofAssets = (step['proofAssets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => RoutineSessionProofAsset.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      if (proofAssets.isEmpty) {
        updatedSteps.add(step);
        continue;
      }

      final updatedAssets = <RoutineSessionProofAsset>[];
      for (final asset in proofAssets) {
        if (asset.remoteObjectKey != null &&
            asset.remoteObjectKey!.isNotEmpty) {
          updatedAssets.add(asset);
          continue;
        }
        final uploaded = await _proofStorage.uploadProofAsset(
          asset: asset,
          ownerUserId: ownerUserId,
          entityType: 'runs',
          entityId: run.id,
        );
        updatedAssets.add(uploaded);
        changed = true;
      }
      step['proofAssets'] = updatedAssets
          .map((asset) => asset.toJson())
          .toList();
      step['photos'] = updatedAssets
          .map((asset) => asset.localRelativePath)
          .toList();
      updatedSteps.add(step);
    }

    if (!changed) {
      return run;
    }
    decoded['steps'] = updatedSteps;
    final updatedRun = RoutineRun(
      id: run.id,
      routineId: run.routineId,
      routineTitle: run.routineTitle,
      finishedAt: run.finishedAt,
      stepCompletionData: jsonEncode(decoded),
      ownerUserId: ownerUserId,
      syncStatus: 'pendingUpload',
      lastSyncedAt: run.lastSyncedAt,
      syncMetadataJson: run.syncMetadataJson,
      updatedAt: DateTime.now(),
    );
    await _database.routineRunDao.insertOrUpdateRun(updatedRun);
    return updatedRun;
  }

  Future<RoutineSession> _uploadSessionProofs(
    RoutineSession session,
    String ownerUserId,
  ) async {
    var changed = false;
    final updatedStates = <RoutineSessionStepState>[];
    for (final stepState in session.stepStates) {
      final updatedAssets = <RoutineSessionProofAsset>[];
      for (final asset in stepState.proofAssets) {
        if (asset.remoteObjectKey != null &&
            asset.remoteObjectKey!.isNotEmpty) {
          updatedAssets.add(asset);
          continue;
        }
        final uploaded = await _proofStorage.uploadProofAsset(
          asset: asset,
          ownerUserId: ownerUserId,
          entityType: 'sessions',
          entityId: session.sessionId,
        );
        updatedAssets.add(uploaded);
        changed = true;
      }
      updatedStates.add(stepState.copyWith(proofAssets: updatedAssets));
    }
    if (!changed) {
      return session;
    }
    return session.copyWith(
      ownerUserId: ownerUserId,
      stepStates: updatedStates,
      updatedAt: DateTime.now(),
      syncMetadata:
          (session.syncMetadata ??
                  const RoutineSessionSyncMetadata(needsSync: true))
              .copyWith(needsSync: true),
    );
  }

  RoutineSession _sessionFromRow(RoutineSessionRow row) {
    return RoutineSession.fromJson({
      'sessionId': row.sessionId,
      'routineId': row.routineId,
      'routineTitleSnapshot': row.routineTitleSnapshot,
      'workspaceId': row.workspaceId,
      'ownerUserId': row.ownerUserId,
      'storageScope': row.storageScope,
      'startedAt': row.startedAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'status': row.status,
      'currentStepIndex': row.currentStepIndex,
      'totalStepCount': row.totalStepCount,
      'baseRoutineVersion': row.baseRoutineVersion,
      'routineSnapshotSteps': jsonDecode(row.routineSnapshotJson),
      'stepStates': jsonDecode(row.stepStatesJson),
      'syncMetadata': row.syncMetadataJson == null
          ? null
          : jsonDecode(row.syncMetadataJson!),
      'completedAt': row.completedAt?.toIso8601String(),
      'discardedAt': row.discardedAt?.toIso8601String(),
    });
  }

  bool _looksOffline(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('offline') ||
        normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection closed') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout') ||
        normalized.contains('network request failed');
  }

  String _failureMessageForError(Object error) {
    if (_looksOffline(error)) {
      return 'You\'re offline. Changes will sync later.';
    }
    return 'Pebble couldn\'t finish syncing everything. Try again.';
  }

  Future<void> _refreshRuntimeState({bool isRunning = false}) async {
    final pendingItems = await _outbox.pendingItems();
    final nextRetryAt = pendingItems
        .where((item) => item.nextAttemptAt != null)
        .map((item) => item.nextAttemptAt!)
        .fold<DateTime?>(
          null,
          (earliest, next) =>
              earliest == null || next.isBefore(earliest) ? next : earliest,
        );
    _setRuntimeState(
      CloudSyncRuntimeState(
        isRunning: isRunning,
        pendingCount: pendingItems.length,
        nextRetryAt: nextRetryAt,
      ),
    );
    _scheduleNextRetry(nextRetryAt);
  }

  void _setRuntimeState(CloudSyncRuntimeState state) {
    _ref.read(cloudSyncRuntimeStateProvider.notifier).state = state;
  }

  void _scheduleNextRetry(DateTime? nextRetryAt) {
    _retryTimer?.cancel();
    if (_isRunning || nextRetryAt == null) {
      return;
    }
    final delay = nextRetryAt.difference(DateTime.now());
    _retryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(kick()),
    );
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}

final cloudSyncRuntimeStateProvider = StateProvider<CloudSyncRuntimeState>(
  (ref) => const CloudSyncRuntimeState.idle(),
);

final cloudSyncCoordinatorProvider = Provider<CloudSyncCoordinator>((ref) {
  final db = ref.read(localDbProvider);
  final coordinator = CloudSyncCoordinator(
    ref: ref,
    database: db,
    outbox: ref.read(syncOutboxRepositoryProvider),
    remoteRoutineDataSource: ref.read(remoteRoutineDataSourceProvider),
    remoteReminderDataSource: ref.read(remoteRoutineReminderDataSourceProvider),
    remoteRunDataSource: ref.read(remoteRoutineRunDataSourceProvider),
    remoteSessionDataSource: ref.read(remoteRoutineSessionDataSourceProvider),
    proofStorage: ref.read(routineSessionProofStorageProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
