import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';

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

  group('normalizeLegacyRoutineIcons', () {
    test('rewrites a legacy emoji to its resolved icon key', () async {
      final repo = container.read(routineRepositoryProvider);
      await repo.saveRoutine(_routine(id: 1, ownerUserId: 'user-2', emoji: '🔒'));

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
