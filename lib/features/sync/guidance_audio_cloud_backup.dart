import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/remote/remote_proof_asset_data_source.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/data/fair_use_policy.dart';

class GuidanceAudioUploadResult {
  const GuidanceAudioUploadResult({this.uploadedKeys = const {}, this.failure});

  /// Remote object keys of clips uploaded in this pass, by clip file name.
  final Map<String, String> uploadedKeys;

  /// The last upload error, if any clip could not be backed up.
  final Object? failure;
}

/// Backs up step voice prompts to the private `routine-proofs` bucket and
/// brings them back on a phone that only has the routine metadata.
///
/// Clips live under `users/<uid>/guidance_audio/<file name>`, the prefix the
/// storage policies already scope to the signed-in user. The local file name
/// is a UUID, so the key is stable per clip and re-uploading it is a no-op.
class GuidanceAudioCloudBackup {
  GuidanceAudioCloudBackup({
    required RemoteProofAssetDataSource remote,
    required GuidanceAudioStorage storage,
    required ProofMediaFairUseStore Function() fairUseStore,
    required SharedPreferences Function() prefs,
    DateTime Function()? now,
  }) : _remote = remote,
       _storage = storage,
       _fairUseStore = fairUseStore,
       _prefs = prefs,
       _now = now ?? DateTime.now;

  static const entityType = 'guidance_audio';

  /// Clips are kept for as long as a routine uses them and are removed
  /// explicitly when replaced or deleted, unlike 21-day proof photos.
  static const remoteRetention = Duration(days: 3650);

  /// Wait before retrying a download that failed for a transient reason.
  static const transientRetryDelay = Duration(minutes: 15);

  static const _missingKeysPrefKey =
      'pebble.guidance_audio.missing_remote_keys';
  static const _maxMissingKeys = 500;

  final RemoteProofAssetDataSource _remote;
  final GuidanceAudioStorage _storage;
  // Resolved on first use: neither is needed until a clip actually moves.
  final ProofMediaFairUseStore Function() _fairUseStore;
  final SharedPreferences Function() _prefs;
  final DateTime Function() _now;
  final Map<String, DateTime> _retryNotBefore = {};

  bool get isEnabled => _remote.isEnabled;

  static String objectKeyFor({
    required String ownerUserId,
    required String localPath,
  }) => 'users/$ownerUserId/$entityType/${p.basename(localPath)}';

  static bool isOwnedBy(String objectKey, String ownerUserId) =>
      ownerUserId.isNotEmpty && objectKey.startsWith('users/$ownerUserId/');

  /// Every voice prompt referenced by a routine's or draft's `stepsJson`.
  /// Malformed entries are skipped rather than failing the whole routine.
  static List<StepGuidanceAudio> clipsIn(String stepsJson) {
    final clips = <StepGuidanceAudio>[];
    for (final audio in _audioMaps(stepsJson)) {
      try {
        final clip = StepGuidanceAudio.fromJson(audio);
        if (clip.localPath.isNotEmpty) {
          clips.add(clip);
        }
      } catch (_) {}
    }
    return clips;
  }

  /// Raw `localPath` of every voice prompt in [stepsJson], read without
  /// full parsing so a damaged entry still protects its file.
  static Set<String> localPathsIn(String stepsJson) {
    return {
      for (final audio in _audioMaps(stepsJson))
        if (audio['localPath']?.toString() case final path?
            when path.isNotEmpty)
          path,
    };
  }

  /// Remote keys of the clips in [stepsJson] that have been backed up, by
  /// clip file name.
  static Map<String, String> remoteKeysByFileName(String stepsJson) {
    return {
      for (final clip in clipsIn(stepsJson))
        if (clip.remoteObjectKey case final key? when key.isNotEmpty)
          p.basename(clip.localPath): key,
    };
  }

  /// Writes [keysByFileName] into the matching clips of [stepsJson], leaving
  /// everything else in the JSON untouched.
  static String applyRemoteKeys(
    String stepsJson,
    Map<String, String> keysByFileName,
  ) {
    if (keysByFileName.isEmpty) return stepsJson;
    final Object? decoded;
    try {
      decoded = jsonDecode(stepsJson);
    } catch (_) {
      return stepsJson;
    }
    if (decoded is! List) return stepsJson;
    var changed = false;
    for (final item in decoded) {
      if (item is! Map) continue;
      final audio = item['guidanceAudio'];
      if (audio is! Map) continue;
      final localPath = audio['localPath']?.toString();
      if (localPath == null || localPath.isEmpty) continue;
      final key = keysByFileName[p.basename(localPath)];
      if (key == null || audio['remoteObjectKey'] == key) continue;
      audio['remoteObjectKey'] = key;
      changed = true;
    }
    return changed ? jsonEncode(decoded) : stepsJson;
  }

  /// Whether [stepsJson] has a clip on this phone that has no backup for
  /// [ownerUserId] yet.
  Future<bool> needsUpload({
    required String stepsJson,
    required String ownerUserId,
  }) async {
    if (!isEnabled) return false;
    for (final clip in clipsIn(stepsJson)) {
      if (_needsUpload(clip, ownerUserId) && await _localFile(clip) != null) {
        return true;
      }
    }
    return false;
  }

