import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/data/repositories/routine_run_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

void main() {
  group('RoutineRunRepository retention', () {
    late LocalDb database;
    late _FakeProofStorage proofStorage;
    late ProviderContainer container;

    Future<void> buildHarness(UserTier tier) async {
      database = LocalDb.forTesting(NativeDatabase.memory());
      proofStorage = _FakeProofStorage();
      container = ProviderContainer(
        overrides: [
          localDbProvider.overrideWithValue(database),
          routineSessionProofStorageProvider.overrideWithValue(proofStorage),
          subscriptionProvider.overrideWithValue(tier),
        ],
      );
    }

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('free history and proof photos are removed after 72 hours', () async {
      await buildHarness(UserTier.personalFree);
      final now = DateTime.now();
      final expired = _run(
        id: 'expired',
        finishedAt: now.subtract(const Duration(hours: 73)),
        stepCompletionData: _completionData(
          proofPath: 'routine_session_proofs/session/proof.webp',
          legacyPath: 'legacy/photo.jpg',
        ),
      );
      final retained = _run(
        id: 'retained',
        finishedAt: now.subtract(const Duration(hours: 71)),
      );
      await database.routineRunDao.insertOrUpdateRun(expired);
      await database.routineRunDao.insertOrUpdateRun(retained);

      await container
          .read(routineRunRepositoryProvider)
          .enforceRetentionPolicy();

      final runs = await database.routineRunDao.getAllRuns();
      expect(runs.map((run) => run.id), contains('retained'));
      expect(runs.map((run) => run.id), isNot(contains('expired')));
      expect(
        proofStorage.deletedProofs,
        containsAll(<String>[
          'routine_session_proofs/session/proof.webp',
          'legacy/photo.jpg',
        ]),
      );
    });

    test(
      'premium history is not pruned by the free retention window',
      () async {
        await buildHarness(UserTier.personalPremium);
        final run = _run(
          id: 'premium-old',
          finishedAt: DateTime.now().subtract(const Duration(days: 30)),
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

String _completionData({required String proofPath, String? legacyPath}) {
  final asset = RoutineSessionProofAsset(
    proofId: 'proof',
    localRelativePath: proofPath,
    remoteObjectKey: null,
    uploadStatus: ProofUploadStatus.localOnly,
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

  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {}

  @override
  Future<void> deleteSessionProofs(String sessionId) async {}

  @override
  Future<void> deleteStoredProof(String storedPath) async {
    deletedProofs.add(storedPath);
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
