import 'package:drift/drift.dart';
import 'package:pebble_routines/core/database/local_db.dart';

part 'routine_dao.g.dart';

@DriftAccessor(tables: [Routines])
class RoutineDao extends DatabaseAccessor<LocalDb> with _$RoutineDaoMixin {
  RoutineDao(super.db);

  Future<void> insertOrUpdateRoutine(Routine routine) =>
      into(routines).insertOnConflictUpdate(routine);
  Future<int> insertRoutineCompanion(RoutinesCompanion routine) =>
      into(routines).insert(routine);
  Stream<List<Routine>> watchAllRoutines() => select(routines).watch();
  Future<List<Routine>> getAllRoutines() => select(routines).get();
  Future<void> deleteRoutine(int id) =>
      (delete(routines)..where((tbl) => tbl.id.equals(id))).go();

  Future<Routine?> getRoutineById(int id) =>
      (select(routines)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Routine?> getRoutineByCloudId(String cloudId) => (select(
    routines,
  )..where((tbl) => tbl.cloudId.equals(cloudId))).getSingleOrNull();

  Future<void> updateRoutinePinState({
    required int id,
    required bool isPinned,
    required DateTime? pinnedAt,
    required int version,
    required DateTime updatedAt,
    required String? ownerUserId,
    required String syncStatus,
  }) {
    return (update(routines)..where((tbl) => tbl.id.equals(id))).write(
      RoutinesCompanion(
        isPinned: Value(isPinned),
        pinnedAt: Value(pinnedAt),
        version: Value(version),
        updatedAt: Value(updatedAt),
        ownerUserId: Value(ownerUserId),
        syncStatus: Value(syncStatus),
      ),
    );
  }

  Future<void> markRoutineSynced({
    required int id,
    required String cloudId,
    required String ownerUserId,
    required DateTime syncedAt,
  }) {
    return (update(routines)..where((tbl) => tbl.id.equals(id))).write(
      RoutinesCompanion(
        cloudId: Value(cloudId),
        ownerUserId: Value(ownerUserId),
        syncStatus: const Value('synced'),
        lastSyncedAt: Value(syncedAt),
        updatedAt: Value(syncedAt),
      ),
    );
  }
}
