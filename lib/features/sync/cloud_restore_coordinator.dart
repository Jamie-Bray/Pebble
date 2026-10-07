import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

class CloudRestoreCoordinator {
  CloudRestoreCoordinator({
    required LocalDb database,
    required RemoteRoutineDataSource remoteRoutineDataSource,
    required RemoteRoutineReminderDataSource remoteReminderDataSource,
    required RemoteRoutineRunDataSource remoteRunDataSource,
    required RemoteRoutineSessionDataSource remoteSessionDataSource,
    required SyncOutboxRepository outbox,
  }) : _database = database,
       _remoteRoutineDataSource = remoteRoutineDataSource,
       _remoteReminderDataSource = remoteReminderDataSource,
       _remoteRunDataSource = remoteRunDataSource,
       _remoteSessionDataSource = remoteSessionDataSource,
       _outbox = outbox;

  final LocalDb _database;
  final RemoteRoutineDataSource _remoteRoutineDataSource;
  final RemoteRoutineReminderDataSource _remoteReminderDataSource;
  final RemoteRoutineRunDataSource _remoteRunDataSource;
  final RemoteRoutineSessionDataSource _remoteSessionDataSource;
  final SyncOutboxRepository _outbox;
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// `"<entityType>:<entityId>"` for every local change still waiting to
  /// upload at the moment a record is merged. Such a row is never overwritten by
  /// the server copy: the change waiting would be lost.
  Set<String> _queuedChanges = const {};

  bool _hasQueuedChange(SyncEntityType type, String entityId) =>
      _queuedChanges.contains('${type.name}:$entityId');

  Future<void> bootstrapAndMerge(String ownerUserId) async {
    await _mergeRoutines(ownerUserId);
    await _mergeReminders(ownerUserId);
    await _mergeRuns(ownerUserId);
    await _mergeSessions(ownerUserId);
  }

