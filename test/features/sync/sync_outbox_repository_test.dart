import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

void main() {
  late LocalDb database;
  late SyncOutboxRepositoryImpl outbox;

  setUp(() {
    database = LocalDb.forTesting(NativeDatabase.memory());
    outbox = SyncOutboxRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<SyncOutboxItem> queueRoutine() async {
    await outbox.enqueue(
      entityType: SyncEntityType.routine,
      entityId: '1',
      operation: SyncOperation.upsert,
    );
    return (await outbox.pendingItems()).single;
  }

  group('retry backoff', () {
    test('a stuck item keeps being retried, never parked for good', () async {
      final item = await queueRoutine();

      await outbox.markRetry(
        item.id,
        Exception('still failing'),
        SyncOutboxRepositoryImpl.stuckAttemptThreshold + 20,
      );

      expect(await outbox.dueItems(), isEmpty);
      final waiting = (await outbox.pendingItems()).single;
      expect(
        waiting.nextAttemptAt!.isBefore(
          DateTime.now().add(
            SyncOutboxRepositoryImpl.maxRetryDelay + const Duration(minutes: 1),
          ),
        ),
        isTrue,
      );
    });

    test('backoff grows and is capped', () {
      expect(
        SyncOutboxRepositoryImpl.retryDelayFor(1),
        const Duration(seconds: 15),
      );
      expect(
        SyncOutboxRepositoryImpl.retryDelayFor(5),
        const Duration(seconds: 75),
      );
      expect(
        SyncOutboxRepositoryImpl.retryDelayFor(6),
        const Duration(seconds: 150),
      );
      expect(
        SyncOutboxRepositoryImpl.retryDelayFor(40),
        SyncOutboxRepositoryImpl.maxRetryDelay,
      );
    });

    test(
      'resetRetrySchedule makes items due now and keeps their failure count',
      () async {
        final item = await queueRoutine();
        await outbox.markRetry(item.id, Exception('still failing'), 7);
        expect(await outbox.dueItems(), isEmpty);

        await outbox.resetRetrySchedule();

        final revived = (await outbox.dueItems()).single;
        expect(revived.attemptCount, 7);
        expect(revived.nextAttemptAt, isNull);
      },
    );

    test('stores the error type with the message', () async {
      final item = await queueRoutine();
      await outbox.markRetry(item.id, StateError('boom'), 1);
      final failed = (await outbox.pendingItems()).single;
      expect(failed.lastErrorSummary, contains('StateError'));
      expect(failed.lastErrorSummary, contains('boom'));
    });
  });

  group('re-queueing', () {
    test('a new edit keeps the failure count and is due now', () async {
      final item = await queueRoutine();
      await outbox.markRetry(item.id, Exception('server said no'), 3);

      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '1',
        operation: SyncOperation.upsert,
      );

      final requeued = (await outbox.pendingItems()).single;
      expect(requeued.id, item.id);
      expect(requeued.attemptCount, 3);
      expect(requeued.nextAttemptAt, isNull);
      expect(await outbox.dueItems(), hasLength(1));
    });

    test('ensureQueued never resets a waiting row', () async {
      final item = await queueRoutine();
      await outbox.markRetry(item.id, Exception('server said no'), 2);

      await outbox.ensureQueued(
        entityType: SyncEntityType.routine,
        entityId: '1',
        operation: SyncOperation.upsert,
      );

      final row = (await outbox.pendingItems()).single;
      expect(row.attemptCount, 2);
      expect(row.nextAttemptAt, isNotNull);
      expect(await outbox.dueItems(), isEmpty);
    });

    test('ensureQueued adds a missing row', () async {
      await outbox.ensureQueued(
        entityType: SyncEntityType.run,
        entityId: 'run-1',
        operation: SyncOperation.upsert,
      );
      final row = (await outbox.dueItems()).single;
      expect(row.entityType, SyncEntityType.run);
      expect(row.attemptCount, 0);
    });
  });

  group('completing an item', () {
    test('removes it when nothing changed during the upload', () async {
      final item = await queueRoutine();
      expect(await outbox.completeIfUnchanged(item), isTrue);
      expect(await outbox.pendingItems(), isEmpty);
    });

    test('keeps it when an edit arrived during the upload', () async {
      final item = await queueRoutine();

      // The routine is edited while the older copy is uploading.
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '1',
        operation: SyncOperation.upsert,
      );

      expect(await outbox.completeIfUnchanged(item), isFalse);
      final kept = (await outbox.dueItems()).single;
      expect(kept.id, item.id);
    });

    test('defer waits without counting a failure', () async {
      final item = await queueRoutine();
      await outbox.defer(item.id, 'Waiting for its routine');
      final row = (await outbox.pendingItems()).single;
      expect(row.attemptCount, 0);
      expect(row.nextAttemptAt, isNotNull);
      expect(row.lastErrorSummary, 'Waiting for its routine');
    });
  });
}
