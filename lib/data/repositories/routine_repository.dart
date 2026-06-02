import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/local/routine_dao.dart';
import 'package:drift/drift.dart' show Variable, Value;
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
  Future<void> deleteRoutineReminder(RoutineReminder reminder);
  Future<void> deleteRoutineRemindersForRoutine(int routineId);
  Future<void> deleteAllRoutineReminders();
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
        await _enqueueReminderDelete(reminder);
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
    await _dao.attachedDatabase.routineComposerDraftDao
        .deleteEditDraftsForRoutine(id);
    await _dao.deleteRoutine(id);
    await _ref.read(cloudSyncCoordinatorProvider).kick();
  }

  @override
  Future<void> deleteRoutineReminder(RoutineReminder reminder) async {
    final db = _dao.attachedDatabase;
    final policy = _ref.read(cloudAccessPolicyProvider);
    var shouldKick = false;
    await db.transaction(() async {
      if (_shouldQueueReminderDelete(policy.canQueuePersonalSync, reminder)) {
        await _enqueueReminderDelete(reminder);
        shouldKick = true;
      }
      await db.routineReminderDao.deleteReminder(reminder.id);
    });
    if (shouldKick) {
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<void> deleteRoutineRemindersForRoutine(int routineId) async {
    final db = _dao.attachedDatabase;
    final reminderDao = db.routineReminderDao;
    final reminders = await reminderDao.getRemindersForRoutine(routineId);
    final policy = _ref.read(cloudAccessPolicyProvider);
    var shouldKick = false;
    await db.transaction(() async {
      for (final reminder in reminders) {
        if (_shouldQueueReminderDelete(policy.canQueuePersonalSync, reminder)) {
          await _enqueueReminderDelete(reminder);
          shouldKick = true;
        }
      }
      await reminderDao.deleteRemindersForRoutine(routineId);
    });
    if (shouldKick) {
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<void> deleteAllRoutineReminders() async {
    final db = _dao.attachedDatabase;
    final reminderDao = db.routineReminderDao;
    final reminders = await reminderDao.getAllReminders();
    final policy = _ref.read(cloudAccessPolicyProvider);
    var shouldKick = false;
    await db.transaction(() async {
      for (final reminder in reminders) {
        if (_shouldQueueReminderDelete(policy.canQueuePersonalSync, reminder)) {
          await _enqueueReminderDelete(reminder);
          shouldKick = true;
        }
      }
      await reminderDao.deleteAllReminders();
    });
    if (shouldKick) {
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  Future<void> _enqueueReminderDelete(RoutineReminder reminder) {
    final cloudId = reminder.cloudId;
    return _ref
        .read(syncOutboxRepositoryProvider)
        .enqueue(
          entityType: SyncEntityType.reminder,
          entityId: reminder.id.toString(),
          operation: SyncOperation.delete,
          payload: cloudId == null || cloudId.isEmpty
              ? null
              : {'cloudId': cloudId},
        );
  }

  bool _shouldQueueReminderDelete(
    bool canQueuePersonalSync,
    RoutineReminder reminder,
  ) {
    final cloudId = reminder.cloudId;
    return canQueuePersonalSync || (cloudId != null && cloudId.isNotEmpty);
  }

  @override
  Future<void> updateRoutinePinned(int id, bool isPinned) async {
    final existing = await getRoutineById(id);
    if (existing == null) return;
    final updated = existing.copyWith(
      isPinned: isPinned,
      version: existing.version + 1,
    );
    await saveRoutine(updated);
  }

  @override
  Future<Routine?> getRoutineById(int id) => _dao.getRoutineById(id);

  @override
  Future<Routine> duplicateRoutine(int id) async {
    final original = await _dao.getRoutineById(id);
    if (original == null) {
      throw Exception('Routine not found');
    }

    final now = DateTime.now();

    // Create a duplicate with modified title and a unique ID
    final duplicate = Routine(
      id: now.millisecondsSinceEpoch,
      title: '${original.title} (Copy)',
      stepsJson: original.stepsJson,
      createdAt: now,
      emoji: RoutineIconCatalog.resolve(original.emoji).key,
      colorHex: original.colorHex,
      isPinned: false,
      pinnedAt: null,
      version: 1,
      updatedAt: now,
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
  Future<bool> moveRoutine(int id, RoutineMoveDirection direction) async {
    final routines = await _dao.getAllRoutines();
    routines.sort(_compareRoutineListOrder);

    final currentIndex = routines.indexWhere((routine) => routine.id == id);
    if (currentIndex == -1) return false;

    final targetIndex = direction == RoutineMoveDirection.up
        ? currentIndex - 1
        : currentIndex + 1;

    if (targetIndex < 0 || targetIndex >= routines.length) return false;

    final current = routines[currentIndex];
    final target = routines[targetIndex];

    if (current.isPinned != target.isPinned) return false;

    final updatedCurrent = current.copyWith(
      createdAt: target.createdAt,
      version: current.version + 1,
    );
    final updatedTarget = target.copyWith(
      createdAt: current.createdAt,
      version: target.version + 1,
    );

    await saveRoutine(updatedCurrent);
    await saveRoutine(updatedTarget);
    return true;
  }

  int _compareRoutineListOrder(Routine a, Routine b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {
    final existing = await getRoutineById(id);
    if (existing == null) return;

    // Fall back to old value if null is provided
    final newEmoji = iconKey ?? existing.emoji;
    final newColorHex = colorHex ?? existing.colorHex;

    final updated = existing.copyWith(
      emoji: Value(newEmoji),
      colorHex: Value(newColorHex),
      version: existing.version + 1,
    );
    await saveRoutine(updated);
  }

  @override
  Future<void> updateRoutineReminder({
    required int id,
    int? reminderDay,
    String? reminderTime,
  }) async {
    final db = _dao.attachedDatabase;
    await _ensureReminderColumns(db);

    final existing = await getRoutineById(id);
    if (existing == null) return;

    // Use raw SQL update here because `copyWith` for generated Drift classes
    // doesn't natively support setting nullable fields to null without wrappers.
    // BUT we must also bump the version, updatedAt, and syncStatus!
    // Since saveRoutine handles all sync outbox and updatedAt logic, it's safer
    // to just let saveRoutine do its job, and handle the nullification in SQL first
    // if needed, OR just construct a new Routine. We'll construct a new Routine!

    final updated = Routine(
      id: existing.id,
      title: existing.title,
      stepsJson: existing.stepsJson,
      createdAt: existing.createdAt,
      emoji: existing.emoji,
      colorHex: existing.colorHex,
      isPinned: existing.isPinned,
      pinnedAt: existing.pinnedAt,
      reminderDay: reminderDay,
      reminderTime: reminderTime,
      version: existing.version + 1,
      updatedAt: existing.updatedAt,
      cloudId: existing.cloudId,
      ownerUserId: existing.ownerUserId,
      syncStatus: existing.syncStatus,
      lastSyncedAt: existing.lastSyncedAt,
    );

    await saveRoutine(updated);
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
