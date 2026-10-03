import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/remote/remote_proof_asset_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_reminder_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/data/models/subscription_account_state.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_restore_coordinator.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/guidance_audio_cloud_backup.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

const _userId = '11111111-1111-1111-1111-111111111111';
const _clipName = '5b0c0d4e-0000-4000-8000-000000000001.wav';
const _clipKey = 'users/$_userId/guidance_audio/$_clipName';

class _FakeProofAssetRemote extends RemoteProofAssetDataSource {
  _FakeProofAssetRemote() : super(null);

  final uploads = <String, Uint8List>{};
  final usageRetention = <String, Duration>{};
  final downloads = <String>[];
  final deletes = <String>[];
  final stored = <String, Uint8List>{};
  Object? uploadError;
  Object? downloadError;

  @override
  bool get isEnabled => true;

  @override
  Future<void> uploadBytes({
    required String objectKey,
    required Uint8List bytes,
    required String contentType,
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required DateTime capturedAt,
    Duration retention = const Duration(days: 21),
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    uploads[objectKey] = bytes;
    usageRetention[objectKey] = retention;
  }

  @override
  Future<Uint8List?> downloadBytes(String objectKey) async {
    downloads.add(objectKey);
    final error = downloadError;
    if (error != null) throw error;
    final bytes = stored[objectKey];
    if (bytes == null) {
      throw const StorageException(
        'Object not found',
        error: 'not_found',
        statusCode: '400',
      );
    }
    return bytes;
  }

  @override
  Future<void> deleteObject(String objectKey) async {
    deletes.add(objectKey);
  }
}

class _RecordingFairUseStore implements ProofMediaFairUseStore {
  final recorded = <int>[];

  @override
  Future<ProofMediaFairUseCheck> canUploadProof({required int byteCount}) {
    throw UnimplementedError('Voice prompts must not be blocked client-side');
  }

  @override
  Future<ProofMediaFairUseState> load() async => const ProofMediaFairUseState(
    activeCloudBytes: 0,
    storageLimitBytes: ProofMediaFairUsePolicy.storageLimitBytes,
    uploadsThisPeriod: 0,
    monthlyUploadLimit: ProofMediaFairUsePolicy.monthlyUploadLimit,
  );

