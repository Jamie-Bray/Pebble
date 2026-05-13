import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';

void main() {
  group('LocalDataOwnershipGuard', () {
    late LocalDb database;

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('allows sync when local data belongs to same account', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(ownerUserId: 'user-a'),
      );

      final report = await LocalDataOwnershipGuard.inspect(
        database: database,
        signedInUserId: 'user-a',
      );

      expect(report.state, LocalDataOwnershipState.sameOwnerOnly);
      expect(report.blocksCloudSync, isFalse);
    });

    test(
      'blocks sync when local data belongs to a different account',
      () async {
        await database.routineDao.insertOrUpdateRoutine(
          _routine(ownerUserId: 'user-a'),
        );

        final report = await LocalDataOwnershipGuard.inspect(
          database: database,
          signedInUserId: 'user-b',
        );

        expect(report.state, LocalDataOwnershipState.differentOwner);
        expect(report.blocksCloudSync, isTrue);
      },
    );

    test('blocks sync for unowned local data until the user chooses', () async {
      await database.routineDao.insertOrUpdateRoutine(_routine());

      final report = await LocalDataOwnershipGuard.inspect(
        database: database,
        signedInUserId: 'user-a',
      );

      expect(report.state, LocalDataOwnershipState.unownedOnly);
      expect(report.blocksCloudSync, isTrue);
    });

    test('links unowned local data to the signed-in account', () async {
      final linkedAt = DateTime(2026, 1, 3, 10);
      await database.routineDao.insertOrUpdateRoutine(_routine());
      await database.routineRunDao.insertOrUpdateRun(_run());
      await database.routineReminderDao.addReminder(_reminder());
      await database.routineSessionDao.insertOrUpdateSession(_session());

      final report = await LocalDataOwnershipGuard.linkUnownedLocalData(
        database: database,
        signedInUserId: 'user-a',
        linkedAt: linkedAt,
      );

      expect(report.state, LocalDataOwnershipState.sameOwnerOnly);
      expect(report.blocksCloudSync, isFalse);
      expect(
        (await database.routineDao.getAllRoutines()).single.ownerUserId,
        'user-a',
      );
      expect(
        (await database.routineRunDao.getAllRuns()).single.syncStatus,
        'pendingUpload',
      );
      expect(
        (await database.routineReminderDao.getAllReminders()).single.syncStatus,
        'pendingUpload',
      );
      final session =
          (await database.routineSessionDao.getAllSessions()).single;
      expect(session.ownerUserId, 'user-a');
      expect(session.syncMetadataJson, contains('"needsSync":true'));
    });

    test('does not link data owned by another account', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(ownerUserId: 'user-a'),
      );

      expect(
        () => LocalDataOwnershipGuard.linkUnownedLocalData(
          database: database,
          signedInUserId: 'user-b',
        ),
        throwsStateError,
      );

      final routine = (await database.routineDao.getAllRoutines()).single;
      expect(routine.ownerUserId, 'user-a');
    });
  });
}

Routine _routine({String? ownerUserId}) {
  return Routine(
    id: 1,
    title: 'Close down',
    stepsJson: jsonEncode(const []),
    createdAt: DateTime(2026, 1, 1),
    emoji: null,
    colorHex: null,
    isPinned: false,
    pinnedAt: null,
    reminderDay: null,
    reminderTime: null,
    version: 1,
    updatedAt: DateTime(2026, 1, 1),
    cloudId: null,
    ownerUserId: ownerUserId,
    syncStatus: ownerUserId == null ? 'localOnly' : 'synced',
    lastSyncedAt: null,
  );
}

RoutineRun _run({String? ownerUserId}) {
  return RoutineRun(
    id: 'run-1',
    routineId: '1',
    routineTitle: 'Close down',
    finishedAt: DateTime(2026, 1, 1, 20),
    stepCompletionData: jsonEncode({'steps': const []}),
    ownerUserId: ownerUserId,
    syncStatus: ownerUserId == null ? 'localOnly' : 'synced',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: DateTime(2026, 1, 1, 20),
  );
}

RoutineRemindersCompanion _reminder() {
  return RoutineRemindersCompanion.insert(
    routineId: 1,
    dayOfWeek: 1,
    time: '09:00',
  );
}

RoutineSessionRow _session({String? ownerUserId}) {
  return RoutineSessionRow(
    sessionId: 'session-1',
    routineId: 1,
    routineTitleSnapshot: 'Close down',
    workspaceId: null,
    ownerUserId: ownerUserId,
    storageScope: 'personal',
    startedAt: DateTime(2026, 1, 1, 19),
    updatedAt: DateTime(2026, 1, 1, 19),
    status: 'completed',
    currentStepIndex: 10,
    totalStepCount: 10,
    baseRoutineVersion: 1,
    stepStatesJson: jsonEncode(const []),
    routineSnapshotJson: jsonEncode(const []),
    syncMetadataJson: null,
    completedAt: DateTime(2026, 1, 1, 20),
    discardedAt: null,
  );
}
