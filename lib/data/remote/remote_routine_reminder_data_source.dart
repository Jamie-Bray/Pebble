import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

class RemoteRoutineReminderRecord {
  final String id;
  final String ownerUserId;
  final String routineCloudId;
  final int dayOfWeek;
  final String time;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RemoteRoutineReminderRecord({
    required this.id,
    required this.ownerUserId,
    required this.routineCloudId,
    required this.dayOfWeek,
    required this.time,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteRoutineReminderRecord.fromJson(Map<String, dynamic> json) {
    return RemoteRoutineReminderRecord(
      id: json['id'].toString(),
      ownerUserId: json['owner_user_id'].toString(),
      routineCloudId: json['routine_id'].toString(),
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      time: json['time']?.toString() ?? '9:00 AM',
      isEnabled: json['is_enabled'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class RemoteRoutineReminderDataSource {
  RemoteRoutineReminderDataSource(this._client);

  final SupabaseClient? _client;

  Future<List<RemoteRoutineReminderRecord>> fetchAll(String ownerUserId) async {
    if (_client == null) return const [];
    final response = await _client
        .from('routine_reminders')
        .select()
        .eq('owner_user_id', ownerUserId)
        .order('updated_at');
    return (response as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(RemoteRoutineReminderRecord.fromJson)
        .toList();
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    if (_client == null) return;
    await _client.from('routine_reminders').upsert(payload);
  }

  Future<void> delete(String id) async {
    if (_client == null) return;
    await _client.from('routine_reminders').delete().eq('id', id);
  }
}

final remoteRoutineReminderDataSourceProvider =
    Provider<RemoteRoutineReminderDataSource>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return RemoteRoutineReminderDataSource(client);
    });
