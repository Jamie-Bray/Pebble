import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteRoutineRunRecord {
  final String id;
  final String ownerUserId;
  final String? routineId;
  final String routineTitle;
  final DateTime finishedAt;
  final String? stepCompletionData;
  final DateTime updatedAt;

  const RemoteRoutineRunRecord({
    required this.id,
    required this.ownerUserId,
    required this.routineId,
    required this.routineTitle,
    required this.finishedAt,
    required this.stepCompletionData,
    required this.updatedAt,
  });

  factory RemoteRoutineRunRecord.fromJson(Map<String, dynamic> json) {
    return RemoteRoutineRunRecord(
      id: json['id'].toString(),
      ownerUserId: json['owner_user_id'].toString(),
      routineId: json['routine_id']?.toString(),
      routineTitle: json['routine_title']?.toString() ?? 'Routine',
      finishedAt:
          DateTime.tryParse(json['finished_at']?.toString() ?? '') ??
          DateTime.now(),
      stepCompletionData: _nullableJsonbToString(json['step_completion_data']),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

String? _nullableJsonbToString(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}

class RemoteRoutineRunDataSource {
  RemoteRoutineRunDataSource(this._client);

  final SupabaseClient? _client;

  Future<List<RemoteRoutineRunRecord>> fetchAll(String ownerUserId) async {
    if (_client == null) return const [];
    final response = await _client
        .from('routine_runs')
        .select()
        .eq('owner_user_id', ownerUserId)
        .order('finished_at', ascending: false);
    return (response as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(RemoteRoutineRunRecord.fromJson)
        .toList();
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    if (_client == null) return;
    await _client.from('routine_runs').upsert(payload);
  }

  Future<void> delete(String id) async {
    if (_client == null) return;
    await _client.from('routine_runs').delete().eq('id', id);
  }
}

final remoteRoutineRunDataSourceProvider = Provider<RemoteRoutineRunDataSource>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return RemoteRoutineRunDataSource(client);
  },
);
