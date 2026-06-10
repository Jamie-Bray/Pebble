import 'package:drift/drift.dart';

import 'package:pebble_routines/core/database/local_db.dart';

part 'sync_outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<LocalDb>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  Future<void> enqueue(SyncOutboxRow row) {
    return into(syncOutbox).insertOnConflictUpdate(row);
  }

  Future<SyncOutboxRow?> findMatchingPending({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return (select(syncOutbox)
          ..where(
            (tbl) =>
                tbl.entityType.equals(entityType) &
                tbl.entityId.equals(entityId) &
                tbl.operation.equals(operation),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> refreshPendingItem({required String id, String? payloadJson}) {
    return (update(syncOutbox)..where((tbl) => tbl.id.equals(id))).write(
      SyncOutboxCompanion(
        payloadJson: Value(payloadJson),
        attemptCount: const Value(0),
        nextAttemptAt: const Value(null),
        lastErrorSummary: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<SyncOutboxRow>> dueItems(DateTime now) {
    return (select(syncOutbox)
          ..where(
            (tbl) =>
                tbl.nextAttemptAt.isNull() |
                tbl.nextAttemptAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.createdAt),
            (tbl) => OrderingTerm.asc(tbl.updatedAt),
          ]))
        .get();
  }

  Future<List<SyncOutboxRow>> allItems() {
    return (select(syncOutbox)..orderBy([
          (tbl) => OrderingTerm.asc(tbl.createdAt),
          (tbl) => OrderingTerm.asc(tbl.updatedAt),
        ]))
        .get();
  }

  Stream<List<SyncOutboxRow>> watchItems() {
    return (select(
      syncOutbox,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])).watch();
  }

  Future<void> deleteItem(String id) {
    return (delete(syncOutbox)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Clears the retry backoff on every queued item so a user-initiated sync
  /// gives long-failing items a fresh run of automatic retries.
  Future<void> resetRetrySchedules() {
    return update(syncOutbox).write(
      SyncOutboxCompanion(
        attemptCount: const Value(0),
        nextAttemptAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateRetry({
    required String id,
    required int attemptCount,
    required DateTime nextAttemptAt,
    String? lastErrorSummary,
  }) {
    return (update(syncOutbox)..where((tbl) => tbl.id.equals(id))).write(
      SyncOutboxCompanion(
        attemptCount: Value(attemptCount),
        nextAttemptAt: Value(nextAttemptAt),
        lastErrorSummary: Value(lastErrorSummary),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
