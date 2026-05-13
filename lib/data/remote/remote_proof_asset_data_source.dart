import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteProofAssetDataSource {
  RemoteProofAssetDataSource(this._client);

  final SupabaseClient? _client;
  static const _bucket = 'routine-proofs';

  bool get isEnabled => _client != null;

  Future<void> uploadBytes({
    required String objectKey,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (_client == null) return;
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          objectKey,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  Future<Uint8List?> downloadBytes(String objectKey) async {
    if (_client == null) return null;
    return _client.storage.from(_bucket).download(objectKey);
  }

  Future<void> deleteObject(String objectKey) async {
    if (_client == null || objectKey.isEmpty) return;
    await _client.storage.from(_bucket).remove([objectKey]);
  }
}

final remoteProofAssetDataSourceProvider = Provider<RemoteProofAssetDataSource>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return RemoteProofAssetDataSource(client);
  },
);