  @override
  Future<void> recordProofUpload({required int byteCount}) async {
    recorded.add(byteCount);
  }
}

class _FakeProofStorage implements RoutineSessionProofStorage {
  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingRoutineDataSource extends RemoteRoutineDataSource {
  _RecordingRoutineDataSource([this.records = const []]) : super(null);

  final List<RemoteRoutineRecord> records;
  final upserts = <Map<String, dynamic>>[];

  @override
  Future<List<RemoteRoutineRecord>> fetchAll(String ownerUserId) async =>
      records;

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    upserts.add(payload);
  }
}

class _TestSubscriptionAccountController extends SubscriptionAccountController {
  _TestSubscriptionAccountController(super.db) : super(loadOnInit: false) {
    state = const SubscriptionAccountState(
      entitlementTier: UserTier.personalPremium,
      pendingTier: null,
      bootstrapStatus: BootstrapStatus.ready,
      userId: _userId,
      email: 'jamie@example.com',
      authProvider: 'google',
      lastBootstrapAt: null,
      lastSyncAt: null,
      lastSyncError: null,
      entitlementStatus: EntitlementStatus.personalPremium,
      entitlementSource: EntitlementSource.serverVerified,
    );
  }
}

String _stepsJson({String? remoteObjectKey, String clipName = _clipName}) {
  return jsonEncode([
    {
      'runtimeType': 'check',
      'label': 'Feed the cat',
      'guidanceAudio': {
        'localPath': clipName,
        'durationMs': 4000,
        'mimeType': 'audio/wav',
        'byteSize': 4,
        'remoteObjectKey': ?remoteObjectKey,
      },
    },
  ]);
}

Routine _routine({required int id, required String stepsJson}) {
  return Routine(
    id: id,
    title: 'Evening',
    stepsJson: stepsJson,
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
    ownerUserId: _userId,
    syncStatus: 'pendingUpload',
    lastSyncedAt: null,
  );
}

void main() {
  late Directory tempRoot;
  late LocalGuidanceAudioStorage storage;
  late _FakeProofAssetRemote remote;
  late _RecordingFairUseStore fairUse;
  late SharedPreferences prefs;
  late DateTime now;

  GuidanceAudioCloudBackup newBackup() => GuidanceAudioCloudBackup(
    remote: remote,
    storage: storage,
    fairUseStore: () => fairUse,
    prefs: () => prefs,
    now: () => now,
  );

  Future<File> clipFile([String name = _clipName]) async =>
      File(await storage.resolveStoredPath(name));

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('pebble_audio_backup_');
    storage = LocalGuidanceAudioStorage(
      documentsDirectory: () async => tempRoot,
    );
    remote = _FakeProofAssetRemote();
    fairUse = _RecordingFairUseStore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 3, 9);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('GuidanceAudioCloudBackup', () {
    test('uploads under the user prefix and tracks fair use', () async {
      final file = await clipFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);

      final result = await newBackup().uploadPending(
        stepsJson: _stepsJson(),
        ownerUserId: _userId,
        entityId: '7',
      );

      expect(result.failure, isNull);
      expect(result.uploadedKeys, {_clipName: _clipKey});
      expect(remote.uploads.keys, [_clipKey]);
      expect(
        remote.usageRetention[_clipKey],
        GuidanceAudioCloudBackup.remoteRetention,
      );
      expect(fairUse.recorded, [4]);

      final keyed = GuidanceAudioCloudBackup.applyRemoteKeys(
        _stepsJson(),
        result.uploadedKeys,
      );
      expect(
        GuidanceAudioCloudBackup.clipsIn(keyed).single.remoteObjectKey,
        _clipKey,
      );
    });

    test('skips clips that are already backed up or missing locally', () async {
      final backup = newBackup();

      final missing = await backup.uploadPending(
        stepsJson: _stepsJson(),
        ownerUserId: _userId,
        entityId: '7',
      );
      final keyed = await backup.uploadPending(
        stepsJson: _stepsJson(remoteObjectKey: _clipKey),
        ownerUserId: _userId,
        entityId: '7',
      );

      expect(missing.uploadedKeys, isEmpty);
      expect(keyed.uploadedKeys, isEmpty);
      expect(remote.uploads, isEmpty);
      expect(
        await backup.needsUpload(stepsJson: _stepsJson(), ownerUserId: _userId),
        isFalse,
      );
    });

    test('downloads a backed-up clip that is missing locally', () async {
      remote.stored[_clipKey] = Uint8List.fromList([9, 8, 7]);

      final restored = await newBackup().restoreMissing(
        stepsJsons: [_stepsJson(remoteObjectKey: _clipKey)],
        ownerUserId: _userId,
      );

      expect(restored, 1);
      final file = await clipFile();
      expect(await file.readAsBytes(), [9, 8, 7]);
      expect(p.basename(file.path), _clipName);
      expect(File('${file.path}.part').existsSync(), isFalse);
    });

    test(
      'remembers a clip the server no longer has and stops asking',
      () async {
        final stepsJson = _stepsJson(remoteObjectKey: _clipKey);

        expect(
          await newBackup().restoreMissing(
            stepsJsons: [stepsJson],
            ownerUserId: _userId,
          ),
          0,
        );
        now = now.add(const Duration(days: 2));
        // A fresh instance (next app launch) reads the persisted miss.
        await newBackup().restoreMissing(
          stepsJsons: [stepsJson],
          ownerUserId: _userId,
        );
        await newBackup().restoreMissing(
          stepsJsons: [stepsJson],
          ownerUserId: _userId,
        );

        expect(remote.downloads, [_clipKey]);
        expect(await (await clipFile()).exists(), isFalse);
      },
    );

    test('backs off transient download failures instead of looping', () async {
      final backup = newBackup();
      final stepsJson = _stepsJson(remoteObjectKey: _clipKey);
      remote.downloadError = const SocketException('offline');

      await backup.restoreMissing(
        stepsJsons: [stepsJson],
        ownerUserId: _userId,
      );
      await backup.restoreMissing(
        stepsJsons: [stepsJson],
        ownerUserId: _userId,
      );
      expect(remote.downloads, hasLength(1));

      remote.downloadError = null;
      remote.stored[_clipKey] = Uint8List.fromList([1]);
      now = now.add(GuidanceAudioCloudBackup.transientRetryDelay);
      final restored = await backup.restoreMissing(
        stepsJsons: [stepsJson],
        ownerUserId: _userId,
      );

      expect(restored, 1);
      expect(remote.downloads, hasLength(2));
    });

    test('ignores keys that belong to another account', () async {
      await newBackup().restoreMissing(
        stepsJsons: [
          _stepsJson(
            remoteObjectKey: 'users/someone-else/guidance_audio/$_clipName',
          ),
        ],
        ownerUserId: _userId,
      );

      expect(remote.downloads, isEmpty);
    });
  });

  group('Cloud sync of voice prompts', () {
    late LocalDb database;
    late SyncOutboxRepository outbox;
    late _RecordingRoutineDataSource routineRemote;
    late ProviderContainer container;

    final coordinatorProvider = Provider<CloudSyncCoordinator>((ref) {
      return CloudSyncCoordinator(
        ref: ref,
        database: ref.read(localDbProvider),
        outbox: ref.read(syncOutboxRepositoryProvider),
        remoteRoutineDataSource: ref.read(remoteRoutineDataSourceProvider),
        remoteReminderDataSource: RemoteRoutineReminderDataSource(null),
        remoteRunDataSource: RemoteRoutineRunDataSource(null),
        remoteSessionDataSource: RemoteRoutineSessionDataSource(null),
        proofStorage: _FakeProofStorage(),
        guidanceAudioBackup: ref.read(guidanceAudioCloudBackupProvider),
      );
    });

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
      outbox = SyncOutboxRepositoryImpl(database);
      routineRemote = _RecordingRoutineDataSource();
      container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          syncOutboxRepositoryProvider.overrideWithValue(outbox),
          remoteRoutineDataSourceProvider.overrideWithValue(routineRemote),
          guidanceAudioStorageProvider.overrideWithValue(storage),
          guidanceAudioCloudBackupProvider.overrideWith((ref) => newBackup()),
          cloudSyncCoordinatorProvider.overrideWith(
            (ref) => ref.watch(coordinatorProvider),
          ),
          authSessionProvider.overrideWithValue(
            const AuthSessionSummary(
              isSignedIn: true,
              userId: _userId,
              email: 'jamie@example.com',
              provider: 'google',
            ),
          ),
          subscriptionAccountControllerProvider.overrideWith(
            (ref) => _TestSubscriptionAccountController(database),
          ),
          cloudAccessPolicyProvider.overrideWithValue(
            const CloudAccessPolicy(
              cachedOwnerUserId: _userId,
              personalCloudEnabled: true,
              // Keeps repository writes from kicking a real sync.
              canQueuePersonalSync: false,
              workspaceCloudEnabled: false,
              isSignedIn: true,
              isAccountSwitchBlocked: false,
            ),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('routine sync uploads the clip and records its key', () async {
      final file = await clipFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 7, stepsJson: _stepsJson()),
      );
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '7',
        operation: SyncOperation.upsert,
      );

      final result = await container.read(coordinatorProvider).runManualSync();

      expect(result.type, ManualSyncResultType.synced);
      expect(remote.uploads.keys, [_clipKey]);
      final local = await database.routineDao.getRoutineById(7);
      expect(
        GuidanceAudioCloudBackup.clipsIn(
          local!.stepsJson,
        ).single.remoteObjectKey,
        _clipKey,
      );
      expect(local.syncStatus, 'synced');
      final uploadedSteps =
          routineRemote.upserts.single['steps_json'] as String;
      expect(
        GuidanceAudioCloudBackup.clipsIn(uploadedSteps).single.remoteObjectKey,
        _clipKey,
      );
      expect(await outbox.pendingItems(), isEmpty);
    });

    test('a failed clip still syncs the routine and queues a retry', () async {
      final file = await clipFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);
      remote.uploadError = Exception(
        'Proof media rolling upload quota exceeded.',
      );
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 7, stepsJson: _stepsJson()),
      );
      await outbox.enqueue(
        entityType: SyncEntityType.routine,
        entityId: '7',
        operation: SyncOperation.upsert,
      );

      await container.read(coordinatorProvider).runManualSync();

      expect(routineRemote.upserts, hasLength(1));
      final pending = await outbox.pendingItems();
      expect(pending, hasLength(1));
      expect(pending.single.entityType, SyncEntityType.guidanceAudio);
      expect(pending.single.operation, SyncOperation.upload);
      expect(pending.single.entityId, '7');
    });

    test('backs up clips of routines synced before audio backup', () async {
      final file = await clipFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 7, stepsJson: _stepsJson()).copyWith(
          cloudId: const drift.Value('33333333-3333-4333-8333-333333333333'),
          syncStatus: 'synced',
        ),
      );

      await container.read(coordinatorProvider).runManualSync();
      await container.read(coordinatorProvider).runManualSync();

      expect(remote.uploads.keys, [_clipKey]);
      expect(routineRemote.upserts, hasLength(1));
      expect(await outbox.pendingItems(), isEmpty);
    });

    test('restore brings back a clip missing on the new phone', () async {
      remote.stored[_clipKey] = Uint8List.fromList([5, 6]);
      final restoreCoordinator = CloudRestoreCoordinator(
        database: database,
        remoteRoutineDataSource: _RecordingRoutineDataSource([
          RemoteRoutineRecord(
            id: '33333333-3333-4333-8333-333333333333',
            ownerUserId: _userId,
            title: 'Evening',
            stepsJson: _stepsJson(remoteObjectKey: _clipKey),
            iconKey: null,
            colorHex: null,
            isPinned: false,
            pinnedAt: null,
            version: 1,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 2, 1),
          ),
        ]),
        remoteReminderDataSource: RemoteRoutineReminderDataSource(null),
        remoteRunDataSource: RemoteRoutineRunDataSource(null),
        remoteSessionDataSource: RemoteRoutineSessionDataSource(null),
        outbox: outbox,
      );

      // Bootstrap is always followed by a sync kick, which fetches audio.
      await restoreCoordinator.bootstrapAndMerge(_userId);
      expect(await (await clipFile()).exists(), isFalse);
      await container.read(coordinatorProvider).kick();

      expect(await (await clipFile()).readAsBytes(), [5, 6]);
      // The restored clip is referenced, so garbage collection keeps it.
      await container.read(coordinatorProvider).kick();
      expect(await (await clipFile()).exists(), isTrue);
      expect(remote.downloads, [_clipKey]);
    });

    test('replacing a clip deletes the old remote copy', () async {
      final repository = container.read(routineRepositoryProvider);
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 7, stepsJson: _stepsJson(remoteObjectKey: _clipKey)),
      );
      const newClip = '5b0c0d4e-0000-4000-8000-000000000002.wav';
      final existing = await database.routineDao.getRoutineById(7);
      await repository.saveRoutine(
        existing!.copyWith(stepsJson: _stepsJson(clipName: newClip)),
      );

      final pending = await outbox.pendingItems();
      expect(pending.single.entityType, SyncEntityType.guidanceAudio);
      expect(pending.single.operation, SyncOperation.delete);
      expect(pending.single.entityId, _clipKey);

      await container.read(coordinatorProvider).runManualSync();
      expect(remote.deletes, [_clipKey]);
    });

    test('a clip still used by a duplicate is kept on delete', () async {
      final repository = container.read(routineRepositoryProvider);
      await database.routineDao.insertOrUpdateRoutine(
        _routine(id: 7, stepsJson: _stepsJson(remoteObjectKey: _clipKey)),
      );
      await repository.duplicateRoutine(7);
      // Deleting kicks a sync, which processes the queued remote delete.
      await repository.deleteRoutine(7);

      expect(remote.deletes, isEmpty);
      expect(
        (await outbox.pendingItems()).where(
          (item) => item.entityType == SyncEntityType.guidanceAudio,
        ),
        isEmpty,
      );

      final remaining = await database.routineDao.getAllRoutines();
      await repository.deleteRoutine(remaining.single.id);
      expect(remote.deletes, [_clipKey]);
    });
  });
}
