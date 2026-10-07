// How a backup pass behaves: when it may say "backed up", what it picks up
// that was saved while queueing was closed, and how it treats work that
// arrives while it is running. The cloud below is a small in-memory model,
// not the live server.
import 'dart:async';
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
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

const _user = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class _Cloud {
  final routines = <String, Map<String, dynamic>>{};
  final reminders = <String, Map<String, dynamic>>{};
  final runs = <String, Map<String, dynamic>>{};
  final sessions = <String, Map<String, dynamic>>{};
  final runUpserts = <Map<String, dynamic>>[];
  final sessionUpserts = <Map<String, dynamic>>[];
  var routineUpsertCalls = 0;

  /// When set, the next session upload waits for it.
  Completer<void>? holdNextSessionUpload;
  final sessionUploadStarted = <Completer<void>>[];

  /// Run uploads never finish while this is true (a stalled connection).
  bool runUploadsHang = false;

  bool offline = false;
  bool routinesOffline = false;

  /// When set, the next run upload waits for it (an upload in flight).
  Completer<void>? holdNextRunUpload;
  final runUploadStarted = <Completer<void>>[];

  void _check() {
    if (offline) throw const SocketException('offline');
  }
}

class _Routines extends RemoteRoutineDataSource {
  _Routines(this.cloud) : super(null);
  final _Cloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    cloud.routineUpsertCalls += 1;
    cloud._check();
    if (cloud.routinesOffline) throw const SocketException('offline');
    cloud.routines[payload['id'] as String] = Map.of(payload);
  }

  @override
  Future<List<RemoteRoutineRecord>> fetchAll(String ownerUserId) async =>
      cloud.routines.values.map(RemoteRoutineRecord.fromJson).toList();
}

class _Sessions extends RemoteRoutineSessionDataSource {
  _Sessions(this.cloud) : super(null);
  final _Cloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    cloud._check();
    for (final started in cloud.sessionUploadStarted) {
      if (!started.isCompleted) started.complete();
    }
    final hold = cloud.holdNextSessionUpload;
    if (hold != null) {
      cloud.holdNextSessionUpload = null;
      await hold.future;
    }
    cloud.sessionUpserts.add(Map.of(payload));
    cloud.sessions[payload['id'] as String] = Map.of(payload);
  }

  @override
  Future<List<RemoteRoutineSessionRecord>> fetchAll(String ownerUserId) async =>
      [];
}

class _Reminders extends RemoteRoutineReminderDataSource {
  _Reminders(this.cloud) : super(null);
  final _Cloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    cloud._check();
    // routine_reminders.routine_id references routines(id).
    if (!cloud.routines.containsKey(payload['routine_id'])) {
      throw const PostgrestException(
        message:
            'insert or update on table "routine_reminders" violates foreign '
            'key constraint "routine_reminders_routine_id_fkey"',
        code: '23503',
      );
    }
    cloud.reminders[payload['id'] as String] = Map.of(payload);
  }
}

class _Runs extends RemoteRoutineRunDataSource {
  _Runs(this.cloud) : super(null);
  final _Cloud cloud;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    cloud._check();
    if (cloud.runUploadsHang) await Completer<void>().future;
    for (final started in cloud.runUploadStarted) {
      if (!started.isCompleted) started.complete();
    }
    final hold = cloud.holdNextRunUpload;
    if (hold != null) {
      cloud.holdNextRunUpload = null;
      await hold.future;
    }
    cloud.runUpserts.add(Map.of(payload));
    cloud.runs[payload['id'] as String] = Map.of(payload);
  }

  @override
  Future<List<RemoteRoutineRunRecord>> fetchAll(String ownerUserId) async => [];
}

class _Proofs implements RoutineSessionProofStorage {
  /// Photos come back "pending" (held back) while this is true.
  bool holdBack = false;

