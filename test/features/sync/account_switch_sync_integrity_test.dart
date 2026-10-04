// What happens to backup when a second account takes over a device
// ("Use this account"), and when the first account comes back.
//
// The fake cloud below models the two server rules that matter, as written in
// supabase/migrations/001 and 014: a row id is unique across ALL accounts, and
// an account can only write rows it owns. It is a model, not the live server.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/local_data_ownership_guard.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

const _userA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _userB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _runId = '11111111-1111-4111-8111-111111111111';
const _sessionId = '22222222-2222-4222-8222-222222222222';

class _FakeCloud {
  final runs = <String, Map<String, dynamic>>{};
  final sessions = <String, Map<String, dynamic>>{};
  final routines = <String, Map<String, dynamic>>{};

  /// Set to make every write fail as if the connection dropped.
  bool offline = false;

  void upsert(
    String table,
    Map<String, Map<String, dynamic>> rows,
    Map<String, dynamic> payload,
  ) {
    if (offline) throw const SocketException('offline');
    final existing = rows[payload['id']];
    if (existing != null &&
        existing['owner_user_id'] != payload['owner_user_id']) {
      throw PostgrestException(
        message:
            'new row violates row-level security policy '
            '(USING expression) for table "$table"',
        code: '42501',
      );
    }
    rows[payload['id'] as String] = Map<String, dynamic>.from(payload);
  }

  Iterable<Map<String, dynamic>> ownedBy(
    Map<String, Map<String, dynamic>> rows,
    String owner,
  ) => rows.values.where((row) => row['owner_user_id'] == owner);
}

class _CloudRuns extends RemoteRoutineRunDataSource {
  _CloudRuns(this.cloud) : super(null);
  final _FakeCloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async =>
      cloud.upsert('routine_runs', cloud.runs, payload);

  @override
  Future<List<RemoteRoutineRunRecord>> fetchAll(String ownerUserId) async =>
      cloud
          .ownedBy(cloud.runs, ownerUserId)
          .map(RemoteRoutineRunRecord.fromJson)
          .toList();
}

class _CloudSessions extends RemoteRoutineSessionDataSource {
  _CloudSessions(this.cloud) : super(null);
  final _FakeCloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async =>
      cloud.upsert('routine_sessions', cloud.sessions, payload);

  @override
  Future<List<RemoteRoutineSessionRecord>> fetchAll(String ownerUserId) async =>
      cloud
          .ownedBy(cloud.sessions, ownerUserId)
          .map(RemoteRoutineSessionRecord.fromJson)
          .toList();
}

class _CloudRoutines extends RemoteRoutineDataSource {
  _CloudRoutines(this.cloud) : super(null);
  final _FakeCloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async =>
      cloud.upsert('routines', cloud.routines, payload);

  @override
  Future<List<RemoteRoutineRecord>> fetchAll(String ownerUserId) async => cloud
      .ownedBy(cloud.routines, ownerUserId)
      .map(RemoteRoutineRecord.fromJson)
      .toList();
}

