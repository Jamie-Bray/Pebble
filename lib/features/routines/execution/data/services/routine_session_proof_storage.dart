import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:pebble_routines/data/remote/remote_proof_asset_data_source.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';

abstract class RoutineSessionProofStorage {
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  });

  Future<String> resolveStoredPath(String storedPath);
  Future<File?> resolveStoredFile(String storedPath);
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset);
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  });
  Future<void> deleteStoredProof(String storedPath);
  Future<void> deleteProofAsset(RoutineSessionProofAsset asset);
  Future<void> deleteSessionProofs(String sessionId);
  Future<void> enforceRetentionPolicy({required bool isPremium});
}

class LocalRoutineSessionProofStorage implements RoutineSessionProofStorage {
  LocalRoutineSessionProofStorage({
    required RemoteProofAssetDataSource remote,
    required ProofMediaFairUseStore fairUseStore,
    DateTime Function()? clock,
  }) : _remote = remote,
       _fairUseStore = fairUseStore,
       _clock = clock ?? DateTime.now;

  static const _rootFolder = 'routine_session_proofs';
  static const _uuid = Uuid();
  static const _downloadRetryBase = Duration(minutes: 1);
  static const _downloadRetryMax = Duration(hours: 1);
  final RemoteProofAssetDataSource _remote;
  final ProofMediaFairUseStore _fairUseStore;
  final DateTime Function() _clock;

  // History and gallery screens resolve every photo on each rebuild, and any
  // sync state change rebuilds them. Without this memory a proof whose cloud
  // copy is gone was re-requested every few minutes for as long as the app
  // stayed open. Missing objects are not retried until the next launch;
  // other failures back off exponentially.
  final Map<String, _ProofDownloadFailure> _downloadFailures = {};
  final Map<String, Future<Uint8List?>> _downloadsInFlight = {};

  @override
  Future<RoutineSessionProofAsset> persistCapturedProof({
    required String sessionId,
    required String sourcePath,
  }) async {
    final stopwatch = Stopwatch()..start();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('Captured proof file not found: $sourcePath');
    }

    final root = await _rootDirectory();
    final sessionDirectory = Directory(p.join(root.path, sessionId));
    if (!await sessionDirectory.exists()) {
      await sessionDirectory.create(recursive: true);
    }

    final proofId = _uuid.v4();
    final sourceByteCount = await sourceFile.length();

    // Every proof must be re-encoded rather than copied: compression drops EXIF
    // metadata (including GPS coordinates that camera and gallery sources can
    // embed), so location data never reaches app storage or cloud backup.
    var absoluteTarget = p.join(sessionDirectory.path, '$proofId.webp');
    var outputFormat = CompressFormat.webp;
    var compressed = await FlutterImageCompress.compressAndGetFile(
      sourceFile.absolute.path,
      absoluteTarget,
      quality: 70,
      format: outputFormat,
    );