  /// When set, the next photo upload waits for it (a slow upload).
  Completer<void>? holdNextUpload;
  final uploadStarted = <Completer<void>>[];

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    for (final started in uploadStarted) {
      if (!started.isCompleted) started.complete();
    }
    final hold = holdNextUpload;
    if (hold != null) {
      holdNextUpload = null;
      await hold.future;
    }
    if (holdBack) {
      return asset.copyWith(uploadStatus: ProofUploadStatus.pendingUpload);
    }
    return asset.copyWith(
      remoteObjectKey: 'users/$ownerUserId/$entityType/$entityId/p.jpg',
      uploadStatus: ProofUploadStatus.uploaded,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account extends SubscriptionAccountController {
  _Account(super.db) : super(loadOnInit: false) {
    state = const SubscriptionAccountState(
      entitlementTier: UserTier.personalPremium,
      pendingTier: null,
      bootstrapStatus: BootstrapStatus.ready,
      userId: _user,
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

class _Device {
  _Device(this.database, this.cloud) {
    outbox = SyncOutboxRepositoryImpl(database);
    container = ProviderContainer(
      overrides: [
        localDbProvider.overrideWithValue(database),
        syncOutboxRepositoryProvider.overrideWithValue(outbox),
        remoteRoutineDataSourceProvider.overrideWithValue(_Routines(cloud)),
        remoteRoutineReminderDataSourceProvider.overrideWithValue(
          _Reminders(cloud),
        ),
        remoteRoutineRunDataSourceProvider.overrideWithValue(_Runs(cloud)),
        remoteRoutineSessionDataSourceProvider.overrideWithValue(
          _Sessions(cloud),
        ),
        routineSessionProofStorageProvider.overrideWithValue(proofs),
        authSessionProvider.overrideWithValue(
          const AuthSessionSummary(
            isSignedIn: true,
            userId: _user,
            email: 'someone@example.com',
            provider: 'google',
          ),
        ),
        subscriptionAccountControllerProvider.overrideWith(
          (ref) => _Account(database),
        ),
        cloudAccessPolicyProvider.overrideWithValue(
          const CloudAccessPolicy(
            cachedOwnerUserId: _user,
            personalCloudEnabled: true,
            canQueuePersonalSync: true,
            workspaceCloudEnabled: false,
            isSignedIn: true,
            isAccountSwitchBlocked: false,
          ),
        ),
      ],
    );
  }

  final LocalDb database;
  final _Cloud cloud;
  final proofs = _Proofs();
  late final SyncOutboxRepositoryImpl outbox;
  late final ProviderContainer container;

  CloudSyncCoordinator get coordinator =>
      container.read(cloudSyncCoordinatorProvider);

  Future<ManualSyncResult> backUp() => coordinator.runManualSync();

  SubscriptionAccountState get account =>
      container.read(subscriptionAccountControllerProvider);

  Future<void> queueRun(String id) => outbox.enqueue(
    entityType: SyncEntityType.run,
    entityId: id,
    operation: SyncOperation.upsert,
  );
}

RoutineRun _run(
  String id, {
  String syncStatus = 'pendingUpload',
  String title = 'Close down',
  String? stepCompletionData,
}) {
  return RoutineRun(
    id: id,
    routineId: '1',
    routineTitle: title,
    finishedAt: DateTime(2026, 10, 6, 20),
    stepCompletionData: stepCompletionData ?? jsonEncode({'steps': const []}),
    ownerUserId: _user,
    syncStatus: syncStatus,
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: DateTime(2026, 10, 6, 20),
  );
}

const _run1 = '11111111-1111-4111-8111-111111111111';
const _run2 = '22222222-2222-4222-8222-222222222222';

void main() {
  late LocalDb database;
  late _Cloud cloud;
  late _Device device;

  setUp(() {
    database = LocalDb.forTesting(NativeDatabase.memory());
    cloud = _Cloud();
    device = _Device(database, cloud);
  });

  tearDown(() async {
    device.container.dispose();
    await database.close();
  });

  group('"Last backed up"', () {
    test('is not set by a pass that leaves a change failing', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      cloud.offline = true;

      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.blockedOffline);
      expect(device.account.lastSyncAt, isNull);
      expect(device.account.lastSyncError, contains('offline'));
      expect(await device.outbox.pendingItems(), hasLength(1));
    });

    test('is set once the pass ends clean and clears the old error', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      cloud.offline = true;
      await device.backUp();

      cloud.offline = false;
      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(device.account.lastSyncAt, isNotNull);
      expect(device.account.lastSyncError, isNull);
      expect(await device.outbox.pendingItems(), isEmpty);
    });

    test('is not set when some changes succeed and one fails', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      // A reminder whose routine cannot go up stays behind.
      final routineId = await database.routineDao.insertRoutineCompanion(
        RoutinesCompanion.insert(
          title: 'Morning',
          stepsJson: jsonEncode(const []),
          createdAt: DateTime(2026, 10, 1),
          ownerUserId: const drift.Value(_user),
        ),
      );
      cloud.routinesOffline = true;
      await database.routineReminderDao.addReminder(
        RoutineRemindersCompanion.insert(
          routineId: routineId,
          dayOfWeek: 1,
          time: '7:00 AM',
          ownerUserId: const drift.Value(_user),
        ),
      );

      final result = await device.backUp();

      expect(cloud.runs, contains(_run1));
      expect(result.type, ManualSyncResultType.partialRetryScheduled);
      expect(device.account.lastSyncAt, isNull);
    });
  });

  group('changes saved while queueing was closed', () {
    test('a run that was never queued is found and backed up', () async {
      // Written at a cold start before consent was re-confirmed: owned, but
      // no outbox row.
      await database.routineRunDao.insertOrUpdateRun(
        _run(_run1, syncStatus: 'localOnly'),
      );
      expect(await device.outbox.pendingItems(), isEmpty);

      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(cloud.runs, contains(_run1));
      final local = await database.routineRunDao.getRunById(_run1);
      expect(local!.syncStatus, 'synced');
      expect(await device.outbox.pendingItems(), isEmpty);
    });

    test('marking synced keeps the time the run last changed', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.backUp();
      final local = await database.routineRunDao.getRunById(_run1);
      expect(local!.updatedAt, DateTime(2026, 10, 6, 20));
      expect(local.lastSyncedAt!.isAfter(local.updatedAt), isTrue);
    });
  });

