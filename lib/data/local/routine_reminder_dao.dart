import 'package:drift/drift.dart';
import 'package:pebble_routines/core/database/local_db.dart';

part 'routine_reminder_dao.g.dart';

@DriftAccessor(tables: [RoutineReminders])
class RoutineReminderDao extends DatabaseAccessor<LocalDb>
    with _$RoutineReminderDaoMixin {
  RoutineReminderDao(super.db);

  /// Get all reminders for a specific routine
  Future<List<RoutineReminder>> getRemindersForRoutine(int routineId) {
    return (select(routineReminders)
          ..where((r) => r.routineId.equals(routineId))
          ..orderBy([
            (r) => OrderingTerm.asc(r.dayOfWeek),
            (r) => OrderingTerm.asc(r.time),
          ]))
        .get();
  }

  /// Get all enabled reminders for a specific routine
  Future<List<RoutineReminder>> getEnabledRemindersForRoutine(int routineId) {
    return (select(routineReminders)
          ..where(
            (r) => r.routineId.equals(routineId) & r.isEnabled.equals(true),
          )
          ..orderBy([
            (r) => OrderingTerm.asc(r.dayOfWeek),
            (r) => OrderingTerm.asc(r.time),
          ]))
        .get();
  }

  /// Add a new reminder
  Future<int> addReminder(
    RoutineRemindersCompanion reminder, {
    bool markPendingUpload = true,
  }) {
    return into(routineReminders).insert(
      reminder.copyWith(
        updatedAt: reminder.updatedAt.present
            ? reminder.updatedAt
            : Value(DateTime.now()),
        syncStatus: markPendingUpload
            ? const Value('pendingUpload')
            : reminder.syncStatus,
      ),
    );
  }

  /// Update an existing reminder
  Future<bool> updateReminder(
    RoutineReminder reminder, {
    bool markPendingUpload = true,
  }) async {
    await update(routineReminders).replace(
      reminder.copyWith(
        updatedAt: markPendingUpload ? DateTime.now() : reminder.updatedAt,
        syncStatus: markPendingUpload ? 'pendingUpload' : reminder.syncStatus,
      ),
    );
    return true; // replace returns void, so we assume success
  }

  Future<RoutineReminder?> getReminderById(int reminderId) {
    return (select(
      routineReminders,
    )..where((r) => r.id.equals(reminderId))).getSingleOrNull();
  }

  Future<RoutineReminder?> getReminderByCloudId(String cloudId) {
    return (select(
      routineReminders,
    )..where((r) => r.cloudId.equals(cloudId))).getSingleOrNull();
  }

  /// Delete a reminder
  Future<bool> deleteReminder(int reminderId) async {
    final result = await (delete(
      routineReminders,
    )..where((r) => r.id.equals(reminderId))).go();
    return result > 0;
  }

  /// Toggle reminder enabled state
  Future<bool> toggleReminder(int reminderId, bool enabled) async {
    final result =
        await (update(
          routineReminders,
        )..where((r) => r.id.equals(reminderId))).write(
          RoutineRemindersCompanion(
            isEnabled: Value(enabled),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value('pendingUpload'),
          ),
        );
    return result > 0;
  }

  /// Delete all reminders for a routine
  Future<int> deleteRemindersForRoutine(int routineId) {
    return (delete(
      routineReminders,
    )..where((r) => r.routineId.equals(routineId))).go();
  }

  /// Delete all reminders across all routines
  Future<int> deleteAllReminders() {
    return delete(routineReminders).go();
  }

  /// Get all reminders across all routines
  Future<List<RoutineReminder>> getAllReminders() {
    return (select(routineReminders)..orderBy([
          (r) => OrderingTerm.asc(r.dayOfWeek),
          (r) => OrderingTerm.asc(r.time),
        ]))
        .get();
  }

  Future<void> markReminderSynced({
    required int reminderId,
    required String cloudId,
    required String ownerUserId,
    required DateTime syncedAt,
  }) {
    return (update(
      routineReminders,
    )..where((r) => r.id.equals(reminderId))).write(
      RoutineRemindersCompanion(
        cloudId: Value(cloudId),
        ownerUserId: Value(ownerUserId),
        syncStatus: const Value('synced'),
        lastSyncedAt: Value(syncedAt),
        updatedAt: Value(syncedAt),
      ),
    );
  }

  /// Get all enabled reminders across all routines.
  Future<List<RoutineReminder>> getAllEnabledReminders() {
    return (select(routineReminders)
          ..where((r) => r.isEnabled.equals(true))
          ..orderBy([
            (r) => OrderingTerm.asc(r.dayOfWeek),
            (r) => OrderingTerm.asc(r.time),
          ]))
        .get();
  }

  /// Get reminders grouped by day of week
  Future<Map<int, List<RoutineReminder>>> getRemindersByDay({
    int? routineId,
  }) async {
    final reminders = routineId != null
        ? await getRemindersForRoutine(routineId)
        : await getAllReminders();
    final Map<int, List<RoutineReminder>> grouped = {};

    for (final reminder in reminders) {
      if (!grouped.containsKey(reminder.dayOfWeek)) {
        grouped[reminder.dayOfWeek] = [];
      }
      grouped[reminder.dayOfWeek]!.add(reminder);
    }

    return grouped;
  }
}
