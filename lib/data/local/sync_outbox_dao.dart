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

  /// A newer change to a row that is already queued. The failure count is
  /// kept, so a row that keeps failing still reaches "needs attention"; only
  /// the backoff is cleared so the new change goes up straight away.
  ///
  /// [updatedAt] always moves forward by at least a second (dates are stored
  /// to the second), so a pass uploading the older copy can tell the row
  /// changed underneath it and keeps it queued.
  Future<void> refreshPendingItem({
    required SyncOutboxRow existing,
    String? payloadJson,
  }) {
    final now = DateTime.now();
    final bumped = existing.updatedAt.add(const Duration(seconds: 1));
    return (update(
      syncOutbox,
    )..where((tbl) => tbl.id.equals(existing.id))).write(
      SyncOutboxCompanion(
        payloadJson: Value(payloadJson),
        nextAttemptAt: const Value(null),
        updatedAt: Value(now.isAfter(bumped) ? now : bumped),
      ),
    );
  }

  /// Removes a finished row only if nothing re-queued it while it was being
  /// uploaded. Returns whether the row was removed.
  Future<bool> deleteItemIfUnchanged(String id, DateTime updatedAt) async {
    final removed =
        await (delete(syncOutbox)..where(
              (tbl) => tbl.id.equals(id) & tbl.updatedAt.equals(updatedAt),
            ))
            .go();
    return removed > 0;
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

  /// Makes every queued item due now, for a user-initiated "Back up now".
  /// Failure counts are kept so a change that still fails stays flagged.
  Future<void> resetRetrySchedules() {
    return update(
      syncOutbox,
    ).write(const SyncOutboxCompanion(nextAttemptAt: Value(null)));
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
