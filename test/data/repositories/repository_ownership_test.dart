import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

const _policySignedInAsUser2 = CloudAccessPolicy(
  cachedOwnerUserId: 'user-2',
  personalCloudEnabled: false,
  canQueuePersonalSync: false,
  workspaceCloudEnabled: false,
  isSignedIn: true,
  isAccountSwitchBlocked: false,
);

Routine _routine({
  required int id,
  String? ownerUserId,
  String emoji = 'check',
}) {
  return Routine(
    id: id,
    title: 'Close down',
    stepsJson: jsonEncode(const []),
    createdAt: DateTime(2026, 1, 1),
    emoji: emoji,
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: DateTime(2026, 1, 1),
    cloudId: null,
    ownerUserId: ownerUserId,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
  );
}

void main() {
  late LocalDb database;
  late ProviderContainer container;

  setUp(() {
    database = LocalDb.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(database),
        cloudAccessPolicyProvider.overrideWithValue(_policySignedInAsUser2),
        cloudSyncCoordinatorProvider.overrideWithValue(_NoopSync()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('saveRoutine ownership stamping', () {
    test('preserves an existing different-account owner', () async {
      final repo = container.read(routineRepositoryProvider);

      await repo.saveRoutine(_routine(id: 1, ownerUserId: 'user-1'));

      final saved = await database.routineDao.getAllRoutines();
      expect(saved.single.ownerUserId, 'user-1');
    });

    test('stamps the cached owner onto unowned rows', () async {
      final repo = container.read(routineRepositoryProvider);

      await repo.saveRoutine(_routine(id: 1, ownerUserId: null));

      final saved = await database.routineDao.getAllRoutines();
      expect(saved.single.ownerUserId, 'user-2');
    });

    test('treats whitespace-only owner as unowned', () async {
      final repo = container.read(routineRepositoryProvider);

      await repo.saveRoutine(_routine(id: 1, ownerUserId: '  '));

      final saved = await database.routineDao.getAllRoutines();
      expect(saved.single.ownerUserId, 'user-2');
    });
  });

  group('deleting while backup is paused', () {
    test('still queues the server delete for a backed-up routine', () async {
      final repo = container.read(routineRepositoryProvider);
      await database.routineDao.insertOrUpdateRoutine(
        _routine(
          id: 1,
          ownerUserId: 'user-2',
        ).copyWith(cloudId: const drift.Value('cloud-1'), syncStatus: 'synced'),
      );

      await repo.deleteRoutine(1);

      final queued = await container
          .read(syncOutboxRepositoryProvider)
          .pendingItems();
      expect(queued, hasLength(1));
      expect(queued.single.entityType, SyncEntityType.routine);
      expect(queued.single.operation, SyncOperation.delete);
      expect(queued.single.payload?['cloudId'], 'cloud-1');
    });

    test('queues nothing for a routine that was never backed up', () async {
      final repo = container.read(routineRepositoryProvider);
      await database.routineDao.insertOrUpdateRoutine(_routine(id: 1));

      await repo.deleteRoutine(1);

      expect(
        await container.read(syncOutboxRepositoryProvider).pendingItems(),
        isEmpty,
      );
    });
  });

  group('normalizeLegacyRoutineIcons', () {
    test('rewrites a legacy emoji to its resolved icon key', () async {
      final repo = container.read(routineRepositoryProvider);
      await repo.saveRoutine(
        _routine(id: 1, ownerUserId: 'user-2', emoji: '🔒'),
      );

      await repo.normalizeLegacyRoutineIcons();

      final saved = await database.routineDao.getRoutineById(1);
      final expectedKey = RoutineIconCatalog.resolve('🔒').key;
      expect(saved?.emoji, expectedKey);
      // Resolving the stored value must now be a no-op (idempotent).
      expect(RoutineIconCatalog.resolve(saved?.emoji).key, expectedKey);
      // The migration is a real content change, so the version is bumped.
      expect(saved?.version, 2);
    });

    test('leaves an already-normalized routine untouched', () async {
      final repo = container.read(routineRepositoryProvider);
      await repo.saveRoutine(
        _routine(id: 1, ownerUserId: 'user-2', emoji: 'check'),
      );

      await repo.normalizeLegacyRoutineIcons();

      final saved = await database.routineDao.getRoutineById(1);
      expect(saved?.emoji, 'check');
      expect(saved?.version, 1, reason: 'no rewrite means no version bump');
    });
  });

  group('pinning', () {
    test('stamps pinnedAt when pinning and clears it when unpinning', () async {
      final repo = container.read(routineRepositoryProvider);

      await repo.saveRoutine(_routine(id: 1, ownerUserId: null));
      await repo.updateRoutinePinned(1, true);

      final pinned = await database.routineDao.getRoutineById(1);
      expect(pinned?.isPinned, isTrue);
      expect(pinned?.pinnedAt, isNotNull);

      await repo.updateRoutinePinned(1, false);

      final unpinned = await database.routineDao.getRoutineById(1);
      expect(unpinned?.isPinned, isFalse);
      expect(unpinned?.pinnedAt, isNull);
    });
  });
}

/// Repository writes kick a backup pass; these tests only check what was
/// queued.
class _NoopSync implements CloudSyncCoordinator {
  @override
  Future<void> kick() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
