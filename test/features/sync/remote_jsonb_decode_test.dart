import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pebble_routines/data/remote/remote_routine_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_run_data_source.dart';
import 'package:pebble_routines/data/remote/remote_routine_session_data_source.dart';

void main() {
  test('remote routine JSONB steps are restored as valid JSON', () {
    final record = RemoteRoutineRecord.fromJson({
      'id': 'routine-1',
      'owner_user_id': 'user-1',
      'title': 'Morning',
      'steps_json': [
        {'label': 'Kettle on'},
      ],
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime(2026, 1, 2).toIso8601String(),
    });

    final decoded = jsonDecode(record.stepsJson) as List<dynamic>;

    expect(decoded.single, containsPair('label', 'Kettle on'));
  });

  test('remote run JSONB completion data is restored as valid JSON', () {
    final record = RemoteRoutineRunRecord.fromJson({
      'id': 'run-1',
      'owner_user_id': 'user-1',
      'routine_title': 'Morning',
      'finished_at': DateTime(2026, 1, 2).toIso8601String(),
      'step_completion_data': {
        'steps': [
          {'label': 'Kettle on', 'photos': const []},
        ],
      },
      'updated_at': DateTime(2026, 1, 2).toIso8601String(),
    });

    final decoded =
        jsonDecode(record.stepCompletionData!) as Map<String, dynamic>;

    expect(decoded['steps'], isA<List<dynamic>>());
  });

  test(
    'remote session JSONB payload accepts decoded maps and JSON strings',
    () {
      final mapRecord = RemoteRoutineSessionRecord.fromJson({
        'id': 'session-1',
        'owner_user_id': 'user-1',
        'payload_json': {'sessionId': 'session-1'},
        'updated_at': DateTime(2026, 1, 2).toIso8601String(),
      });
      final stringRecord = RemoteRoutineSessionRecord.fromJson({
        'id': 'session-2',
        'owner_user_id': 'user-1',
        'payload_json': '{"sessionId":"session-2"}',
        'updated_at': DateTime(2026, 1, 2).toIso8601String(),
      });

      expect(mapRecord.payload['sessionId'], 'session-1');
      expect(stringRecord.payload['sessionId'], 'session-2');
    },
  );
}