    // Some platforms/codecs can fail WebP re-encoding. JPEG is still a safe
    // re-encode path, while copying the original bytes would preserve EXIF.
    if (compressed == null) {
      absoluteTarget = p.join(sessionDirectory.path, '$proofId.jpg');
      outputFormat = CompressFormat.jpeg;
      compressed = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        absoluteTarget,
        quality: 72,
        format: outputFormat,
      );
    }

    if (compressed == null) {
      throw StateError('Could not re-encode proof photo safely.');
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final relativePath = p.relative(
      absoluteTarget,
      from: documentsDirectory.path,
    );

    final asset = RoutineSessionProofAsset(
      proofId: proofId,
      localRelativePath: relativePath,
      remoteObjectKey: null,
      uploadStatus: ProofUploadStatus.localOnly,
      capturedAt: DateTime.now(),
    );
    developer.log(
      'persistCapturedProof compressed ${outputFormat.name} '
      '${sourceByteCount ~/ 1024}KB in ${stopwatch.elapsedMilliseconds}ms',
      name: 'RoutinePlayer',
    );
    return asset;
  }

  @override
  Future<String> resolveStoredPath(String storedPath) async {
    if (storedPath.isEmpty) {
      return storedPath;
    }
    if (p.isAbsolute(storedPath)) {
      return storedPath;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, storedPath);
  }

  @override
  Future<File?> resolveStoredFile(String storedPath) async {
    final absolutePath = await resolveStoredPath(storedPath);
    if (absolutePath.isEmpty) {
      return null;
    }
    final file = File(absolutePath);
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  @override
  Future<File?> resolveProofAssetFile(RoutineSessionProofAsset asset) async {
    final local = await resolveStoredFile(asset.localRelativePath);
    if (local != null) {
      return local;
    }
    final remoteObjectKey = asset.remoteObjectKey;
    if (remoteObjectKey == null ||
        remoteObjectKey.isEmpty ||
        !_remote.isEnabled) {
      return null;
    }

    final bytes = await _downloadProofBytes(remoteObjectKey);
    if (bytes == null) {
      return null;
    }
    final absolutePath = await resolveStoredPath(asset.localRelativePath);
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List?> _downloadProofBytes(String objectKey) async {
    // Only the signed-in owner can read users/<uid>/... objects. Signed out,
    // deleted, or a different account: the request could only fail.
    final userId = _remote.signedInUserId;
    if (userId == null ||
        userId.isEmpty ||
        !objectKey.startsWith('users/$userId/')) {
      return null;
    }
    final failure = _downloadFailures[objectKey];
    if (failure != null && _clock().isBefore(failure.retryAt)) {
      return null;
    }
    final inFlight = _downloadsInFlight[objectKey];
    if (inFlight != null) {
      return inFlight;
    }
    final download = _attemptDownload(objectKey);
    _downloadsInFlight[objectKey] = download;
    try {
      return await download;
    } finally {
      // Already awaited above; removing it just ends the de-duplication.
      _downloadsInFlight.remove(objectKey)?.ignore();
    }
  }

  Future<Uint8List?> _attemptDownload(String objectKey) async {
    try {
      final bytes = await _remote.downloadBytes(objectKey);
      if (bytes != null) {
        _downloadFailures.remove(objectKey);
      }
      return bytes;
    } catch (error) {
      final missing = isMissingProofObjectError(error);
      final attempts = (_downloadFailures[objectKey]?.attempts ?? 0) + 1;
      final backoff = _downloadRetryBase * (1 << (attempts - 1).clamp(0, 6));
      final retryIn = missing
          ? const Duration(days: 365)
          : backoff > _downloadRetryMax
          ? _downloadRetryMax
          : backoff;
      _downloadFailures[objectKey] = _ProofDownloadFailure(
        attempts: attempts,
        retryAt: _clock().add(retryIn),
      );
      developer.log(
        'Proof download failed for $objectKey '
        '(${missing ? 'missing, not retrying' : 'attempt $attempts'}): '
        '$error',
        name: 'RoutinePlayer',
      );
      return null;
    }
  }

  @override
  Future<RoutineSessionProofAsset> uploadProofAsset({
    required RoutineSessionProofAsset asset,
    required String ownerUserId,
    required String entityType,
    required String entityId,
  }) async {
    final file = await resolveStoredFile(asset.localRelativePath);
    if (file == null) {
      return asset.copyWith(uploadStatus: ProofUploadStatus.failed);
    }
    if (!_remote.isEnabled) {
      return asset.copyWith(uploadStatus: ProofUploadStatus.pendingUpload);
    }

    final bytes = await file.readAsBytes();
    final fairUseCheck = await _fairUseStore.canUploadProof(
      byteCount: bytes.length,
    );
    if (!fairUseCheck.allowed) {
      return asset.copyWith(
        uploadStatus:
            fairUseCheck.reason == ProofMediaUploadBlockReason.fileTooLarge
            ? ProofUploadStatus.failed
            : ProofUploadStatus.pendingUpload,
      );
    }
    final ext = p.extension(file.path).replaceFirst('.', '');
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final objectKey =
        'users/$ownerUserId/$entityType/$entityId/${asset.proofId}.$safeExt';
    await _remote.uploadBytes(
      objectKey: objectKey,
      bytes: bytes,
      contentType: _contentTypeForPath(file.path),
      ownerUserId: ownerUserId,
      entityType: entityType,
      entityId: entityId,
      capturedAt: asset.capturedAt,
    );
    await _fairUseStore.recordProofUpload(byteCount: bytes.length);
    return asset.copyWith(
      remoteObjectKey: objectKey,
      uploadStatus: ProofUploadStatus.uploaded,
    );
  }

  @override
  Future<void> deleteStoredProof(String storedPath) async {
    final absolutePath = await resolveStoredPath(storedPath);
    if (absolutePath.isEmpty) {
      return;
    }
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteProofAsset(RoutineSessionProofAsset asset) async {
    await deleteStoredProof(asset.localRelativePath);
    final remoteObjectKey = asset.remoteObjectKey;
    if (remoteObjectKey != null && remoteObjectKey.isNotEmpty) {
      // Remote cleanup is best-effort: RLS denies proof_asset_usage writes
      // once premium lapses, and the server-side retention job removes
      // expired objects regardless, so a failure here must never block
      // local deletion (history pruning runs inside the watchRuns stream).
      try {
        await _remote.deleteObject(remoteObjectKey);
      } catch (error) {
        developer.log(
          'Best-effort remote proof delete failed for $remoteObjectKey: '
          '$error',
          name: 'RoutinePlayer',
        );
      }
    }
  }

  @override
  Future<void> deleteSessionProofs(String sessionId) async {
    final root = await _rootDirectory();
    final sessionDirectory = Directory(p.join(root.path, sessionId));
    if (await sessionDirectory.exists()) {
      await sessionDirectory.delete(recursive: true);
    }
  }

  @override
  Future<void> enforceRetentionPolicy({required bool isPremium}) async {
    if (isPremium) {
      return;
    }
    // Free shows 48 hours of history but keeps 21 days of it, photos
    // included, so upgrading shows them again.
    const localRetention = ProofMediaFairUsePolicy.storedHistoryRetention;

    final root = await _rootDirectory();
    if (!await root.exists()) return;

    final now = DateTime.now();
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age >= localRetention) {
            await entity.delete();
          }
        } catch (_) {
          // ignore
        }
      }
    }
  }

  Future<Directory> _rootDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documentsDirectory.path, _rootFolder));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  String _contentTypeForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

class _ProofDownloadFailure {
  const _ProofDownloadFailure({required this.attempts, required this.retryAt});

  final int attempts;
  final DateTime retryAt;
}

final routineSessionProofStorageProvider = Provider<RoutineSessionProofStorage>(
  (ref) {
    final remote = ref.read(remoteProofAssetDataSourceProvider);
    final fairUseStore = ref.read(proofMediaFairUseStoreProvider);
    return LocalRoutineSessionProofStorage(
      remote: remote,
      fairUseStore: fairUseStore,
    );
  },
);