  group('work arriving during a pass', () {
    test('a change queued mid-pass goes up in the same pass', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      final hold = Completer<void>();
      final started = Completer<void>();
      cloud.holdNextRunUpload = hold;
      cloud.runUploadStarted.add(started);

      final pass = device.backUp();
      await started.future;
      await database.routineRunDao.insertOrUpdateRun(_run(_run2));
      await device.queueRun(_run2);
      hold.complete();
      await pass;

      expect(cloud.runs.keys, containsAll([_run1, _run2]));
      expect(await device.outbox.pendingItems(), isEmpty);
      expect(device.account.lastSyncAt, isNotNull);
    });

    test('"Back up now" during a pass waits, then runs its own', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      final hold = Completer<void>();
      final started = Completer<void>();
      cloud.holdNextRunUpload = hold;
      cloud.runUploadStarted.add(started);

      final first = device.backUp();
      await started.future;
      final second = device.backUp();
      hold.complete();

      expect((await first).type, ManualSyncResultType.synced);
      final secondResult = await second;
      expect(secondResult.type, ManualSyncResultType.noChanges);
      expect(secondResult.message, isNot(contains('already')));
    });

    test('an edit saved during its own upload is not lost', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      final hold = Completer<void>();
      final started = Completer<void>();
      cloud.holdNextRunUpload = hold;
      cloud.runUploadStarted.add(started);

      final pass = device.backUp();
      await started.future;
      // The person renames the run while the older copy is uploading.
      await database.routineRunDao.insertOrUpdateRun(
        _run(_run1, title: 'Close down (edited)'),
      );
      await device.queueRun(_run1);
      hold.complete();
      await pass;

      expect(cloud.runUpserts, hasLength(2));
      expect(cloud.runs[_run1]!['routine_title'], 'Close down (edited)');
      expect(await device.outbox.pendingItems(), isEmpty);
    });
  });

  group('a reminder and its routine', () {
    Future<int> addRoutineWithReminder() async {
      final routineId = await database.routineDao.insertRoutineCompanion(
        RoutinesCompanion.insert(
          title: 'Morning',
          stepsJson: jsonEncode(const []),
          createdAt: DateTime(2026, 10, 1),
          syncStatus: const drift.Value('pendingUpload'),
        ),
      );
      final reminderId = await database.routineReminderDao.addReminder(
        RoutineRemindersCompanion.insert(
          routineId: routineId,
          dayOfWeek: 1,
          time: '7:00 AM',
        ),
      );
      // Only the reminder is queued: the routine was saved before queueing
      // opened.
      await device.outbox.enqueue(
        entityType: SyncEntityType.reminder,
        entityId: reminderId.toString(),
        operation: SyncOperation.upsert,
      );
      return routineId;
    }

    test('the routine goes up first, then the reminder', () async {
      final routineId = await addRoutineWithReminder();

      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.synced);
      final routine = await database.routineDao.getRoutineById(routineId);
      expect(cloud.routines, contains(routine!.cloudId));
      expect(cloud.reminders.values.single['routine_id'], routine.cloudId);
      expect(await device.outbox.pendingItems(), isEmpty);
    });

    test(
      'a reminder waits without failing while its routine cannot go up',
      () async {
        await addRoutineWithReminder();
        cloud.routinesOffline = true;

        await device.backUp();

        final items = await device.outbox.pendingItems();
        final reminder = items.singleWhere(
          (item) => item.entityType == SyncEntityType.reminder,
        );
        expect(reminder.attemptCount, 0);
        expect(cloud.reminders, isEmpty);
        expect(
          items.any((item) => item.entityType == SyncEntityType.routine),
          isTrue,
        );

        cloud.routinesOffline = false;
        final result = await device.backUp();
        expect(result.type, ManualSyncResultType.synced);
        expect(cloud.reminders, hasLength(1));
      },
    );
  });

  group('failures', () {
    test('count up across passes instead of resetting', () async {
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      await device.queueRun(_run1);
      cloud.offline = true;

      for (var i = 0; i < 3; i++) {
        await device.backUp();
      }

      final item = (await device.outbox.pendingItems()).single;
      expect(item.attemptCount, 3);
      expect(item.lastErrorSummary, contains('SocketException'));
    });
  });

  test('pruning old sessions never removes one still in progress', () async {
    RoutineSessionRow session(String id, String status) => RoutineSessionRow(
      sessionId: id,
      routineId: 1,
      routineTitleSnapshot: 'Morning',
      workspaceId: null,
      ownerUserId: _user,
      storageScope: 'personalCloud',
      startedAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      status: status,
      currentStepIndex: 0,
      totalStepCount: 1,
      baseRoutineVersion: 1,
      stepStatesJson: jsonEncode(const []),
      routineSnapshotJson: jsonEncode(const []),
      syncMetadataJson: null,
      completedAt: null,
      discardedAt: null,
    );
    await database.routineSessionDao.insertOrUpdateSession(
      session('active-1', 'active'),
    );
    await database.routineSessionDao.insertOrUpdateSession(
      session('done-1', 'completed'),
    );

    await database.routineSessionDao.deleteSessionsOlderThan(
      DateTime(2026, 10, 1),
    );

    final left = await database.routineSessionDao.getAllSessions();
    expect(left.map((row) => row.sessionId), ['active-1']);
  });

  group('proof photos held back during a run upload', () {
    test('are retried by themselves on a later pass', () async {
      final asset = RoutineSessionProofAsset(
        proofId: 'p1',
        localRelativePath: 'routine_session_proofs/s/p1.webp',
        remoteObjectKey: null,
        capturedAt: DateTime(2026, 10, 6, 19),
        uploadStatus: ProofUploadStatus.localOnly,
      );
      await database.routineRunDao.insertOrUpdateRun(
        _run(
          _run1,
          stepCompletionData: jsonEncode({
            'steps': [
              {
                'stepIndex': 0,
                'proofAssets': [asset.toJson()],
              },
            ],
          }),
        ),
      );
      device.proofs.holdBack = true;

      await device.backUp();

      expect(cloud.runs, contains(_run1));
      final waiting = (await device.outbox.pendingItems()).single;
      expect(waiting.entityType, SyncEntityType.proofAsset);
      expect(device.account.lastSyncAt, isNull);

      device.proofs.holdBack = false;
      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.synced);
      expect(await device.outbox.pendingItems(), isEmpty);
      expect(
        cloud.runs[_run1]!['step_completion_data'],
        contains('users/$_user/runs/$_run1/p.jpg'),
      );
    });
  });

  group('changes made while the backup uploads are never overwritten', () {
    Map<String, dynamic> photo({String? caption, String? key}) => {
      'proofId': 'p1',
      'localRelativePath': 'routine_session_proofs/s1/p1.webp',
      'remoteObjectKey': key,
      'uploadStatus': key == null ? 'localOnly' : 'uploaded',
      'capturedAt': DateTime(2026, 10, 6, 19).toIso8601String(),
      if (caption != null) 'aiDescription': caption,
    };

    RoutineSessionRow sessionRow({
      required String status,
      required String stepStatus,
      required DateTime updatedAt,
      String? caption,
    }) => RoutineSessionRow(
      sessionId: 's1',
      routineId: 1,
      routineTitleSnapshot: 'Morning',
      workspaceId: null,
      ownerUserId: _user,
      storageScope: 'personalCloud',
      startedAt: DateTime(2026, 10, 6, 18),
      updatedAt: updatedAt,
      status: status,
      currentStepIndex: 0,
      totalStepCount: 1,
      baseRoutineVersion: 1,
      stepStatesJson: jsonEncode([
        {
          'stepIndex': 0,
          'status': stepStatus,
          'completedAt': null,
          'proofAssets': [photo(caption: caption)],
        },
      ]),
      routineSnapshotJson: jsonEncode(const []),
      syncMetadataJson: jsonEncode({'needsSync': true}),
      completedAt: status == 'completed' ? DateTime(2026, 10, 6, 19) : null,
      discardedAt: null,
    );

    test('a session finished during its upload stays finished', () async {
      await database.routineSessionDao.insertOrUpdateSession(
        sessionRow(
          status: 'active',
          stepStatus: 'pending',
          updatedAt: DateTime(2026, 10, 6, 18, 30),
        ),
      );
      await device.outbox.enqueue(
        entityType: SyncEntityType.session,
        entityId: 's1',
        operation: SyncOperation.upsert,
      );
      final hold = Completer<void>();
      final started = Completer<void>();
      device.proofs.holdNextUpload = hold;
      device.proofs.uploadStarted.add(started);

      final pass = device.backUp();
      await started.future;
      // The person checks the step and finishes, and a caption arrives,
      // while the photo is still uploading.
      await database.routineSessionDao.insertOrUpdateSession(
        sessionRow(
          status: 'completed',
          stepStatus: 'completed',
          updatedAt: DateTime(2026, 10, 6, 19),
          caption: 'A tidy desk',
        ),
      );
      await device.outbox.enqueue(
        entityType: SyncEntityType.session,
        entityId: 's1',
        operation: SyncOperation.upsert,
      );
      hold.complete();
      await pass;

      final local = await database.routineSessionDao.getSessionById('s1');
      expect(local!.status, 'completed');
      expect(local.completedAt, isNotNull);
      final step = (jsonDecode(local.stepStatesJson) as List).single as Map;
      expect(step['status'], 'completed');
      final asset = (step['proofAssets'] as List).single as Map;
      expect(asset['aiDescription'], 'A tidy desk');
      expect(asset['remoteObjectKey'], 'users/$_user/sessions/s1/p.jpg');
      // The finished copy went up last, and nothing is left waiting.
      final lastPayload = cloud.sessionUpserts.last['payload_json'] as Map;
      expect(lastPayload['status'], 'completed');
      expect(await device.outbox.pendingItems(), isEmpty);
    });

    test('a caption written during a run photo upload is kept', () async {
      String runData({String? caption, String? key}) => jsonEncode({
        'steps': [
          {
            'stepIndex': 0,
            'proofAssets': [photo(caption: caption, key: key)],
          },
        ],
      });
      await database.routineRunDao.insertOrUpdateRun(
        _run(_run1, stepCompletionData: runData()),
      );
      final hold = Completer<void>();
      final started = Completer<void>();
      device.proofs.holdNextUpload = hold;
      device.proofs.uploadStarted.add(started);

      final pass = device.backUp();
      await started.future;
      // saveProofDescription writes the caption into the run meanwhile.
      await database.routineRunDao.insertOrUpdateRun(
        _run(_run1, stepCompletionData: runData(caption: 'A tidy desk')),
      );
      await device.queueRun(_run1);
      hold.complete();
      await pass;

      final local = await database.routineRunDao.getRunById(_run1);
      final data = jsonDecode(local!.stepCompletionData!) as Map;
      final step = (data['steps'] as List).single as Map;
      final asset = (step['proofAssets'] as List).single as Map;
      expect(asset['aiDescription'], 'A tidy desk');
      expect(asset['remoteObjectKey'], 'users/$_user/runs/$_run1/p.jpg');
      final uploaded = cloud.runs[_run1]!['step_completion_data'] as String;
      expect(uploaded, contains('A tidy desk'));
      expect(uploaded, contains('users/$_user/runs/$_run1/p.jpg'));
    });
  });

  group('reminders waiting on a routine', () {
    test(
      'a failing routine is tried once per pass, not once per reminder',
      () async {
        final routineId = await database.routineDao.insertRoutineCompanion(
          RoutinesCompanion.insert(
            title: 'Morning',
            stepsJson: jsonEncode(const []),
            createdAt: DateTime(2026, 10, 1),
            ownerUserId: const drift.Value(_user),
            syncStatus: const drift.Value('pendingUpload'),
          ),
        );
        for (var day = 1; day <= 3; day++) {
          await database.routineReminderDao.addReminder(
            RoutineRemindersCompanion.insert(
              routineId: routineId,
              dayOfWeek: day,
              time: '7:00 AM',
              ownerUserId: const drift.Value(_user),
            ),
          );
        }
        cloud.routinesOffline = true;

        await device.backUp();

        expect(cloud.routineUpsertCalls, 1);
        final items = await device.outbox.pendingItems();
        final routineRow = items.singleWhere(
          (item) => item.entityType == SyncEntityType.routine,
        );
        expect(routineRow.attemptCount, 1);
        for (final reminder in items.where(
          (item) => item.entityType == SyncEntityType.reminder,
        )) {
          expect(reminder.attemptCount, 0);
          // Waits for the routine's own retry rather than a fixed short delay.
          expect(
            reminder.nextAttemptAt!.isBefore(
              routineRow.nextAttemptAt!.subtract(const Duration(seconds: 1)),
            ),
            isFalse,
          );
        }
      },
    );

    test('a routine already on the server lets its reminder go up even while a '
        'newer edit to it is waiting', () async {
      const routineCloudId = '33333333-3333-4333-8333-333333333333';
      final routineId = await database.routineDao.insertRoutineCompanion(
        RoutinesCompanion.insert(
          title: 'Morning (edited)',
          stepsJson: jsonEncode(const []),
          createdAt: DateTime(2026, 10, 1),
          cloudId: const drift.Value(routineCloudId),
          ownerUserId: const drift.Value(_user),
          syncStatus: const drift.Value('pendingUpload'),
          lastSyncedAt: drift.Value(DateTime(2026, 10, 2)),
        ),
      );
      cloud.routines[routineCloudId] = {'id': routineCloudId};
      await database.routineReminderDao.addReminder(
        RoutineRemindersCompanion.insert(
          routineId: routineId,
          dayOfWeek: 1,
          time: '7:00 AM',
          ownerUserId: const drift.Value(_user),
        ),
      );
      cloud.routinesOffline = true;

      await device.backUp();

      expect(cloud.reminders.values.single['routine_id'], routineCloudId);
      // Only the routine's own item tried the routine.
      expect(cloud.routineUpsertCalls, 1);
    });
  });

  group('a stalled connection', () {
    tearDown(() {
      CloudSyncCoordinator.rowWriteTimeout = const Duration(seconds: 30);
      CloudSyncCoordinator.manualWaitLimit = const Duration(minutes: 2);
    });

    test('times out into a retry and never leaves "backing up" on', () async {
      CloudSyncCoordinator.rowWriteTimeout = const Duration(milliseconds: 50);
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      cloud.runUploadsHang = true;

      final result = await device.backUp();

      expect(result.type, ManualSyncResultType.blockedOffline);
      expect(
        device.container.read(cloudSyncRuntimeStateProvider).isRunning,
        isFalse,
      );
      final item = (await device.outbox.pendingItems()).single;
      expect(item.attemptCount, 1);
      expect(item.lastErrorSummary, contains('TimeoutException'));
    });

    test('"Back up now" stops waiting for a pass that will not end', () async {
      CloudSyncCoordinator.manualWaitLimit = const Duration(milliseconds: 50);
      await database.routineRunDao.insertOrUpdateRun(_run(_run1));
      final hold = Completer<void>();
      final started = Completer<void>();
      cloud.holdNextRunUpload = hold;
      cloud.runUploadStarted.add(started);

      final first = device.backUp();
      await started.future;
      final second = await device.backUp();

      expect(second.type, ManualSyncResultType.partialRetryScheduled);
      hold.complete();
      await first;
      // Let the follow-up pass the second request asked for finish.
      await device.backUp();
    });
  });

  test(
    'a restore never overwrites a local edit still waiting to go up',
    () async {
      const routineCloudId = '44444444-4444-4444-8444-444444444444';
      final routineId = await database.routineDao.insertRoutineCompanion(
        RoutinesCompanion.insert(
          title: 'Local edit',
          stepsJson: jsonEncode(const []),
          createdAt: DateTime(2026, 10, 1),
          updatedAt: drift.Value(DateTime(2026, 10, 2)),
          cloudId: const drift.Value(routineCloudId),
          ownerUserId: const drift.Value(_user),
          syncStatus: const drift.Value('pendingUpload'),
          lastSyncedAt: drift.Value(DateTime(2026, 10, 1)),
        ),
      );
      await device.outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: routineId.toString(),
        operation: SyncOperation.upsert,
      );
      cloud.routines[routineCloudId] = {
        'id': routineCloudId,
        'owner_user_id': _user,
        'title': 'Older server copy',
        'steps_json': jsonEncode(const []),
        'icon_key': null,
        'color_hex': null,
        'is_pinned': false,
        'pinned_at': null,
        'version': 1,
        'created_at': DateTime.utc(2026, 10, 1).toIso8601String(),
        // Newer clock than the local edit (another device's clock was ahead).
        'updated_at': DateTime.utc(2026, 10, 5).toIso8601String(),
      };

      await device.container
          .read(cloudRestoreCoordinatorProvider)
          .bootstrapAndMerge(_user);

      final local = await database.routineDao.getRoutineById(routineId);
      expect(local!.title, 'Local edit');
      expect(local.syncStatus, 'pendingUpload');
    },
  );
}
