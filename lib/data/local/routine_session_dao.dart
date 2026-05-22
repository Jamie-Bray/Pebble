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

  Future<void> deleteSessionsOlderThan(DateTime cutoff) {
    return (delete(routineSessions)
          ..where((tbl) => tbl.updatedAt.isSmallerThanValue(cutoff)))
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
