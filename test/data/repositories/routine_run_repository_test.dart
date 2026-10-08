import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/data/repositories/routine_run_repository.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/domain/subscription_lifecycle.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/models/cloud_access_state.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RoutineRunRepository retention', () {
    late LocalDb database;
    late _FakeProofStorage proofStorage;
    late ProviderContainer container;

    Future<void> buildHarness(UserTier tier, {bool isSignedIn = false}) async {
      database = LocalDb.forTesting(NativeDatabase.memory());
      proofStorage = _FakeProofStorage();
      container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          authSessionProvider.overrideWithValue(
            AuthSessionSummary(
              isSignedIn: isSignedIn,
              userId: isSignedIn ? 'user-1' : null,
              email: isSignedIn ? 'jamie@example.com' : null,
              provider: isSignedIn ? 'google' : null,
            ),
          ),
          subscriptionProvider.overrideWithValue(tier),
          cloudSyncCoordinatorProvider.overrideWithValue(_NoopSync()),
          subscriptionLifecycleProvider.overrideWithValue(
            tier == UserTier.personalPremium
                ? const SubscriptionLifecycle(
                    phase: SubscriptionLifecyclePhase.activePremium,
                    expiredAt: null,
                    graceEndsAt: null,
                  )
                : const SubscriptionLifecycle(
                    phase: SubscriptionLifecyclePhase.free,
                    expiredAt: null,
                    graceEndsAt: null,
                  ),
          ),
        ],
      );
    }

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('deleting a backed-up run while signed out still queues the server '
        'delete, so a restore cannot bring it back', () async {
      await buildHarness(UserTier.personalPremium);
      final finishedAt = DateTime.now().subtract(const Duration(hours: 1));
      await database.routineRunDao.insertOrUpdateRun(
        _run(id: 'owned', finishedAt: finishedAt).copyWith(
          ownerUserId: const drift.Value('user-1'),
          syncStatus: 'synced',
        ),
      );
      await database.routineRunDao.insertOrUpdateRun(
        _run(id: 'local-only', finishedAt: finishedAt),
      );

      final repo = container.read(routineRunRepositoryProvider);
      await repo.deleteRun('owned');
      await repo.deleteRun('local-only');

      final queued = await container
          .read(syncOutboxRepositoryProvider)
          .pendingItems();
      expect(queued, hasLength(1));
      expect(queued.single.entityId, 'owned');
      expect(queued.single.operation, SyncOperation.delete);
    });

    test('free history and proof photos are kept for 21 days, and only the '
        'last 48 hours are shown', () async {
      await buildHarness(UserTier.personalFree);
      final now = DateTime.now();
      final expired = _run(
        id: 'expired',
        finishedAt: now.subtract(const Duration(days: 21, hours: 1)),
        stepCompletionData: _completionData(
          proofPath: 'routine_session_proofs/session/proof.webp',
          remoteObjectKey: 'users/user/runs/expired/proof.webp',
          legacyPath: 'legacy/photo.jpg',
        ),
      );
      final hidden = _run(
        id: 'hidden',
        finishedAt: now.subtract(const Duration(hours: 49)),
        stepCompletionData: _completionData(
          proofPath: 'routine_session_proofs/hidden/proof.webp',
        ),
      );
      final shown = _run(
        id: 'shown',
        finishedAt: now.subtract(const Duration(hours: 47)),
      );
      await database.routineRunDao.insertOrUpdateRun(expired);
      await database.routineRunDao.insertOrUpdateRun(hidden);
      await database.routineRunDao.insertOrUpdateRun(shown);

      await container
          .read(routineRunRepositoryProvider)
          .enforceRetentionPolicy();

      final runs = await database.routineRunDao.getAllRuns();
      expect(runs.map((run) => run.id), containsAll(['shown', 'hidden']));
      expect(runs.map((run) => run.id), isNot(contains('expired')));
      expect(
        proofStorage.deletedProofs,
        containsAll(<String>[
          'routine_session_proofs/session/proof.webp',
          'legacy/photo.jpg',
        ]),
      );
      expect(
        proofStorage.deletedProofs,
        isNot(contains('routine_session_proofs/hidden/proof.webp')),
      );
      // Retention clears this phone only. The cloud copy is left for the
      // server's 21-day cleanup, so a renewing subscriber can get it back.
      expect(proofStorage.deletedRemoteProofs, isEmpty);

      final sub = container.listen(storedRoutineRunsProvider, (_, _) {});
      await container.read(storedRoutineRunsProvider.future);
      final visible = container.read(routineHistoryVmProvider).requireValue;
      expect(visible.map((run) => run.id), ['shown']);
      expect(container.read(hiddenHistoryRunCountProvider), 1);
      sub.close();
    });

    test('premium shows the full 21 days', () async {
      await buildHarness(UserTier.personalPremium);
      await database.routineRunDao.insertOrUpdateRun(
        _run(
          id: 'old',
          finishedAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      );

      final sub = container.listen(storedRoutineRunsProvider, (_, _) {});
      await container.read(storedRoutineRunsProvider.future);
      final visible = container.read(routineHistoryVmProvider).requireValue;
      expect(visible.map((run) => run.id), ['old']);
      expect(container.read(hiddenHistoryRunCountProvider), 0);
      sub.close();
    });

    test(
      'signed-in premium history is not pruned by the free retention window',
      () async {
        await buildHarness(UserTier.personalPremium, isSignedIn: true);
        final run = _run(
          id: 'premium-old',
          finishedAt: DateTime.now().subtract(const Duration(days: 7)),
          stepCompletionData: _completionData(
            proofPath: 'routine_session_proofs/session/proof.webp',
          ),
        );
        await database.routineRunDao.insertOrUpdateRun(run);

        await container
            .read(routineRunRepositoryProvider)
            .enforceRetentionPolicy();

        final runs = await database.routineRunDao.getAllRuns();
        expect(runs.single.id, 'premium-old');
        expect(proofStorage.deletedProofs, isEmpty);
      },
    );

    test(
      'signed-out premium retains history using the premium retention window',
      () async {
        await buildHarness(UserTier.personalPremium);
        final run = _run(
          id: 'premium-signed-out-old',
          finishedAt: DateTime.now().subtract(const Duration(hours: 49)),
          stepCompletionData: _completionData(
            proofPath: 'routine_session_proofs/session/proof.webp',
          ),
        );
        await database.routineRunDao.insertOrUpdateRun(run);

        await container
            .read(routineRunRepositoryProvider)
            .enforceRetentionPolicy();

        final runs = await database.routineRunDao.getAllRuns();
        expect(runs.single.id, 'premium-signed-out-old');
        expect(proofStorage.deletedProofs, isEmpty);
      },
    );
  });

  group('RoutineRunRepository retention at start-up', () {
    late LocalDb database;
    late _FakeProofStorage proofStorage;

    setUp(() {
      database = LocalDb.forTesting(NativeDatabase.memory());
      proofStorage = _FakeProofStorage();
    });

    tearDown(() async {
      await database.close();
    });

    Future<ProviderContainer> containerWithStoredAccount(
      Future<void> Function(SubscriptionAccountController writer) store, {
      bool resetPrefs = true,
    }) async {
      if (resetPrefs) SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writer = SubscriptionAccountController(
        database,
        prefs: prefs,
        loadOnInit: false,
      );
      await store(writer);
      final container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          authSessionProvider.overrideWithValue(
            const AuthSessionSummary(
              isSignedIn: false,
              userId: null,
              email: null,
              provider: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'a Premium user\'s history is not pruned before the stored plan loads',
      () async {
        final container = await containerWithStoredAccount(
          (writer) => writer.applyRevenueCatEntitlement(
            UserTier.personalPremium,
            periodEndsAt: DateTime.now().add(const Duration(days: 20)),
          ),
        );
        await database.routineRunDao.insertOrUpdateRun(
          _run(
            id: 'five-days-old',
            finishedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        );

        // First read creates the account controller in its Free default;
        // retention must wait for the stored Premium plan.
        await container
            .read(routineRunRepositoryProvider)
            .enforceRetentionPolicy();

        final runs = await database.routineRunDao.getAllRuns();
        expect(runs.map((run) => run.id), ['five-days-old']);
      },
    );

    test(
      'a lapse inferred from an old cached period end deletes nothing',
      () async {
        // Last seen period end was 30 days ago: the plan may well have
        // renewed while the app was closed. Until the store confirms the
        // lapse, history keeps the Premium window.
        final container = await containerWithStoredAccount(
          (writer) => writer.applyRevenueCatEntitlement(
            UserTier.personalPremium,
            periodEndsAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        );
        await database.routineRunDao.insertOrUpdateRun(
          _run(
            id: 'ten-days-old',
            finishedAt: DateTime.now().subtract(const Duration(days: 10)),
          ),
        );

        await container
            .read(routineRunRepositoryProvider)
            .enforceRetentionPolicy();

        final account = container.read(subscriptionAccountControllerProvider);
        expect(account.entitlementStatus, EntitlementStatus.expired);
        expect(account.entitlementLapseNoticedAt, isNull);
        final runs = await database.routineRunDao.getAllRuns();
        expect(runs.map((run) => run.id), ['ten-days-old']);
      },
    );

    test('a confirmed lapse shows 21 days for 7 days, then hides what is older '
        'than 48 hours without deleting it', () async {
      final container = await containerWithStoredAccount((writer) async {
        await writer.applyRevenueCatEntitlement(
          UserTier.personalPremium,
          periodEndsAt: DateTime.now().subtract(const Duration(days: 9)),
        );
        await writer.applyExpiredStoreEntitlement();
      });
      await database.routineRunDao.insertOrUpdateRun(
        _run(
          id: 'three-days-old',
          finishedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      await container
          .read(routineRunRepositoryProvider)
          .enforceRetentionPolicy();

      // Confirmed just now, so grace runs 7 days from today even though
      // the period ended 9 days ago: the user gets the full warning.
      var runs = await database.routineRunDao.getAllRuns();
      expect(runs.map((run) => run.id), ['three-days-old']);
      expect(
        container.read(subscriptionLifecycleProvider).phase,
        SubscriptionLifecyclePhase.expiredGrace,
      );

      container.dispose();
      // Simulate the grace window having passed: the lapse was confirmed
      // 8 days ago. The next launch reads that and applies Free limits.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pebble.entitlement.lapse_noticed_at',
        DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      );
      final afterGrace = await containerWithStoredAccount(
        (_) async {},
        resetPrefs: false,
      );
      await afterGrace
          .read(routineRunRepositoryProvider)
          .enforceRetentionPolicy();
      expect(
        afterGrace.read(subscriptionLifecycleProvider).phase,
        SubscriptionLifecyclePhase.expired,
      );
      runs = await database.routineRunDao.getAllRuns();
      expect(runs.map((run) => run.id), ['three-days-old']);
      final sub = afterGrace.listen(storedRoutineRunsProvider, (_, _) {});
      await afterGrace.read(storedRoutineRunsProvider.future);
      expect(afterGrace.read(routineHistoryVmProvider).requireValue, isEmpty);
      expect(afterGrace.read(hiddenHistoryRunCountProvider), 1);
      sub.close();
    });
  });
}

RoutineRun _run({
  required String id,
  required DateTime finishedAt,
  String? stepCompletionData,
}) {
  return RoutineRun(
    id: id,
    routineId: '1',
    routineTitle: 'Routine',
    finishedAt: finishedAt,
    stepCompletionData: stepCompletionData,
    ownerUserId: null,
    syncStatus: 'localOnly',
    lastSyncedAt: null,
    syncMetadataJson: null,
    updatedAt: finishedAt,
  );
}

String _completionData({
  required String proofPath,
  String? remoteObjectKey,
  String? legacyPath,
}) {
  final asset = RoutineSessionProofAsset(
    proofId: 'proof',
    localRelativePath: proofPath,
    remoteObjectKey: remoteObjectKey,
    uploadStatus: remoteObjectKey == null
        ? ProofUploadStatus.localOnly
        : ProofUploadStatus.uploaded,
    capturedAt: DateTime.now(),
  );
  return jsonEncode({
    'steps': [
      {
        'proofAssets': [asset.toJson()],
        'photos': [if (legacyPath != null) legacyPath],
      },
    ],
  });
}

class _FakeProofStorage implements RoutineSessionProofStorage {
  final Set<String> deletedProofs = <String>{};
  final Set<String> deletedRemoteProofs = <String>{};

  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  Future<void> deleteSessionProofs(String sessionId) async {}

  @override
  Future<void> deleteStoredProof(String storedPath) async {
    deletedProofs.add(storedPath);
  }

  @override
  Future<void> deleteProofAsset(RoutineSessionProofAsset asset) async {
    deletedProofs.add(asset.localRelativePath);
    final remoteObjectKey = asset.remoteObjectKey;
    if (remoteObjectKey != null) {
      deletedRemoteProofs.add(remoteObjectKey);
    }
  }

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async => null;

  @override
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset) async =>
      null;

  @override
  Future<String> resolveStoredPath(String storedPath) async => storedPath;

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    return asset;
  }
}

/// Repository writes kick a backup pass; these tests only check what was
/// queued.
class _NoopSync implements CloudSyncCoordinator {
  @override
  Future<void> kick() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
