import 'dart:convert';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/local/routine_run_dao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routine_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/providers/cloud_access_provider.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/sync/cloud_sync_coordinator.dart';
import 'package:pebble_routines/features/sync/sync_outbox_repository.dart';

abstract class RoutineRunRepository {
  Stream<List<RoutineRun>> watchRuns();
  Future<void> saveRun(RoutineRun run);
  Future<void> deleteAllRuns();
  Future<void> deleteRun(String id);
  Future<void> enforceRetentionPolicy();
}

class RoutineRunRepositoryImpl implements RoutineRunRepository {
  final RoutineRunDao _dao;
  final Ref _ref;
  final RoutineSessionProofStorage _proofStorage;
  RoutineRunRepositoryImpl(this._dao, this._ref, this._proofStorage);

  @override
  Stream<List<RoutineRun>> watchRuns() {
    return _dao.watchAllRuns().asyncMap((runs) async {
      return _pruneExpiredRuns(runs);
    });
  }

  @override
  Future<void> saveRun(RoutineRun run) async {
    await enforceRetentionPolicy();
    final policy = _ref.read(cloudAccessPolicyProvider);
    final ownerUserId = policy.cachedOwnerUserId;
    final shouldQueue = policy.canQueuePersonalSync;
    final prepared = RoutineRun(
      id: run.id,
      routineId: run.routineId,
      routineTitle: run.routineTitle,
      finishedAt: run.finishedAt,
      stepCompletionData: run.stepCompletionData,
      ownerUserId: ownerUserId ?? run.ownerUserId,
      syncStatus: shouldQueue ? 'pendingUpload' : run.syncStatus,
      lastSyncedAt: run.lastSyncedAt,
      syncMetadataJson: run.syncMetadataJson,
      updatedAt: DateTime.now(),
    );
    await _dao.insertOrUpdateRun(prepared);
    if (shouldQueue) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.run,
            entityId: prepared.id,
            operation: SyncOperation.upsert,
          );
      await _ref.read(cloudSyncCoordinatorProvider).kick();
    }
  }

  @override
  Future<void> deleteAllRuns() async {
    final policy = _ref.read(cloudAccessPolicyProvider);
    final runs = await _dao.getAllRuns();
    for (final run in runs.where((item) {
      return policy.canQueuePersonalSync &&
          item.ownerUserId != null &&
          item.ownerUserId!.isNotEmpty;
    })) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.run,
            entityId: run.id,
            operation: SyncOperation.delete,
          );
    }
    for (final run in runs) {
      await _deleteProofsForRun(run);
    }
    await _dao.deleteAllRuns();
    await _ref.read(cloudSyncCoordinatorProvider).kick();
  }

  @override
  Future<void> deleteRun(String id) async {
    final policy = _ref.read(cloudAccessPolicyProvider);
    final run = await _dao.getRunById(id);
    if (policy.canQueuePersonalSync &&
        run?.ownerUserId != null &&
        run!.ownerUserId!.isNotEmpty) {
      await _ref
          .read(syncOutboxRepositoryProvider)
          .enqueue(
            entityType: SyncEntityType.run,
            entityId: id,
            operation: SyncOperation.delete,
          );
    }
    if (run != null) {
      await _deleteProofsForRun(run);
    }
    await _dao.deleteRun(id);
    await _ref.read(cloudSyncCoordinatorProvider).kick();
  }

  @override
  Future<void> enforceRetentionPolicy() async {
    final runs = await _dao.getAllRuns();
    await _pruneExpiredRuns(runs);
  }

  Future<List<RoutineRun>> _pruneExpiredRuns(List<RoutineRun> runs) async {
    final retention = _ref.read(accountHistoryRetentionProvider);

    final cutoff = DateTime.now().subtract(retention);
    final expiredRuns = runs
        .where((run) => !run.finishedAt.isAfter(cutoff))
        .toList(growable: false);

    for (final run in expiredRuns) {
      await _deleteProofsForRun(run);
      await _dao.deleteRun(run.id);
    }

    if (expiredRuns.isEmpty) {
      return runs;
    }

    final expiredIds = expiredRuns.map((run) => run.id).toSet();
    return runs
        .where((run) => !expiredIds.contains(run.id))
        .toList(growable: false);
  }

  Future<void> _deleteProofsForRun(RoutineRun run) async {
    final refs = _proofRefsForRun(run);
    for (final asset in refs.assets) {
      await _proofStorage.deleteProofAsset(asset);
    }
    for (final path in refs.legacyPaths) {
      await _proofStorage.deleteStoredProof(path);
    }
  }

  _RunProofRefs _proofRefsForRun(RoutineRun run) {
    final raw = run.stepCompletionData;
    if (raw == null || raw.isEmpty) {
      return const _RunProofRefs();
    }

    final assetsByLocalPath = <String, RoutineSessionProofAsset>{};
    final legacyPaths = <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const _RunProofRefs();
      }
      final steps = decoded['steps'];
      if (steps is! List) {
        return const _RunProofRefs();
      }

      for (final rawStep in steps) {
        if (rawStep is! Map) {
          continue;
        }
        final step = Map<String, dynamic>.from(rawStep);
        final proofAssets = step['proofAssets'];
        if (proofAssets is List) {
          for (final rawAsset in proofAssets) {
            if (rawAsset is! Map) {
              continue;
            }
            final asset = RoutineSessionProofAsset.fromJson(
              Map<String, dynamic>.from(rawAsset),
            );
            if (asset.localRelativePath.isNotEmpty) {
              assetsByLocalPath[asset.localRelativePath] = asset;
            }
          }
        }

        final legacyPhotos = step['photos'];
        if (legacyPhotos is List) {
          for (final rawPath in legacyPhotos) {
            final path = rawPath.toString();
            if (path.isNotEmpty && !assetsByLocalPath.containsKey(path)) {
              legacyPaths.add(path);
            }
          }
        }
      }
    } catch (_) {
      return _RunProofRefs(
        assets: assetsByLocalPath.values.toList(growable: false),
        legacyPaths: legacyPaths,
      );
    }
    return _RunProofRefs(
      assets: assetsByLocalPath.values.toList(growable: false),
      legacyPaths: legacyPaths,
    );
  }
}

class _RunProofRefs {
  const _RunProofRefs({
    this.assets = const <RoutineSessionProofAsset>[],
    this.legacyPaths = const <String>{},
  });

  final List<RoutineSessionProofAsset> assets;
  final Set<String> legacyPaths;
}

final routineRunRepositoryProvider = Provider<RoutineRunRepository>((ref) {
  final db = ref.read(localDbProvider);
  final proofStorage = ref.read(routineSessionProofStorageProvider);
  return RoutineRunRepositoryImpl(db.routineRunDao, ref, proofStorage);
});
