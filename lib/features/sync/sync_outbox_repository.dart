import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';

enum SyncEntityType {
  routine,
  reminder,
  run,
  session,
  proofAsset,

  /// Step voice prompts: `upload` carries a local routine id, `delete` a
  /// remote object key.
  guidanceAudio,
}

enum SyncOperation { upsert, delete, upload }

class SyncOutboxItem {
  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic>? payload;
  final int attemptCount;
  final String? lastErrorSummary;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.attemptCount,
    required this.lastErrorSummary,
    required this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
  });
}

abstract class SyncOutboxRepository {
  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    Map<String, dynamic>? payload,
  });

  /// Queues the item only when it is not queued already. Unlike [enqueue] it
  /// never touches an existing row, so sweeps (restore, the per-pass
  /// baseline) cannot reset a failing row's backoff.
  Future<void> ensureQueued({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
  });

  Future<List<SyncOutboxItem>> pendingItems();
  Future<List<SyncOutboxItem>> dueItems();
  Future<void> markComplete(String id);

  /// Removes [item] once it is backed up, unless it was re-queued while it
  /// was uploading (a newer edit). Returns whether it was removed.
  Future<bool> completeIfUnchanged(SyncOutboxItem item);

  /// Parks [id] without counting a failure, for an item that is waiting on
  /// another one (a reminder waiting for its routine). It is tried again at
  /// [until] when given (for example the routine's own next retry), else
  /// after a short while.
  Future<void> defer(String id, String reason, {DateTime? until});

  /// The queued row for this entity and operation, if there is one.
  Future<SyncOutboxItem?> findQueued({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
  });
  Future<void> markRetry(String id, Object error, int attemptCount);
  Future<void> resetRetrySchedule();
}

class SyncOutboxRepositoryImpl implements SyncOutboxRepository {
  SyncOutboxRepositoryImpl(this._db);

  /// Failures in a row after which an item counts as "stuck" and backup
  /// asks for attention. Pebble keeps retrying it in the background (see
  /// [retryDelayFor]); it is never parked for good.
  static const stuckAttemptThreshold = 5;

  /// The longest wait between automatic retries of a failing item.
  static const maxRetryDelay = Duration(minutes: 30);

  /// Wait before the retry after failure number [attemptCount]: 15 s, 30 s
  /// … 75 s for the first five failures, then doubling up to
  /// [maxRetryDelay].
  static Duration retryDelayFor(int attemptCount) {
    final attempts = attemptCount < 1 ? 1 : attemptCount;
    if (attempts <= 5) return Duration(seconds: attempts * 15);
    final doublings = (attempts - 5).clamp(0, 10);
    final delay = Duration(seconds: 75 * (1 << doublings));
    return delay > maxRetryDelay ? maxRetryDelay : delay;
  }

  /// How long a deferred item waits before it is tried again.
  static const deferDelay = Duration(seconds: 20);

  static const _uuid = Uuid();
  final LocalDb _db;

  @override
  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    Map<String, dynamic>? payload,
  }) async {
    final now = DateTime.now();

    if (operation == SyncOperation.delete) {
      final existingUpsert = await _db.syncOutboxDao.findMatchingPending(
        entityType: entityType.name,
        entityId: entityId,
        operation: SyncOperation.upsert.name,
      );
      if (existingUpsert != null) {
        await _db.syncOutboxDao.deleteItem(existingUpsert.id);
        final cloudId = payload?['cloudId']?.toString();
        if (cloudId == null || cloudId.isEmpty) {
          return;
        }
      }
    }

    final payloadJson = payload == null ? null : jsonEncode(payload);
    final existing = await _db.syncOutboxDao.findMatchingPending(
      entityType: entityType.name,
      entityId: entityId,
      operation: operation.name,
    );
    if (existing != null) {
      await _db.syncOutboxDao.refreshPendingItem(
        existing: existing,
        payloadJson: payloadJson,
      );
      return;
    }

    await _db.syncOutboxDao.enqueue(
      SyncOutboxRow(
        id: _uuid.v4(),
        entityType: entityType.name,
        entityId: entityId,
        operation: operation.name,
        payloadJson: payloadJson,
        attemptCount: 0,
        lastErrorSummary: null,
        nextAttemptAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> ensureQueued({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
  }) async {
    final existing = await _db.syncOutboxDao.findMatchingPending(
      entityType: entityType.name,
      entityId: entityId,
      operation: operation.name,
    );
    if (existing != null) return;
    final now = DateTime.now();
    await _db.syncOutboxDao.enqueue(
      SyncOutboxRow(
        id: _uuid.v4(),
        entityType: entityType.name,
        entityId: entityId,
        operation: operation.name,
        payloadJson: null,
        attemptCount: 0,
        lastErrorSummary: null,
        nextAttemptAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<SyncOutboxItem>> pendingItems() async {
    final rows = await _db.syncOutboxDao.allItems();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<List<SyncOutboxItem>> dueItems() async {
    final rows = await _db.syncOutboxDao.dueItems(DateTime.now());
    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> markComplete(String id) => _db.syncOutboxDao.deleteItem(id);

  @override
  Future<bool> completeIfUnchanged(SyncOutboxItem item) =>
      _db.syncOutboxDao.deleteItemIfUnchanged(item.id, item.updatedAt);

  @override
  Future<void> markRetry(String id, Object error, int attemptCount) {
    return _db.syncOutboxDao.updateRetry(
      id: id,
      attemptCount: attemptCount,
      nextAttemptAt: DateTime.now().add(retryDelayFor(attemptCount)),
      lastErrorSummary: summarizeError(error),
    );
  }

  @override
  Future<void> defer(String id, String reason, {DateTime? until}) async {
    final row = await (_db.select(
      _db.syncOutbox,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final soonest = DateTime.now().add(deferDelay);
    await _db.syncOutboxDao.updateRetry(
      id: id,
      attemptCount: row.attemptCount,
      nextAttemptAt: until != null && until.isAfter(soonest) ? until : soonest,
      lastErrorSummary: reason,
    );
  }

  @override
  Future<SyncOutboxItem?> findQueued({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
  }) async {
    final row = await _db.syncOutboxDao.findMatchingPending(
      entityType: entityType.name,
      entityId: entityId,
      operation: operation.name,
    );
    return row == null ? null : _mapRow(row);
  }

  /// The stored error: its type and message, trimmed so one huge server
  /// response cannot bloat the outbox.
  static String summarizeError(Object error) {
    final text = error.toString();
    final type = error.runtimeType.toString();
    final typed = text.startsWith(type) ? text : '$type: $text';
    return typed.length <= 500 ? typed : '${typed.substring(0, 497)}...';
  }

  @override
  Future<void> resetRetrySchedule() {
    return _db.syncOutboxDao.resetRetrySchedules();
  }

  SyncOutboxItem _mapRow(SyncOutboxRow row) {
    final payload = row.payloadJson == null || row.payloadJson!.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(row.payloadJson!) as Map<String, dynamic>,
          );
    return SyncOutboxItem(
      id: row.id,
      entityType: SyncEntityType.values.firstWhere(
        (value) => value.name == row.entityType,
        orElse: () => SyncEntityType.routine,
      ),
      entityId: row.entityId,
      operation: SyncOperation.values.firstWhere(
        (value) => value.name == row.operation,
        orElse: () => SyncOperation.upsert,
      ),
      payload: payload,
      attemptCount: row.attemptCount,
      lastErrorSummary: row.lastErrorSummary,
      nextAttemptAt: row.nextAttemptAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  final db = ref.read(localDbProvider);
  return SyncOutboxRepositoryImpl(db);
});
