import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteRoutineRecord {
  final String id;
  final String ownerUserId;
  final String title;
  final String stepsJson;
  final String? iconKey;
  final int? colorHex;
  final bool isPinned;
  final DateTime? pinnedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RemoteRoutineRecord({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.stepsJson,
    required this.iconKey,
    required this.colorHex,
    required this.isPinned,
    required this.pinnedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteRoutineRecord.fromJson(Map<String, dynamic> json) {
    return RemoteRoutineRecord(
      id: json['id'].toString(),
      ownerUserId: json['owner_user_id'].toString(),
      title: json['title']?.toString() ?? 'Routine',
      stepsJson: _jsonbToString(json['steps_json'], fallback: '[]'),
      iconKey: json['icon_key']?.toString(),
      colorHex: (json['color_hex'] as num?)?.toInt(),
      isPinned: json['is_pinned'] == true,
      pinnedAt: DateTime.tryParse(json['pinned_at']?.toString() ?? ''),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

String _jsonbToString(dynamic value, {required String fallback}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}

class RemoteRoutineDataSource {
  RemoteRoutineDataSource(this._client);

  final SupabaseClient? _client;

  bool get isEnabled => _client != null;

  Future<List<RemoteRoutineRecord>> fetchAll(String ownerUserId) async {
    if (_client == null) return const [];
    final response = await _client
        .from('routines')
        .select()
        .eq('owner_user_id', ownerUserId)
        .order('updated_at');
    return (response as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(RemoteRoutineRecord.fromJson)
        .toList();
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    if (_client == null) return;
    await _client.from('routines').upsert(payload);
  }

  Future<void> delete(String id) async {
    if (_client == null) return;
    await _client.from('routines').delete().eq('id', id);
  }
}

final remoteRoutineDataSourceProvider = Provider<RemoteRoutineDataSource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return RemoteRoutineDataSource(client);
});