class _RecordingProofStorage implements RoutineSessionProofStorage {
  final uploadedKeys = <String>[];

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    final key = 'users/$ownerUserId/$entityType/$entityId/${asset.proofId}.jpg';
    uploadedKeys.add(key);
    return asset.copyWith(
      remoteObjectKey: key,
      uploadStatus: ProofUploadStatus.uploaded,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAccountController extends SubscriptionAccountController {
  _TestAccountController(super.db, String userId) : super(loadOnInit: false) {
    state = SubscriptionAccountState(
      entitlementTier: UserTier.personalPremium,
      pendingTier: null,
      bootstrapStatus: BootstrapStatus.ready,
      userId: userId,
      email: 'someone@example.com',
      authProvider: 'google',
      lastBootstrapAt: null,
      lastSyncAt: null,
      lastSyncError: null,
      entitlementStatus: EntitlementStatus.personalPremium,
      entitlementSource: EntitlementSource.serverVerified,
    );
  }
}

/// One device (one local database) with [userId] signed in, Premium verified
/// and backup consent given.
class _SignedIn {
  _SignedIn(this.database, this.cloud, this.userId) {
    outbox = SyncOutboxRepositoryImpl(database);
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(database),
        syncOutboxRepositoryProvider.overrideWithValue(outbox),
        remoteRoutineDataSourceProvider.overrideWithValue(
          _CloudRoutines(cloud),
        ),
        remoteRoutineReminderDataSourceProvider.overrideWithValue(
          RemoteRoutineReminderDataSource(null),
        ),
        remoteRoutineRunDataSourceProvider.overrideWithValue(_CloudRuns(cloud)),
        remoteRoutineSessionDataSourceProvider.overrideWithValue(
          _CloudSessions(cloud),
        ),
        routineSessionProofStorageProvider.overrideWithValue(proofs),
        authSessionProvider.overrideWithValue(
          AuthSessionSummary(
            isSignedIn: true,
            userId: userId,
            email: 'someone@example.com',
            provider: 'google',
          ),
        ),
        subscriptionAccountControllerProvider.overrideWith(
          (ref) => _TestAccountController(database, userId),
        ),
        cloudAccessPolicyProvider.overrideWithValue(
          CloudAccessPolicy(
            cachedOwnerUserId: userId,
            personalCloudEnabled: true,
            canQueuePersonalSync: false,
            workspaceCloudEnabled: false,
            isSignedIn: true,
            isAccountSwitchBlocked: false,
          ),
        ),
      ],
    );
  }

  final LocalDb database;
  final _FakeCloud cloud;
  final String userId;
  final proofs = _RecordingProofStorage();
  late final SyncOutboxRepositoryImpl outbox;
  late final ProviderContainer container;

  Future<ManualSyncResult> backUp() =>
      container.read(cloudSyncCoordinatorProvider).runManualSync();

  /// The "Use this account" choice, followed by the same restore-and-merge
  /// the backup screen runs straight after it.
  Future<void> useThisAccount() async {
    await LocalDataOwnershipGuard.useCurrentAccountForLocalData(
      database: database,
      signedInUserId: userId,
    );
    await restore();
  }

  Future<void> restore() =>
      container.read(cloudRestoreCoordinatorProvider).bootstrapAndMerge(userId);

  SubscriptionAccountState get account =>
      container.read(subscriptionAccountControllerProvider);
}

RoutineRun _run({required String owner, String? stepCompletionData}) {
  return RoutineRun(
    id: _runId,
    routineId: '1',
    routineTitle: 'Close down',
    finishedAt: DateTime(2026, 1, 1, 20),
    stepCompletionData: stepCompletionData ?? jsonEncode({'steps': const []}),
    ownerUserId: owner,
    syncStatus: 'pendingUpload',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: DateTime(2026, 1, 1, 20),
  );
}

RoutineSessionRow _session({required String owner}) {
  return RoutineSessionRow(
    sessionId: _sessionId,
    routineId: 1,
    routineTitleSnapshot: 'Close down',
    workspaceId: null,
    ownerUserId: owner,
    storageScope: 'personal',
    startedAt: DateTime(2026, 1, 1, 19),
    updatedAt: DateTime.now(),
    status: 'completed',
    currentStepIndex: 0,
    totalStepCount: 0,
    baseRoutineVersion: 1,
    stepStatesJson: jsonEncode(const []),
    routineSnapshotJson: jsonEncode(const []),
    syncMetadataJson: jsonEncode({'needsSync': true}),
    completedAt: DateTime(2026, 1, 1, 20),
    discardedAt: null,
  );
}

Routine _routine({required int id, required String title, String? owner}) {
  return Routine(
    id: id,
    title: title,
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
    ownerUserId: owner,
    syncStatus: 'pendingUpload',
    lastSyncedAt: null,
  );
}

