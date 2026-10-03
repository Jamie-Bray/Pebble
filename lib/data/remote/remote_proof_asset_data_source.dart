import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteProofAssetDataSource {
  RemoteProofAssetDataSource(this._client);

  final SupabaseClient? _client;
  static const _bucket = 'routine-proofs';
  static const _retentionDays = 21;

  bool get isEnabled => _client != null;

  Future<void> uploadBytes({
    required String objectKey,
    required Uint8List bytes,
    required String contentType,
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required DateTime capturedAt,
    Duration retention = const Duration(days: _retentionDays),
  }) async {
    if (_client == null) return;
    await _reserveUsage(
      objectKey: objectKey,
      byteSize: bytes.length,
      contentType: contentType,
      ownerUserId: ownerUserId,
      entityType: entityType,
      entityId: entityId,
      capturedAt: capturedAt,
      retention: retention,
    );
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            objectKey,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } catch (error) {
      if (_looksLikeExistingObjectConflict(error)) {
        return;
      }
      await _markUsageDeleted(objectKey);
      rethrow;
    }
  }

  Future<Uint8List?> downloadBytes(String objectKey) async {
    if (_client == null) return null;
    return _client.storage.from(_bucket).download(objectKey);
  }

  Future<void> deleteObject(String objectKey) async {
    if (_client == null || objectKey.isEmpty) return;
    await _client.storage.from(_bucket).remove([objectKey]);
    await _markUsageDeleted(objectKey);
  }

  Future<void> _reserveUsage({
    required String objectKey,
    required int byteSize,
    required String contentType,
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required DateTime capturedAt,
    required Duration retention,
  }) async {
    final now = DateTime.now().toUtc();
    await _client!.from('proof_asset_usage').upsert({
      'owner_user_id': ownerUserId,
      'entity_type': entityType,
      'entity_id': entityId,
      'object_key': objectKey,
      'byte_size': byteSize,
      'content_type': contentType,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'expires_at': now.add(retention).toIso8601String(),
      'deleted_at': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, onConflict: 'object_key');
  }

  Future<void> _markUsageDeleted(String objectKey) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client!
        .from('proof_asset_usage')
        .update({'deleted_at': now, 'updated_at': now})
        .eq('object_key', objectKey);
  }

  /// Storage answers a missing object with HTTP 400 and a `not_found` body
  /// (sometimes 404), so callers can treat it as permanent instead of
  /// retrying a download that can never succeed.
  static bool isObjectNotFound(Object error) {
    if (error is StorageException) {
      if (error.statusCode == '404' || error.error == 'not_found') {
        return true;
      }
    }
    final message = error.toString().toLowerCase();
    return message.contains('object not found') ||
        message.contains('not_found');
  }

  bool _looksLikeExistingObjectConflict(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('409') ||
        message.contains('already exists') ||
        message.contains('duplicate');
  }
}

final remoteProofAssetDataSourceProvider = Provider<RemoteProofAssetDataSource>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return RemoteProofAssetDataSource(client);
  },
);
