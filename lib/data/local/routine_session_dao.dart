import 'package:drift/drift.dart';

import 'package:pebble_routines/core/database/local_db.dart';

part 'routine_session_dao.g.dart';

@DriftAccessor(tables: [RoutineSessions])
class RoutineSessionDao extends DatabaseAccessor<LocalDb>
    with _$RoutineSessionDaoMixin {
  RoutineSessionDao(super.db);

  Future<void> insertOrUpdateSession(RoutineSessionRow session) {
    return into(routineSessions).insertOnConflictUpdate(session);
  }

  /// Records a backup on a session without touching what the person did:
  /// status, step progress, completion times and [updatedAt] stay as they
  /// are. [stepStatesJson] must be the row's current value with only photo
  /// backup keys added.
  Future<void> updateSyncFields({
    required String sessionId,
    required String? ownerUserId,
    required String stepStatesJson,
    required String syncMetadataJson,
  }) {
    return (update(
      routineSessions,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).write(
      RoutineSessionsCompanion(
        ownerUserId: Value(ownerUserId),
        stepStatesJson: Value(stepStatesJson),
        syncMetadataJson: Value(syncMetadataJson),
      ),
    );
  }

  Future<RoutineSessionRow?> getSessionById(String sessionId) {
    return (select(
      routineSessions,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).getSingleOrNull();
  }

  Stream<RoutineSessionRow?> watchSession(String sessionId) {
    return (select(
      routineSessions,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).watchSingleOrNull();
  }

  Future<RoutineSessionRow?> getActiveSessionForRoutine(int routineId) {
    return (select(routineSessions)
          ..where(
            (tbl) =>
                tbl.routineId.equals(routineId) & tbl.status.equals('active'),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<RoutineSessionRow>> listActiveSessions() {
    return (select(routineSessions)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();
  }

  /// Prunes finished (completed or discarded) sessions last touched before
  /// [cutoff]. An active session is someone's routine in progress, however
  /// old, so it is never removed here.
  Future<void> deleteSessionsOlderThan(DateTime cutoff) {
    return (delete(routineSessions)..where(
          (tbl) =>
              tbl.updatedAt.isSmallerThanValue(cutoff) &
              tbl.status.equals('active').not(),
        ))
        .go();
  }

  Future<List<RoutineSessionRow>> getAllSessions() {
    return (select(
      routineSessions,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])).get();
  }

  Stream<List<RoutineSessionRow>> watchActiveSessions() {
    return (select(routineSessions)
          ..where((tbl) => tbl.status.equals('active'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }
}
