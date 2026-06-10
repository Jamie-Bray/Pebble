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

  group('retry backoff', () {
    test('items past the stuck threshold are parked out of dueItems', () async {
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '1',
        operation: SyncOperation.upsert,
      );
      final item = (await outbox.pendingItems()).single;

      await outbox.markRetry(
        item.id,
        Exception('still failing'),
        SyncOutboxRepositoryImpl.stuckAttemptThreshold,
      );

      expect(await outbox.dueItems(), isEmpty);
      final parked = (await outbox.pendingItems()).single;
      expect(
        parked.nextAttemptAt!.isAfter(
          DateTime.now().add(const Duration(days: 300)),
        ),
        isTrue,
      );
    });

    test('resetRetrySchedule revives parked items for retry', () async {
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '1',
        operation: SyncOperation.upsert,
      );
      final item = (await outbox.pendingItems()).single;
      await outbox.markRetry(
        item.id,
        Exception('still failing'),
        SyncOutboxRepositoryImpl.stuckAttemptThreshold,
      );
      expect(await outbox.dueItems(), isEmpty);

      await outbox.resetRetrySchedule();

      final revived = (await outbox.dueItems()).single;
      expect(revived.attemptCount, 0);
      expect(revived.nextAttemptAt, isNull);
    });
  });
}
