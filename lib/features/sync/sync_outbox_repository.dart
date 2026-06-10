import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';

enum SyncEntityType { routine, reminder, run, session, proofAsset }

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

  Future<List<SyncOutboxItem>> pendingItems();
  Future<List<SyncOutboxItem>> dueItems();
  Future<void> markComplete(String id);
  Future<void> markRetry(String id, Object error, int attemptCount);
  Future<void> resetRetrySchedule();
}

class SyncOutboxRepositoryImpl implements SyncOutboxRepository {
  SyncOutboxRepositoryImpl(this._db);

  /// Attempts after which automatic retries effectively stop (the next
  /// attempt is parked a year out). Items at or past this are "stuck" and
  /// only revived by a user-initiated sync.
  static const stuckAttemptThreshold = 20;

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
        id: existing.id,
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
  Future<void> markRetry(String id, Object error, int attemptCount) {
    final nextAttemptAt = attemptCount >= stuckAttemptThreshold
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now().add(Duration(seconds: attemptCount.clamp(1, 5) * 15));
    return _db.syncOutboxDao.updateRetry(
      id: id,
      attemptCount: attemptCount,
      nextAttemptAt: nextAttemptAt,
      lastErrorSummary: error.toString(),
    );
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
