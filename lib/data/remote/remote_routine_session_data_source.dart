import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteRoutineSessionRecord {
  final String id;
  final String ownerUserId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  const RemoteRoutineSessionRecord({
    required this.id,
    required this.ownerUserId,
    required this.payload,
    required this.updatedAt,
  });

  factory RemoteRoutineSessionRecord.fromJson(Map<String, dynamic> json) {
    return RemoteRoutineSessionRecord(
      id: json['id'].toString(),
      ownerUserId: json['owner_user_id'].toString(),
      payload: _payloadFromJsonb(json['payload_json']),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

Map<String, dynamic> _payloadFromJsonb(dynamic value) {
  if (value is String) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

class RemoteRoutineSessionDataSource {
  RemoteRoutineSessionDataSource(this._client);

  final SupabaseClient? _client;

  Future<List<RemoteRoutineSessionRecord>> fetchAll(String ownerUserId) async {
    if (_client == null) return const [];
    final response = await _client
        .from('routine_sessions')
        .select()
        .eq('owner_user_id', ownerUserId)
        .order('updated_at');
    return (response as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(RemoteRoutineSessionRecord.fromJson)
        .toList();
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    if (_client == null) return;
    await _client.from('routine_sessions').upsert(payload);
  }

  Future<void> delete(String id) async {
    if (_client == null) return;
    await _client.from('routine_sessions').delete().eq('id', id);
  }
}

final remoteRoutineSessionDataSourceProvider =
    Provider<RemoteRoutineSessionDataSource>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return RemoteRoutineSessionDataSource(client);
    });