void main() {
  late LocalDb database;
  late _FakeCloud cloud;
  final devices = <_SignedIn>[];

  _SignedIn signIn(String userId, {LocalDb? on}) {
    final device = _SignedIn(on ?? database, cloud, userId);
    devices.add(device);
    return device;
  }

  setUp(() {
    database = LocalDb.forTesting(NativeDatabase.memory());
    cloud = _FakeCloud();
  });

  tearDown(() async {
    for (final device in devices) {
      device.container.dispose();
    }
    devices.clear();
    await database.close();
  });

  /// Account A completes a routine on this device and backs it up.
  Future<void> accountABacksUpHistory() async {
    await database.routineRunDao.insertOrUpdateRun(_run(owner: _userA));
    await database.routineSessionDao.insertOrUpdateSession(
      _session(owner: _userA),
    );
    final result = await signIn(_userA).backUp();
    expect(result.type, ManualSyncResultType.synced);
    expect(cloud.runs[_runId]!['owner_user_id'], _userA);
    expect(cloud.sessions[_sessionId]!['owner_user_id'], _userA);
  }

  group('a second account takes over the device', () {
    test('history backs up under ids the first account has not used', () async {
      await accountABacksUpHistory();

      final b = signIn(_userB);
      await b.useThisAccount();
      final result = await b.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(b.account.lastSyncError, isNull);
      expect(await b.outbox.pendingItems(), isEmpty);

      // Account A's backup is untouched; account B has its own copy.
      expect(cloud.ownedBy(cloud.runs, _userA).single['id'], _runId);
      final bRun = cloud.ownedBy(cloud.runs, _userB).single;
      expect(bRun['id'], isNot(_runId));
      expect(bRun['routine_title'], 'Close down');
      expect(cloud.ownedBy(cloud.sessions, _userA).single['id'], _sessionId);
      final bSession = cloud.ownedBy(cloud.sessions, _userB).single;
      expect(bSession['id'], isNot(_sessionId));

      // Nothing is lost or doubled on the device.
      final localRun = (await database.routineRunDao.getAllRuns()).single;
      expect(localRun.id, bRun['id']);
      expect(localRun.ownerUserId, _userB);
      expect(localRun.syncStatus, 'synced');
      final localSession =
          (await database.routineSessionDao.getAllSessions()).single;
      expect(localSession.sessionId, _sessionId);
    });

    test('a later change to the same session reuses its cloud id', () async {
      await accountABacksUpHistory();
      final b = signIn(_userB);
      await b.useThisAccount();
      await b.backUp();

      final row = (await database.routineSessionDao.getAllSessions()).single;
      final metadata = Map<String, dynamic>.from(
        jsonDecode(row.syncMetadataJson!) as Map,
      )..['needsSync'] = true;
      await database.routineSessionDao.insertOrUpdateSession(
        row.copyWith(syncMetadataJson: drift.Value(jsonEncode(metadata))),
      );
      final result = await b.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(cloud.ownedBy(cloud.sessions, _userB), hasLength(1));
    });

    test('restoring afterwards does not double history', () async {
      await accountABacksUpHistory();
      final b = signIn(_userB);
      await b.useThisAccount();
      await b.backUp();

      await b.restore();

      expect(await database.routineRunDao.getAllRuns(), hasLength(1));
      expect(await database.routineSessionDao.getAllSessions(), hasLength(1));
    });

    test('photos are uploaded again into the new account', () async {
      const aKey = 'users/$_userA/runs/$_runId/photo-1.jpg';
      await database.routineRunDao.insertOrUpdateRun(
        _run(
          owner: _userA,
          stepCompletionData: jsonEncode({
            'steps': [
              {
                'proofAssets': [
                  {
                    'proofId': 'photo-1',
                    'localRelativePath': 'session/photo-1.jpg',
                    'remoteObjectKey': aKey,
                    'uploadStatus': 'uploaded',
                    'capturedAt': DateTime(2026, 1, 1, 20).toIso8601String(),
                  },
                ],
              },
            ],
          }),
        ),
      );
      final a = signIn(_userA);
      await a.backUp();
      expect(a.proofs.uploadedKeys, isEmpty, reason: 'already backed up by A');

      final b = signIn(_userB);
      await b.useThisAccount();
      await b.backUp();

      final bRun = cloud.ownedBy(cloud.runs, _userB).single;
      expect(b.proofs.uploadedKeys.single, startsWith('users/$_userB/runs/'));
      expect(bRun['step_completion_data'], contains('users/$_userB/'));
      expect(bRun['step_completion_data'], isNot(contains(aKey)));
    });

    test('the first account coming back reuses its original backup', () async {
      await accountABacksUpHistory();
      final b = signIn(_userB);
      await b.useThisAccount();
      await b.backUp();

      final a = signIn(_userA);
      await a.useThisAccount();
      final result = await a.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(cloud.ownedBy(cloud.runs, _userA).single['id'], _runId);
      expect(cloud.ownedBy(cloud.runs, _userB), hasLength(1));
      final localRun = (await database.routineRunDao.getAllRuns()).single;
      expect(localRun.id, _runId);
      expect(localRun.syncMetadataJson, isNull);
      expect(await database.routineSessionDao.getAllSessions(), hasLength(1));
    });
  });

  group('when the server does reject a write', () {
    // The state every taken-over run was in before the ids were scoped to the
    // new owner. Still reachable if a row slips through, so pin how it ends.
    test('it is reported, retried, and nothing local is lost', () async {
      await accountABacksUpHistory();
      await database.routineRunDao.insertOrUpdateRun(_run(owner: _userB));
      await database.delete(database.routineSessions).go();
      final b = signIn(_userB);

      final result = await b.backUp();

      expect(result.type, ManualSyncResultType.failed);
      expect(b.account.bootstrapStatus, BootstrapStatus.error);
      expect(b.account.lastSyncError, result.message);
      expect(cloud.runs[_runId]!['owner_user_id'], _userA);

      final local = (await database.routineRunDao.getAllRuns()).single;
      expect(local.id, _runId);
      expect(local.syncStatus, 'pendingUpload');

      final pending = (await b.outbox.pendingItems()).single;
      expect(pending.entityType, SyncEntityType.run);
      expect(pending.attemptCount, 1);
      expect(pending.nextAttemptAt, isNotNull);
      expect(pending.lastErrorSummary, contains('row-level security'));
    });
  });

  group('what a taken-over run leaves behind', () {
    test('it still shows in history with its routine and title', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Close down', owner: _userA),
      );
      await accountABacksUpHistory();

      await signIn(_userB).useThisAccount();

      // What the History screen reads.
      final run = (await database.routineRunDao.watchAllRuns().first).single;
      expect(run.routineTitle, 'Close down');
      expect(run.routineId, '1');
      expect(run.finishedAt, DateTime(2026, 1, 1, 20));
      final latest = await database.routineRunDao
          .watchLatestRunForRoutine(1)
          .first;
      expect(latest?.id, run.id);
    });

    test('a queued upload under the old id is dropped, then the run '
        'uploads under its new id', () async {
      await accountABacksUpHistory();
      final b = signIn(_userB);
      await b.outbox.enqueue(
        entityType: SyncEntityType.run,
        entityId: _runId,
        operation: SyncOperation.upsert,
      );
      await LocalDataOwnershipGuard.useCurrentAccountForLocalData(
        database: database,
        signedInUserId: _userB,
      );

      // First pass clears the stale item; it points at no run any more.
      final first = await b.backUp();
      expect(first.type, ManualSyncResultType.synced);
      expect(await b.outbox.pendingItems(), isEmpty);
      expect(cloud.ownedBy(cloud.runs, _userB), isEmpty);

      // The run is still marked as waiting, so the next pass picks it up.
      await b.backUp();
      expect(cloud.ownedBy(cloud.runs, _userB), hasLength(1));
      expect(cloud.runs[_runId]!['owner_user_id'], _userA);
    });

    test('the session keeps pointing at the run it completed', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(owner: _userA));
      await database.routineSessionDao.insertOrUpdateSession(
        _session(owner: _userA).copyWith(
          syncMetadataJson: drift.Value(
            jsonEncode({'needsSync': false, 'completedRunId': _runId}),
          ),
        ),
      );

      await LocalDataOwnershipGuard.useCurrentAccountForLocalData(
        database: database,
        signedInUserId: _userB,
      );

      final run = (await database.routineRunDao.getAllRuns()).single;
      final session =
          (await database.routineSessionDao.getAllSessions()).single;
      final metadata = RoutineSessionSyncMetadata.fromJson(
        Map<String, dynamic>.from(jsonDecode(session.syncMetadataJson!) as Map),
      );
      expect(run.id, isNot(_runId));
      expect(metadata.completedRunId, run.id);
    });
  });

  group('routine cloud ids', () {
    test('two devices keep their own routines in the backup', () async {
      final otherDevice = LocalDb.forTesting(NativeDatabase.memory());
      addTearDown(otherDevice.close);
      // Both are "routine 1" on their own device.
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Morning', owner: _userA),
      );
      await otherDevice.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Lock up', owner: _userA),
      );

      await signIn(_userA).backUp();
      await signIn(_userA, on: otherDevice).backUp();

      expect(cloud.routines.values.map((row) => row['title']).toSet(), {
        'Morning',
        'Lock up',
      });
    });

    test('a failed upload and its retry use the same id', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Morning', owner: _userA),
      );
      final a = signIn(_userA);

      cloud.offline = true;
      final failed = await a.backUp();
      expect(failed.type, ManualSyncResultType.blockedOffline);
      final afterFailure = await database.routineDao.getRoutineById(1);
      expect(afterFailure!.cloudId, isNotNull);
      expect(afterFailure.syncStatus, 'pendingUpload');
      expect(cloud.routines, isEmpty);

      cloud.offline = false;
      final retried = await a.backUp();
      expect(retried.type, ManualSyncResultType.synced);
      await a.backUp();

      expect(cloud.routines.keys.single, afterFailure.cloudId);
      final synced = await database.routineDao.getRoutineById(1);
      expect(synced!.cloudId, afterFailure.cloudId);
      expect(synced.syncStatus, 'synced');
    });

    test('a routine that already has a cloud id keeps it', () async {
      const existing = '33333333-3333-4333-8333-333333333333';
      await database.routineDao.insertOrUpdateRoutine(
        _routine(
          id: 1,
          title: 'Morning',
          owner: _userA,
        ).copyWith(cloudId: const drift.Value(existing)),
      );

      await signIn(_userA).backUp();

      expect(cloud.routines.keys.single, existing);
    });

    test('a run points at the id its routine is backed up under', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Close down', owner: _userA),
      );
      await database.routineRunDao.insertOrUpdateRun(_run(owner: _userA));
      final a = signIn(_userA);

      await a.backUp();
      await a.backUp();

      expect(cloud.runs[_runId]!['routine_id'], cloud.routines.keys.single);
    });
  });

  group('KNOWN ISSUE, not fixed here (see docs/review/AUTH_SYNC_AUDIT.md)', () {
    // This pins today's behaviour so a future fix has to change it.

    test('routines double up when an account takes a device back', () async {
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 1, title: 'Close down', owner: _userA),
      );
      final a = signIn(_userA);
      await a.backUp();
      final b = signIn(_userB);
      await b.useThisAccount();
      await b.backUp();

      final aAgain = signIn(_userA);
      await aAgain.useThisAccount();
      await aAgain.backUp();

      final titles = (await database.routineDao.getAllRoutines()).map(
        (routine) => routine.title,
      );
      expect(titles, ['Close down', 'Close down']);
      // Each copy on the device has its own copy in the backup.
      expect(cloud.ownedBy(cloud.routines, _userA), hasLength(2));
    });
  });
}