  Future<void> _mergeRoutines(String ownerUserId) async {
    final remoteRoutines = await _remoteRoutineDataSource.fetchAll(ownerUserId);

    for (final remote in remoteRoutines) {
      await _mergeRecordSafely('routine', remote.id, () async {
        final locals = await _database.routineDao.getAllRoutines();
        final matching = locals.where(
          (local) => _normalizedCloudId(local.cloudId) == remote.id,
        );
        await _mergeRoutine(ownerUserId, remote, matching.firstOrNull);
      });
    }

    // Queue whatever this phone holds that the backup does not: new rows,
    // rows changed since their last upload, and rows the server lacks.
    // Rows that are already backed up are left alone, so a restore no
    // longer re-uploads everything.
    for (final local in await _database.routineDao.getAllRoutines()) {
      if (_routineNeedsUpload(local)) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.routine,
          entityId: local.id.toString(),
          operation: SyncOperation.upsert,
        );
      }
    }
  }

  Future<void> _mergeReminders(String ownerUserId) async {
    final remote = await _remoteReminderDataSource.fetchAll(ownerUserId);
    for (final record in remote) {
      await _mergeRecordSafely(
        'reminder',
        record.id,
        () => _mergeReminder(ownerUserId, record),
      );
    }

    final local = await _database.routineReminderDao.getAllReminders();
    for (final reminder in local.where(_reminderNeedsUpload)) {
      await _outbox.ensureQueued(
        entityType: SyncEntityType.reminder,
        entityId: reminder.id.toString(),
        operation: SyncOperation.upsert,
      );
    }
  }

  Future<void> _mergeRuns(String ownerUserId) async {
    final remoteRuns = await _remoteRunDataSource.fetchAll(ownerUserId);

    for (final remote in remoteRuns) {
      await _mergeRecordSafely(
        'run',
        remote.id,
        () async => _mergeRun(
          ownerUserId,
          remote,
          await _database.routineRunDao.getRunById(remote.id),
        ),
      );
    }

    for (final local in await _database.routineRunDao.getAllRuns()) {
      if (_runNeedsUpload(local)) {
        await _outbox.ensureQueued(
          entityType: SyncEntityType.run,
          entityId: local.id,
          operation: SyncOperation.upsert,
        );
      }
    }
  }

  Future<void> _mergeSessions(String ownerUserId) async {
    final remoteSessions = await _remoteSessionDataSource.fetchAll(ownerUserId);

    for (final remote in remoteSessions) {
      await _mergeRecordSafely(
        'session',
        remote.id,
        () => _mergeSession(ownerUserId, remote),
      );
    }

    final localSessions = await _database.routineSessionDao.getAllSessions();
    for (final local in localSessions.where(
      (session) => session.ownerUserId == null || session.ownerUserId!.isEmpty,
    )) {
      await _outbox.ensureQueued(
        entityType: SyncEntityType.session,
        entityId: local.sessionId,
        operation: SyncOperation.upsert,
      );
    }
  }

  /// A row is in the backup when it is marked synced and has not changed
  /// since that upload.
  static bool _changedSinceUpload({
    required String syncStatus,
    required DateTime? lastSyncedAt,
    required DateTime updatedAt,
  }) {
    if (syncStatus != 'synced' || lastSyncedAt == null) return true;
    return lastSyncedAt.isBefore(updatedAt);
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static bool _routineNeedsUpload(Routine routine) =>
      _isBlank(routine.cloudId) ||
      _isBlank(routine.ownerUserId) ||
      _changedSinceUpload(
        syncStatus: routine.syncStatus,
        lastSyncedAt: routine.lastSyncedAt,
        updatedAt: routine.updatedAt,
      );

  static bool _reminderNeedsUpload(RoutineReminder reminder) =>
      _isBlank(reminder.cloudId) ||
      _isBlank(reminder.ownerUserId) ||
      _changedSinceUpload(
        syncStatus: reminder.syncStatus,
        lastSyncedAt: reminder.lastSyncedAt,
        updatedAt: reminder.updatedAt,
      );

  static bool _runNeedsUpload(RoutineRun run) =>
      _isBlank(run.ownerUserId) ||
      _changedSinceUpload(
        syncStatus: run.syncStatus,
        lastSyncedAt: run.lastSyncedAt,
        updatedAt: run.updatedAt,
      );

  static bool _sessionNeedsUpload(RoutineSessionRow session) {
    if (_isBlank(session.ownerUserId)) return true;
    final metadataJson = session.syncMetadataJson;
    if (metadataJson == null || metadataJson.isEmpty) return false;
    try {
      final decoded = jsonDecode(metadataJson);
      return decoded is Map && decoded['needsSync'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _mergeRoutine(
    String ownerUserId,
    RemoteRoutineRecord remote,
    Routine? local,
  ) async {
    if (local == null) {
      await _database.routineDao.insertRoutineCompanion(
        RoutinesCompanion.insert(
          title: remote.title,
          stepsJson: remote.stepsJson,
          createdAt: remote.createdAt,
          emoji: drift.Value(remote.iconKey),
          colorHex: drift.Value(remote.colorHex),
          isPinned: drift.Value(remote.isPinned),
          pinnedAt: drift.Value(remote.pinnedAt),
          version: drift.Value(remote.version),
          updatedAt: drift.Value(remote.updatedAt),
          cloudId: drift.Value(remote.id),
          ownerUserId: drift.Value(ownerUserId),
          syncStatus: const drift.Value('synced'),
          lastSyncedAt: drift.Value(DateTime.now()),
        ),
      );
      return;
    }
    if (!_hasQueuedChange(SyncEntityType.routine, local.id.toString()) &&
        remote.updatedAt.isAfter(local.updatedAt)) {
      await _database.routineDao.insertOrUpdateRoutine(
        Routine(
          id: local.id,
          title: remote.title,
          stepsJson: remote.stepsJson,
          createdAt: local.createdAt,
          emoji: remote.iconKey,
          colorHex: remote.colorHex,
          isPinned: remote.isPinned,
          pinnedAt: remote.pinnedAt,
          reminderDay: local.reminderDay,
          reminderTime: local.reminderTime,
          version: remote.version,
          updatedAt: remote.updatedAt,
          cloudId: remote.id,
          ownerUserId: ownerUserId,
          syncStatus: 'synced',
          lastSyncedAt: DateTime.now(),
        ),
      );
    }
    // Otherwise the local copy is as new or newer; the sweep in
    // [_mergeRoutines] queues it only if it changed since its last upload.
  }

  Future<void> _mergeReminder(
    String ownerUserId,
    RemoteRoutineReminderRecord record,
  ) async {
    final existing = await _database.routineReminderDao.getReminderByCloudId(
      record.id,
    );
    if (existing != null) {
      if (!_hasQueuedChange(SyncEntityType.reminder, existing.id.toString()) &&
          record.updatedAt.isAfter(existing.updatedAt)) {
        await _database.routineReminderDao.updateReminder(
          RoutineReminder(
            id: existing.id,
            routineId: existing.routineId,
            dayOfWeek: record.dayOfWeek,
            time: record.time,
            isEnabled: record.isEnabled,
            createdAt: existing.createdAt,
            updatedAt: record.updatedAt,
            cloudId: record.id,
            ownerUserId: ownerUserId,
            syncStatus: 'synced',
            lastSyncedAt: DateTime.now(),
          ),
          markPendingUpload: false,
        );
      }
      return;
    }

    final localRoutine = await _findRoutineByCloudReference(
      record.routineCloudId,
    );
    if (localRoutine == null) {
      return;
    }
    await _database.routineReminderDao.addReminder(
      RoutineRemindersCompanion.insert(
        routineId: localRoutine.id,
        dayOfWeek: record.dayOfWeek,
        time: record.time,
        isEnabled: drift.Value(record.isEnabled),
        createdAt: drift.Value(record.createdAt),
        updatedAt: drift.Value(record.updatedAt),
        cloudId: drift.Value(record.id),
        ownerUserId: drift.Value(ownerUserId),
        syncStatus: const drift.Value('synced'),
        lastSyncedAt: drift.Value(DateTime.now()),
      ),
      markPendingUpload: false,
    );
  }

  Future<void> _mergeRun(
    String ownerUserId,
    RemoteRoutineRunRecord remote,
    RoutineRun? local,
  ) async {
    final normalizedRoutineId = await _normalizeRunRoutineReference(
      remote.routineId,
    );
    if (local == null) {
      await _database.routineRunDao.insertOrUpdateRun(
        RoutineRun(
          id: remote.id,
          routineId: normalizedRoutineId,
          routineTitle: remote.routineTitle,
          finishedAt: remote.finishedAt,
          stepCompletionData: remote.stepCompletionData,
          ownerUserId: ownerUserId,
          syncStatus: 'synced',
          lastSyncedAt: DateTime.now(),
          syncMetadataJson: null,
          updatedAt: remote.updatedAt,
        ),
      );
      return;
    }
    if (!_hasQueuedChange(SyncEntityType.run, local.id) &&
        remote.updatedAt.isAfter(local.updatedAt)) {
      await _database.routineRunDao.insertOrUpdateRun(
        RoutineRun(
          id: local.id,
          routineId: normalizedRoutineId.isNotEmpty
              ? normalizedRoutineId
              : local.routineId,
          routineTitle: remote.routineTitle,
          finishedAt: remote.finishedAt,
          stepCompletionData: remote.stepCompletionData,
          ownerUserId: ownerUserId,
          syncStatus: 'synced',
          lastSyncedAt: DateTime.now(),
          syncMetadataJson: local.syncMetadataJson,
          updatedAt: remote.updatedAt,
        ),
      );
    }
    // Otherwise the sweep in [_mergeRuns] queues it only if it changed
    // since its last upload.
  }

  Future<void> _mergeSession(
    String ownerUserId,
    RemoteRoutineSessionRecord remote,
  ) async {
    final payload = remote.payload;
    final jsonPayload = payload['payload'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['payload'] as Map<String, dynamic>)
        : payload;
    final entity = RoutineSession.fromJson(jsonPayload);
    // Match on the session's own id: the cloud row id differs for a session
    // taken over from another account.
    final local = await _database.routineSessionDao.getSessionById(
      entity.sessionId,
    );
    if (local == null) {
      await _database.routineSessionDao.insertOrUpdateSession(
        RoutineSessionRow(
          sessionId: entity.sessionId,
          routineId: entity.routineId,
          routineTitleSnapshot: entity.routineTitleSnapshot,
          workspaceId: entity.workspaceId,
          ownerUserId: ownerUserId,
          storageScope: entity.storageScope.name,
          startedAt: entity.startedAt,
          updatedAt: entity.updatedAt,
          status: entity.status.name,
          currentStepIndex: entity.currentStepIndex,
          totalStepCount: entity.totalStepCount,
          baseRoutineVersion: entity.baseRoutineVersion,
          stepStatesJson: jsonEncode(
            entity.stepStates.map((item) => item.toJson()).toList(),
          ),
          routineSnapshotJson: jsonEncode(
            entity.routineSnapshotSteps.map((item) => item.toJson()).toList(),
          ),
          syncMetadataJson: jsonEncode(
            (entity.syncMetadata ??
                    const RoutineSessionSyncMetadata(needsSync: false))
                .copyWith(remoteSessionId: remote.id)
                .toJson(),
          ),
          completedAt: entity.completedAt,
          discardedAt: entity.discardedAt,
        ),
      );
      return;
    }

    final localNeedsPriority =
        local.status == 'active' ||
        _hasQueuedChange(SyncEntityType.session, local.sessionId);
    if (!localNeedsPriority && remote.updatedAt.isAfter(local.updatedAt)) {
      await _database.routineSessionDao.insertOrUpdateSession(
        RoutineSessionRow(
          sessionId: entity.sessionId,
          routineId: entity.routineId,
          routineTitleSnapshot: entity.routineTitleSnapshot,
          workspaceId: entity.workspaceId,
          ownerUserId: ownerUserId,
          storageScope: entity.storageScope.name,
          startedAt: entity.startedAt,
          updatedAt: entity.updatedAt,
          status: entity.status.name,
          currentStepIndex: entity.currentStepIndex,
          totalStepCount: entity.totalStepCount,
          baseRoutineVersion: entity.baseRoutineVersion,
          stepStatesJson: jsonEncode(
            entity.stepStates.map((item) => item.toJson()).toList(),
          ),
          routineSnapshotJson: jsonEncode(
            entity.routineSnapshotSteps.map((item) => item.toJson()).toList(),
          ),
          syncMetadataJson: jsonEncode(
            (entity.syncMetadata ??
                    const RoutineSessionSyncMetadata(needsSync: false))
                .copyWith(remoteSessionId: remote.id)
                .toJson(),
          ),
          completedAt: entity.completedAt,
          discardedAt: entity.discardedAt,
        ),
      );
    } else if (_sessionNeedsUpload(local)) {
      await _outbox.ensureQueued(
        entityType: SyncEntityType.session,
        entityId: local.sessionId,
        operation: SyncOperation.upsert,
      );
    }
  }

  /// One malformed remote record must not abort the whole restore: log it,
  /// skip it, and keep merging the rest of the account.
  Future<void> _mergeRecordSafely(
    String kind,
    String id,
    Future<void> Function() merge,
  ) async {
    try {
      await _database.transaction(() async {
        final pending = await _outbox.pendingItems();
        // A pending deletion is a tombstone until the server acknowledges
        // it. Restoring that row would undo the person's offline deletion.
        if (pending.any(
          (item) =>
              item.entityType.name == kind &&
              item.operation == SyncOperation.delete &&
              _normalizedCloudId(
                    item.payload?['cloudId']?.toString() ?? item.entityId,
                  ) ==
                  id,
        )) {
          return;
        }
        _queuedChanges = {
          for (final item in pending)
            '${item.entityType.name}:${item.entityId}',
        };
        await merge();
      });
    } catch (error) {
      debugPrint('Restore skipped remote $kind $id: $error');
    }
  }

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value.trim());

  String _toSupabaseUuid(String value) {
    final trimmed = value.trim();
    if (_looksLikeUuid(trimmed)) {
      return trimmed.toLowerCase();
    }
    return _uuid.v5(Namespace.url.value, 'vix.pebble/$trimmed');
  }

  String? _normalizedCloudId(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return _toSupabaseUuid(trimmed);
  }

  Future<Routine?> _findRoutineByCloudReference(
    String? routineReference,
  ) async {
    final normalized = _normalizedCloudId(routineReference);
    if (normalized == null) {
      return null;
    }
    return _database.routineDao.getRoutineByCloudId(normalized);
  }

  Future<String> _normalizeRunRoutineReference(String? routineReference) async {
    if (routineReference == null || routineReference.isEmpty) {
      return '';
    }
    final localRoutineId = int.tryParse(routineReference);
    if (localRoutineId != null) {
      return localRoutineId.toString();
    }
    final routine = await _findRoutineByCloudReference(routineReference);
    if (routine != null) {
      return routine.id.toString();
    }
    final normalizedCloudId = _normalizedCloudId(routineReference);
    return normalizedCloudId ?? routineReference;
  }
}

final cloudRestoreCoordinatorProvider = Provider<CloudRestoreCoordinator>((
  ref,
) {
  final db = ref.read(localDbProvider);
  return CloudRestoreCoordinator(
    database: db,
    remoteRoutineDataSource: ref.read(remoteRoutineDataSourceProvider),
    remoteReminderDataSource: ref.read(remoteRoutineReminderDataSourceProvider),
    remoteRunDataSource: ref.read(remoteRoutineRunDataSourceProvider),
    remoteSessionDataSource: ref.read(remoteRoutineSessionDataSourceProvider),
    outbox: ref.read(syncOutboxRepositoryProvider),
  );
});
