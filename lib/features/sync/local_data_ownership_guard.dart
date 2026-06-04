import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pebble_routines/core/database/local_db.dart';

enum LocalDataOwnershipState {
  empty,
  unownedOnly,
  sameOwnerOnly,
  differentOwner,
  mixed,
}

class LocalDataOwnershipReport {
  const LocalDataOwnershipReport({
    required this.state,
    required this.unownedCount,
    required this.sameOwnerCount,
    required this.differentOwnerCount,
  });

  final LocalDataOwnershipState state;
  final int unownedCount;
  final int sameOwnerCount;
  final int differentOwnerCount;

  bool get blocksCloudSync =>
      state == LocalDataOwnershipState.unownedOnly ||
      state == LocalDataOwnershipState.differentOwner ||
      state == LocalDataOwnershipState.mixed;

  String get userFacingMessage {
    switch (state) {
      case LocalDataOwnershipState.empty:
      case LocalDataOwnershipState.sameOwnerOnly:
        return 'Local data is safe to sync for this account.';
      case LocalDataOwnershipState.unownedOnly:
        return 'Existing local data is not linked to this account yet. Pebble will keep it local until you choose what to do.';
      case LocalDataOwnershipState.differentOwner:
      case LocalDataOwnershipState.mixed:
        return 'This device has local data linked to another account. Pebble will not upload or merge it into the signed-in account without your choice.';
    }
  }
}

class LocalDataOwnershipGuard {
  static Future<LocalDataOwnershipReport> inspect({
    required LocalDb database,
    required String signedInUserId,
  }) async {
    final ownerIds = <String?>[];
    ownerIds.addAll(
      (await database.routineDao.getAllRoutines()).map(
        (routine) => routine.ownerUserId,
      ),
    );
    ownerIds.addAll(
      (await database.routineRunDao.getAllRuns()).map((run) => run.ownerUserId),
    );
    ownerIds.addAll(
      (await database.routineReminderDao.getAllReminders()).map(
        (reminder) => reminder.ownerUserId,
      ),
    );
    ownerIds.addAll(
      (await database.routineSessionDao.getAllSessions()).map(
        (session) => session.ownerUserId,
      ),
    );

    if (ownerIds.isEmpty) {
      return const LocalDataOwnershipReport(
        state: LocalDataOwnershipState.empty,
        unownedCount: 0,
        sameOwnerCount: 0,
        differentOwnerCount: 0,
      );
    }

    var unowned = 0;
    var same = 0;
    var different = 0;
    for (final ownerId in ownerIds) {
      final normalized = ownerId?.trim();
      if (normalized == null || normalized.isEmpty) {
        unowned += 1;
      } else if (normalized == signedInUserId) {
        same += 1;
      } else {
        different += 1;
      }
    }

    final state = different > 0
        ? (same > 0 || unowned > 0
              ? LocalDataOwnershipState.mixed
              : LocalDataOwnershipState.differentOwner)
        : unowned > 0
        ? (same > 0
              ? LocalDataOwnershipState.mixed
              : LocalDataOwnershipState.unownedOnly)
        : LocalDataOwnershipState.sameOwnerOnly;

    return LocalDataOwnershipReport(
      state: state,
      unownedCount: unowned,
      sameOwnerCount: same,
      differentOwnerCount: different,
    );
  }

  static Future<LocalDataOwnershipReport> linkUnownedLocalData({
    required LocalDb database,
    required String signedInUserId,
    DateTime? linkedAt,
  }) async {
    final normalizedUserId = signedInUserId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('Sign in before linking local data.');
    }

    final report = await inspect(
      database: database,
      signedInUserId: normalizedUserId,
    );
    if (report.state == LocalDataOwnershipState.empty ||
        report.state == LocalDataOwnershipState.sameOwnerOnly) {
      return report;
    }
    if (report.differentOwnerCount > 0) {
      throw StateError(
        'This device has local data linked to another account. Pebble will keep it local until an account-switch choice is available.',
      );
    }

    final now = linkedAt ?? DateTime.now();
    final sessionSyncMetadata = jsonEncode({
      'needsSync': true,
      'ownershipLinkedAt': now.toUtc().toIso8601String(),
    });

    await database.transaction(() async {
      await (database.update(database.routines)..where(
            (tbl) => tbl.ownerUserId.isNull() | tbl.ownerUserId.equals(''),
          ))
          .write(
            RoutinesCompanion(
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineRuns)..where(
            (tbl) => tbl.ownerUserId.isNull() | tbl.ownerUserId.equals(''),
          ))
          .write(
            RoutineRunsCompanion(
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineReminders)..where(
            (tbl) => tbl.ownerUserId.isNull() | tbl.ownerUserId.equals(''),
          ))
          .write(
            RoutineRemindersCompanion(
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineSessions)..where(
            (tbl) => tbl.ownerUserId.isNull() | tbl.ownerUserId.equals(''),
          ))
          .write(
            RoutineSessionsCompanion(
              ownerUserId: Value(normalizedUserId),
              updatedAt: Value(now),
              syncMetadataJson: Value(sessionSyncMetadata),
            ),
          );
    });

    return inspect(database: database, signedInUserId: normalizedUserId);
  }

  static Future<LocalDataOwnershipReport> useCurrentAccountForLocalData({
    required LocalDb database,
    required String signedInUserId,
    DateTime? linkedAt,
  }) async {
    final normalizedUserId = signedInUserId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('Sign in before linking local data.');
    }

    final now = linkedAt ?? DateTime.now();
    final sessionSyncMetadata = jsonEncode({
      'needsSync': true,
      'ownershipLinkedAt': now.toUtc().toIso8601String(),
      'ownershipChoice': 'useCurrentAccount',
    });

    await database.transaction(() async {
      await (database.update(database.routines)..where(
            (tbl) =>
                tbl.ownerUserId.isNull() |
                tbl.ownerUserId.equals('') |
                tbl.ownerUserId.isNotValue(normalizedUserId),
          ))
          .write(
            RoutinesCompanion(
              cloudId: const Value(null),
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineRuns)..where(
            (tbl) =>
                tbl.ownerUserId.isNull() |
                tbl.ownerUserId.equals('') |
                tbl.ownerUserId.isNotValue(normalizedUserId),
          ))
          .write(
            RoutineRunsCompanion(
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineReminders)..where(
            (tbl) =>
                tbl.ownerUserId.isNull() |
                tbl.ownerUserId.equals('') |
                tbl.ownerUserId.isNotValue(normalizedUserId),
          ))
          .write(
            RoutineRemindersCompanion(
              cloudId: const Value(null),
              ownerUserId: Value(normalizedUserId),
              syncStatus: const Value('pendingUpload'),
              updatedAt: Value(now),
            ),
          );

      await (database.update(database.routineSessions)..where(
            (tbl) =>
                tbl.ownerUserId.isNull() |
                tbl.ownerUserId.equals('') |
                tbl.ownerUserId.isNotValue(normalizedUserId),
          ))
          .write(
            RoutineSessionsCompanion(
              ownerUserId: Value(normalizedUserId),
              updatedAt: Value(now),
              syncMetadataJson: Value(sessionSyncMetadata),
            ),
          );
    });

    return inspect(database: database, signedInUserId: normalizedUserId);
  }
}
