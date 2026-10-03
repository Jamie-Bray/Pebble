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

  /// The account whose proofs can be downloaded right now, or null when
  /// signed out. Storage RLS only serves `users/<this id>/...` objects.
  String? get signedInUserId => _client?.auth.currentUser?.id;

  Future<void> uploadBytes({
    required String objectKey,
    required Uint8List bytes,
    required String contentType,
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required DateTime capturedAt,
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
    // Signed out (including after account deletion) nothing is readable, so
    // never spend a request that can only come back "not found".
    if (_client == null || _client.auth.currentSession == null) return null;
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
      'expires_at': now
          .add(const Duration(days: _retentionDays))
          .toIso8601String(),
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

/// Supabase Storage reports a missing (or RLS-hidden) object as
/// `{"statusCode": "404", "error": "not_found", "message": "Object not found"}`,
/// sometimes behind an HTTP 400. Retrying those can never succeed.
bool isMissingProofObjectError(Object error) {
  if (error is StorageException) {
    if (error.statusCode == '404' || error.error == 'not_found') return true;
    return error.message.toLowerCase().contains('not found');
  }
  return false;
}
