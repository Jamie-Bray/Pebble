import 'dart:convert';

import 'package:drift/drift.dart' as drift;
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

  Future<void> bootstrapAndMerge(String ownerUserId) async {
    await _mergeRoutines(ownerUserId);
    await _mergeReminders(ownerUserId);
    await _mergeRuns(ownerUserId);
    await _mergeSessions(ownerUserId);
  }

  Future<void> _mergeRoutines(String ownerUserId) async {
    final localRoutines = await _database.routineDao.getAllRoutines();
    final remoteRoutines = await _remoteRoutineDataSource.fetchAll(ownerUserId);
    final localByCloudId = {
      for (final routine in localRoutines)
        if (_normalizedCloudId(routine.cloudId) case final normalizedCloudId?)
          normalizedCloudId: routine,
    };

    for (final remote in remoteRoutines) {
      final local = localByCloudId[remote.id];
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
        continue;
      }
      if (remote.updatedAt.isAfter(local.updatedAt)) {
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
      } else {
        await _outbox.enqueue(
          entityType: SyncEntityType.routine,
          entityId: local.id.toString(),
          operation: SyncOperation.upsert,
        );
      }
    }

    for (final local in localRoutines.where(
      (routine) => routine.cloudId == null || routine.cloudId!.isEmpty,
    )) {
      await _outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: local.id.toString(),
        operation: SyncOperation.upsert,
      );
    }
  }

  Future<void> _mergeReminders(String ownerUserId) async {
    final remote = await _remoteReminderDataSource.fetchAll(ownerUserId);
    for (final record in remote) {
      final existing = await _database.routineReminderDao.getReminderByCloudId(
        record.id,
      );
      if (existing != null) {
        if (record.updatedAt.isAfter(existing.updatedAt)) {
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
        continue;
      }

      final localRoutine = await _findRoutineByCloudReference(
        record.routineCloudId,
      );
      if (localRoutine == null) {
        continue;
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

    final local = await _database.routineReminderDao.getAllReminders();
    for (final reminder in local.where(
      (item) => item.cloudId == null || item.cloudId!.isEmpty,
    )) {
      await _outbox.enqueue(
        entityType: SyncEntityType.reminder,
        entityId: reminder.id.toString(),
        operation: SyncOperation.upsert,
      );
    }
  }

  Future<void> _mergeRuns(String ownerUserId) async {
    final localRuns = await _database.routineRunDao.getAllRuns();
    final remoteRuns = await _remoteRunDataSource.fetchAll(ownerUserId);
    final localById = {for (final run in localRuns) run.id: run};

    for (final remote in remoteRuns) {
      final local = localById[remote.id];
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
        continue;
      }
      if (remote.updatedAt.isAfter(local.updatedAt)) {
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
      } else {
        await _outbox.enqueue(
          entityType: SyncEntityType.run,
          entityId: local.id,
          operation: SyncOperation.upsert,
        );
      }
    }

    for (final local in localRuns.where(
      (run) => run.ownerUserId == null || run.ownerUserId!.isEmpty,
    )) {
      await _outbox.enqueue(
        entityType: SyncEntityType.run,
        entityId: local.id,
        operation: SyncOperation.upsert,
      );
    }
  }

  Future<void> _mergeSessions(String ownerUserId) async {
    final localSessions = await _database.routineSessionDao.getAllSessions();
    final remoteSessions = await _remoteSessionDataSource.fetchAll(ownerUserId);
    final localById = {
      for (final session in localSessions) session.sessionId: session,
    };

    for (final remote in remoteSessions) {
      final payload = remote.payload;
      final jsonPayload = payload['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              payload['payload'] as Map<String, dynamic>,
            )
          : payload;
      final entity = RoutineSession.fromJson(jsonPayload);
      final local = localById[remote.id];
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
                  .copyWith(remoteSessionId: entity.sessionId)
                  .toJson(),
            ),
            completedAt: entity.completedAt,
            discardedAt: entity.discardedAt,
          ),
        );
        continue;
      }

      final localNeedsPriority = local.status == 'active';
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
                  .copyWith(remoteSessionId: entity.sessionId)
                  .toJson(),
            ),
            completedAt: entity.completedAt,
            discardedAt: entity.discardedAt,
          ),
        );
      } else {
        await _outbox.enqueue(
          entityType: SyncEntityType.session,
          entityId: local.sessionId,
          operation: SyncOperation.upsert,
        );
      }
    }

    for (final local in localSessions.where(
      (session) => session.ownerUserId == null || session.ownerUserId!.isEmpty,
    )) {
      await _outbox.enqueue(
        entityType: SyncEntityType.session,
        entityId: local.sessionId,
        operation: SyncOperation.upsert,
      );
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
