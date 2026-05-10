import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/local/routine_dao.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());

enum RoutineMoveDirection { up, down }

abstract class RoutineRepository {
  Stream<List<Routine>> watchRoutines();
  Future<void> saveRoutine(Routine routine);
  Future<void> deleteRoutine(int id);
  Future<void> updateRoutinePinned(int id, bool isPinned);
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction);
  Future<Routine?> getRoutineById(int id);
  Future<Routine> duplicateRoutine(int id);
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  });
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  });
  Future<(int?, String?)> getRoutineReminder(int id);
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId);
}

class RoutineRepositoryImpl implements RoutineRepository {
  final RoutineDao _dao;
  final Ref _ref;
  RoutineRepositoryImpl(this._dao, this._ref);

  @override
  Stream<List<Routine>> watchRoutines() => _dao.watchAllRoutines();

  @override
  Future<void> saveRoutine(Routine routine) async {
    final policy = _ref.read(cloudAccessPolicyProvider);
    final ownerUserId = policy.cachedOwnerUserId;
    final shouldQueue = policy.canQueuePersonalSync;
    final prepared = Routine(
      id: routine.id,
      title: routine.title,
      stepsJson: routine.stepsJson,
      createdAt: routine.createdAt,
      emoji: routine.emoji,
      colorHex: routine.colorHex,
      isPinned: routine.isPinned,
      pinnedAt: routine.pinnedAt,
      reminderDay: routine.reminderDay,
      reminderTime: routine.reminderTime,
      version: routine.version,
      updatedAt: DateTime.now(),
      cloudId: routine.cloudId,
      ownerUserId: ownerUserId ?? routine.ownerUserId,
      syncStatus: shouldQueue ? 'pendingUpload' : routine.syncStatus,
      lastSyncedAt: routine.lastSyncedAt,
    );
    await _dao.insertOrUpdateRoutine(prepared);
    if (shouldQueue) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.routine,
            entityId: prepared.id.toString(),
            operation: SyncOperation.upsert,
          );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<void> deleteRoutine(int id) async {
    final existing = await _dao.getRoutineById(id);
    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      // Ensure reminder rows don't linger orphaned. Orphans can keep the sync
      // queue stuck if they reference a deleted routine.
      final reminderDao = _dao.attachedDatabase.routineReminderDao;
      final reminders = await reminderDao.getRemindersForRoutine(id);
      for (final reminder in reminders) {
        final cloudId = reminder.cloudId;
        if (cloudId != null && cloudId.isNotEmpty) {
          await _ref
              .read(syncOutboxRepositoryProvider)
              .enqueue(
                entityType: SyncEntityType.reminder,
                entityId: reminder.id.toString(),
                operation: SyncOperation.delete,
                payload: {'cloudId': cloudId},
              );
        }
      }
      await reminderDao.deleteRemindersForRoutine(id);

      final routineCloudId = existing?.cloudId;
      if (routineCloudId != null && routineCloudId.isNotEmpty) {
        await _ref
            .read(syncOutboxRepositoryProvider)
            .enqueue(
              entityType: SyncEntityType.routine,
              entityId: id.toString(),
              operation: SyncOperation.delete,
              payload: {'cloudId': routineCloudId},
            );
      }
    } else {
      await _dao.attachedDatabase.routineReminderDao.deleteRemindersForRoutine(
        id,
      );
    }
    await _dao.deleteRoutine(id);
    await _ref.read(cloudSyncCoordinatorProvider).kick();
  }

  @override
  Future<void> updateRoutinePinned(int id, bool isPinned) =>
      _updatePinnedAndSync(id, isPinned);

  @override
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async {
    final routines = await _dao.getAllRoutines();
    routines.sort(_compareRoutineListOrder);

    final currentIndex = routines.indexWhere((routine) => routine.id == id);
    if (currentIndex == -1) {
      return false;
    }

    final targetIndex = direction == RoutineMoveDirection.up
        ? currentIndex - 1
        : currentIndex + 1;
    if (targetIndex < 0 || targetIndex >= routines.length) {
      return false;
    }

    final current = routines[currentIndex];
    final target = routines[targetIndex];
    if (current.isPinned != target.isPinned) {
      return false;
    }

    await _dao.updateRoutineCreatedAt(current.id, target.createdAt);
    await _dao.updateRoutineCreatedAt(target.id, current.createdAt);

    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      final outbox = _ref.read(syncOutboxRepositoryProvider);
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: current.id.toString(),
        operation: SyncOperation.upsert,
      );
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: target.id.toString(),
        operation: SyncOperation.upsert,
      );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }

    return true;
  }

  int _compareRoutineListOrder(Routine a, Routine b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  Future<void> _updatePinnedAndSync(int id, bool isPinned) async {
    await _dao.updateRoutinePinned(id, isPinned);
    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.routine,
            entityId: id.toString(),
            operation: SyncOperation.upsert,
          );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<Routine?> getRoutineById(int id) => _dao.getRoutineById(id);

  @override
  Future<Routine> duplicateRoutine(int id) async {
    final original = await _dao.getRoutineById(id);
    if (original == null) {
      throw Exception('Routine not found');
    }

    // Create a duplicate with modified title
    final duplicate = Routine(
      id: 0, // This will be auto-generated by the database
      title: '${original.title} (Copy)',
      stepsJson: original.stepsJson,
      createdAt: DateTime.now(),
      emoji: RoutineIconCatalog.resolve(original.emoji).key,
      colorHex: original.colorHex,
      isPinned: false,
      pinnedAt: null,
      version: 1,
      updatedAt: DateTime.now(),
      cloudId: null,
      ownerUserId: null,
      syncStatus: 'localOnly',
      lastSyncedAt: null,
    );

    await _dao.insertOrUpdateRoutine(duplicate);
    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.routine,
            entityId: duplicate.id.toString(),
            operation: SyncOperation.upsert,
          );
    }
    return duplicate;
  }

  @override
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {
    await _dao.updateRoutineAppearance(
      id: id,
      iconKey: iconKey,
      colorHex: colorHex,
    );
    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.routine,
            entityId: id.toString(),
            operation: SyncOperation.upsert,
          );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  }) async {
    // Use raw SQL to avoid depending on regenerated Drift code
    final db = _dao.attachedDatabase;
    await _ensureReminderColumns(db);
    if (reminderDay == null && reminderTime == null) {
      await db.customStatement(
        'UPDATE routines SET reminderDay = NULL, reminderTime = NULL WHERE id = ?;',
        [id],
      );
    } else {
      await db.customStatement(
        'UPDATE routines SET reminderDay = ?, reminderTime = ? WHERE id = ?;',
        [reminderDay, reminderTime, id],
      );
    }
    final policy = _ref.read(cloudAccessPolicyProvider);
    if (policy.canQueuePersonalSync) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.routine,
            entityId: id.toString(),
            operation: SyncOperation.upsert,
          );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<(int?, String?)> getRoutineReminder(int id) async {
    final db = _dao.attachedDatabase;
    await _ensureReminderColumns(db);
    final rows = await db
        .customSelect(
          'SELECT reminderDay, reminderTime FROM routines WHERE id = ? LIMIT 1;',
          variables: [Variable.withInt(id)],
          readsFrom: {db.routines},
        )
        .get();
    if (rows.isEmpty) return (null, null);
    final data = rows.first.data;
    final int? day = data['reminderDay'] as int?;
    final String? time = data['reminderTime'] as String?;
    return (day, time);
  }

  Future<void> _ensureReminderColumns(LocalDb db) async {
    try {
      final rows = await db.customSelect('PRAGMA table_info(routines);').get();
      final existing = rows
          .map((r) => (r.data['name'] as String?)?.toLowerCase())
          .whereType<String>()
          .toSet();
      if (!existing.contains('reminderday')) {
        await db.customStatement(
          'ALTER TABLE routines ADD COLUMN reminderDay INTEGER;',
        );
      }
      if (!existing.contains('remindertime')) {
        await db.customStatement(
          'ALTER TABLE routines ADD COLUMN reminderTime TEXT;',
        );
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId) {
    return _dao.attachedDatabase.routineRunDao.watchLatestRunForRoutine(
      routineId,
    );
  }
}

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  final db = ref.read(localDbProvider);
  return RoutineRepositoryImpl(db.routineDao, ref);
});

final latestRoutineRunProvider = StreamProvider.family<RoutineRun?, int>((
  ref,
  routineId,
) {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.watchLatestRunForRoutine(routineId);
});
