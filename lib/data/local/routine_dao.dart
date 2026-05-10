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

  Future<void> updateRoutinePinned(int id, bool isPinned) =>
      (update(routines)..where((tbl) => tbl.id.equals(id))).write(
        RoutinesCompanion(
          isPinned: Value(isPinned),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pendingUpload'),
        ),
      );

  Future<void> updateRoutineCreatedAt(int id, DateTime createdAt) =>
      (update(routines)..where((tbl) => tbl.id.equals(id))).write(
        RoutinesCompanion(
          createdAt: Value(createdAt),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value('pendingUpload'),
        ),
      );

  Future<Routine?> getRoutineById(int id) =>
      (select(routines)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<Routine?> getRoutineByCloudId(String cloudId) => (select(
    routines,
  )..where((tbl) => tbl.cloudId.equals(cloudId))).getSingleOrNull();

  Future<void> updateRoutineAppearance({
    required int id,
    String? iconKey,
    int? colorHex,
  }) async {
    final companion = RoutinesCompanion(
      // Backed by legacy `emoji` column for compatibility.
      emoji: iconKey != null ? Value(iconKey) : const Value.absent(),
      colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value('pendingUpload'),
    );
    await (update(
      routines,
    )..where((tbl) => tbl.id.equals(id))).write(companion);
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