  /// Uploads each clip in [stepsJson] that has no backup yet. Never throws:
  /// a failed clip is reported in [GuidanceAudioUploadResult.failure] so the
  /// caller decides whether to retry.
  Future<GuidanceAudioUploadResult> uploadPending({
    required String stepsJson,
    required String ownerUserId,
    required String entityId,
  }) async {
    if (!isEnabled) return const GuidanceAudioUploadResult();
    final uploaded = <String, String>{};
    Object? failure;
    for (final clip in clipsIn(stepsJson)) {
      if (!_needsUpload(clip, ownerUserId)) continue;
      final fileName = p.basename(clip.localPath);
      if (uploaded.containsKey(fileName)) continue;
      final file = await _localFile(clip);
      // A clip missing on this phone has nothing to back up; leave it as is.
      if (file == null) continue;
      final objectKey = objectKeyFor(
        ownerUserId: ownerUserId,
        localPath: clip.localPath,
      );
      try {
        final bytes = await file.readAsBytes();
        await _remote.uploadBytes(
          objectKey: objectKey,
          bytes: bytes,
          contentType: clip.mimeType ?? GuidanceAudioStorage.defaultMimeType,
          ownerUserId: ownerUserId,
          entityType: entityType,
          entityId: entityId,
          capturedAt: _now(),
          retention: remoteRetention,
        );
        // Voice prompts are capped at 10 seconds, so they never wait on the
        // local photo allowance. The server still counts their usage rows
        // toward the rolling upload quota, so record them to keep the local
        // counters in step with it.
        await _fairUseStore().recordProofUpload(byteCount: bytes.length);
        uploaded[fileName] = objectKey;
      } catch (error) {
        developer.log(
          'Voice prompt upload failed for $objectKey: $error',
          name: 'GuidanceAudioCloudBackup',
        );
        failure = error;
      }
    }
    return GuidanceAudioUploadResult(uploadedKeys: uploaded, failure: failure);
  }

  /// Downloads backed-up clips that are missing on this phone into the voice
  /// prompt folder, under the file name the steps already reference. Never
  /// throws. A clip the server no longer has is remembered and never asked
  /// for again; other failures wait [transientRetryDelay] before retrying.
  Future<int> restoreMissing({
    required Iterable<String> stepsJsons,
    required String ownerUserId,
  }) async {
    if (!isEnabled) return 0;
    final knownMissing = _missingKeys();
    final seen = <String>{};
    var restored = 0;
    for (final stepsJson in stepsJsons) {
      for (final clip in clipsIn(stepsJson)) {
        final objectKey = clip.remoteObjectKey;
        if (objectKey == null || !isOwnedBy(objectKey, ownerUserId)) continue;
        if (!seen.add(objectKey) || knownMissing.contains(objectKey)) continue;
        final notBefore = _retryNotBefore[objectKey];
        if (notBefore != null && _now().isBefore(notBefore)) continue;

        File? partial;
        try {
          final target = await _storage.resolveStoredPath(
            p.basename(clip.localPath),
          );
          if (target.isEmpty || await File(target).exists()) continue;
          final bytes = await _remote.downloadBytes(objectKey);
          if (bytes == null) continue;
          // Write beside the target and rename, so an interrupted download
          // never leaves a truncated clip that looks restored.
          partial = File('$target.part');
          await partial.parent.create(recursive: true);
          await partial.writeAsBytes(bytes, flush: true);
          await partial.rename(target);
          partial = null;
          _retryNotBefore.remove(objectKey);
          restored += 1;
        } catch (error) {
          if (RemoteProofAssetDataSource.isObjectNotFound(error)) {
            knownMissing.add(objectKey);
            await _saveMissingKeys(knownMissing);
          } else {
            _retryNotBefore[objectKey] = _now().add(transientRetryDelay);
          }
          developer.log(
            'Voice prompt restore skipped for $objectKey: $error',
            name: 'GuidanceAudioCloudBackup',
          );
        } finally {
          if (partial != null) {
            try {
              await partial.delete();
            } catch (_) {}
          }
        }
      }
    }
    return restored;
  }

  /// Best-effort: a clip left behind is removed with the account, so a
  /// failure here must never block local edits or the outbox.
  Future<void> deleteRemote(String objectKey) async {
    if (!isEnabled || objectKey.isEmpty) return;
    try {
      await _remote.deleteObject(objectKey);
    } catch (error) {
      developer.log(
        'Best-effort voice prompt delete failed for $objectKey: $error',
        name: 'GuidanceAudioCloudBackup',
      );
    }
  }

  bool _needsUpload(StepGuidanceAudio clip, String ownerUserId) {
    final key = clip.remoteObjectKey;
    return key == null || !isOwnedBy(key, ownerUserId);
  }

  Future<File?> _localFile(StepGuidanceAudio clip) async {
    final path = await _storage.resolveStoredPath(clip.localPath);
    if (path.isEmpty) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  Set<String> _missingKeys() {
    try {
      return {...?_prefs().getStringList(_missingKeysPrefKey)};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveMissingKeys(Set<String> keys) async {
    final list = keys.toList();
    final bounded = list.length > _maxMissingKeys
        ? list.sublist(list.length - _maxMissingKeys)
        : list;
    try {
      await _prefs().setStringList(_missingKeysPrefKey, bounded);
    } catch (_) {
      // Still skipped for the rest of this pass; worst case one more request
      // after the next launch.
    }
  }

  static Iterable<Map<String, dynamic>> _audioMaps(String stepsJson) sync* {
    if (stepsJson.isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(stepsJson);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is! Map) continue;
      final audio = item['guidanceAudio'];
      if (audio is Map) {
        yield Map<String, dynamic>.from(audio);
      }
    }
  }
}

final guidanceAudioCloudBackupProvider = Provider<GuidanceAudioCloudBackup>((
  ref,
) {
  return GuidanceAudioCloudBackup(
    remote: ref.read(remoteProofAssetDataSourceProvider),
    storage: ref.read(guidanceAudioStorageProvider),
    fairUseStore: () => ref.read(proofMediaFairUseStoreProvider),
    prefs: () => ref.read(sharedPreferencesProvider),
  );
});
