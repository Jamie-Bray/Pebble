import 'package:drift/drift.dart';
import 'package:pebble_routines/core/database/local_db.dart';

part 'routine_composer_draft_dao.g.dart';

@DriftAccessor(tables: [RoutineComposerDrafts])
class RoutineComposerDraftDao extends DatabaseAccessor<LocalDb>
    with _$RoutineComposerDraftDaoMixin {
  RoutineComposerDraftDao(super.db);

  Future<RoutineComposerDraftRow?> getDraftById(String draftId) {
    return (select(
      routineComposerDrafts,
    )..where((tbl) => tbl.draftId.equals(draftId))).getSingleOrNull();
  }

  Stream<RoutineComposerDraftRow?> watchDraft(String draftId) {
    return (select(
      routineComposerDrafts,
    )..where((tbl) => tbl.draftId.equals(draftId))).watchSingleOrNull();
  }

  Future<RoutineComposerDraftRow?> getLatestDraft({
    required String mode,
    int? sourceRoutineId,
  }) async {
    final query = select(routineComposerDrafts)
      ..where((tbl) {
        final matchesMode = tbl.mode.equals(mode);
        final matchesSource = sourceRoutineId == null
            ? tbl.sourceRoutineId.isNull()
            : tbl.sourceRoutineId.equals(sourceRoutineId);
        return matchesMode & matchesSource;
      })
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<List<RoutineComposerDraftRow>> getCreateDrafts() {
    final query = select(routineComposerDrafts)
      ..where((tbl) => tbl.mode.equals('create') & tbl.sourceRoutineId.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    return query.get();
  }

  Future<void> upsertDraft(RoutineComposerDraftsCompanion companion) {
    return into(routineComposerDrafts).insertOnConflictUpdate(companion);
  }

  Future<void> deleteDraft(String draftId) {
    return (delete(
      routineComposerDrafts,
    )..where((tbl) => tbl.draftId.equals(draftId))).go();
  }

  Future<void> deleteCreateDrafts() {
    return (delete(routineComposerDrafts)..where(
          (tbl) => tbl.mode.equals('create') & tbl.sourceRoutineId.isNull(),
        ))
        .go();
  }
}
