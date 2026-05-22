import 'package:drift/drift.dart';
import 'package:pebble_routines/core/database/local_db.dart';

part 'routine_run_dao.g.dart';

@DriftAccessor(tables: [RoutineRuns])
class RoutineRunDao extends DatabaseAccessor<LocalDb>
    with _$RoutineRunDaoMixin {
  RoutineRunDao(super.db);

  Future<void> insertOrUpdateRun(RoutineRun run) =>
      into(routineRuns).insertOnConflictUpdate(run);
  Stream<List<RoutineRun>> watchAllRuns() => select(routineRuns).watch();
  Future<List<RoutineRun>> getAllRuns() => select(routineRuns).get();
  Future<RoutineRun?> getRunById(String id) =>
      (select(routineRuns)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<RoutineRun?> watchLatestRunForRoutine(int routineId) {
    return (select(routineRuns)
          ..where((t) => t.routineId.equals(routineId.toString()))
          ..orderBy([(t) => OrderingTerm.desc(t.finishedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<int> deleteAllRuns() => delete(routineRuns).go();
  Future<int> deleteRun(String id) =>
      (delete(routineRuns)..where((t) => t.id.equals(id))).go();

  Future<int> deleteRunsOlderThan(DateTime cutoff) =>
      (delete(routineRuns)..where((t) => t.finishedAt.isSmallerThanValue(cutoff))).go();

  Future<void> markRunSynced({
    required String id,
    required String ownerUserId,
    required DateTime syncedAt,
    String? syncMetadataJson,
  }) {
    return (update(routineRuns)..where((t) => t.id.equals(id))).write(
      RoutineRunsCompanion(
        ownerUserId: Value(ownerUserId),
        syncStatus: const Value('synced'),
        lastSyncedAt: Value(syncedAt),
        syncMetadataJson: Value(syncMetadataJson),
        updatedAt: Value(syncedAt),
      ),
    );
  }
}
