import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// One step of an AI draft.
@immutable
class RoutineAiStep {
  const RoutineAiStep({
    required this.label,
    required this.photo,
    this.detail = '',
  });

  final String label;
  final bool photo;

  /// A sentence for the step's description in the editor. Not shown in the
  /// AI sheet.
  final String detail;

  RoutineAiStep copyWith({String? label, bool? photo}) => RoutineAiStep(
    label: label ?? this.label,
    photo: photo ?? this.photo,
    detail: detail,
  );
}

/// A routine drafted by AI. Nothing is saved until the person taps Save in
/// the editor.
@immutable
class RoutineAiDraft {
  const RoutineAiDraft({required this.name, required this.steps});

  final String name;
  final List<RoutineAiStep> steps;

  static RoutineAiDraft? fromJson(Object? data) {
    if (data is! Map) return null;
    final name = data['name'];
    final steps = data['steps'];
    if (name is! String || name.trim().isEmpty || steps is! List) return null;
    final parsed = <RoutineAiStep>[
      for (final step in steps)
        if (step is Map &&
            step['label'] is String &&
            (step['label'] as String).trim().isNotEmpty)
          RoutineAiStep(
            label: (step['label'] as String).trim(),
            photo: step['photo'] == true,
            detail: step['detail'] is String
                ? (step['detail'] as String).trim()
                : '',
          ),
    ];
    if (parsed.isEmpty) return null;
    return RoutineAiDraft(name: name.trim(), steps: parsed);
  }
}

@immutable
class RoutineAiQuestion {
  const RoutineAiQuestion({required this.question, required this.options});

  final String question;
  final List<String> options;
}

@immutable
class RoutineAiAnswer {
  const RoutineAiAnswer({required this.question, required this.answer});

  final String question;
  final String answer;

  Map<String, String> toJson() => {'question': question, 'answer': answer};
}

/// Why there is no draft: the server's `reason` (featureOff, freeUsed,
/// dailyLimit, busy, tooManyTries, couldNotBuild) or `offline`.
@immutable
class RoutineAiReply {
  const RoutineAiReply.draft(RoutineAiDraft this.draft)
    : questions = const [],
      reason = null;
  const RoutineAiReply.questions(this.questions) : draft = null, reason = null;
  const RoutineAiReply.refused(String this.reason)
    : draft = null,
      questions = const [];

  final RoutineAiDraft? draft;
  final List<RoutineAiQuestion> questions;
  final String? reason;
}

@immutable
class RoutineAiStatus {
  const RoutineAiStatus({
    required this.enabled,
    this.premium = false,
    this.freeBuildUsed = false,
  });

  static const off = RoutineAiStatus(enabled: false);

  final bool enabled;
  final bool premium;
  final bool freeBuildUsed;

  /// Whether a build would be allowed now (Premium has a daily cap, which
  /// only the server knows).
  bool get canBuild => enabled && (premium || !freeBuildUsed);
}

/// Talks to the `build-routine` Edge Function. The server decides whether
/// the feature is on, the free build and the Personal Premium allowance.
abstract class RoutineAiClient {
  Future<RoutineAiStatus> status();

  Future<RoutineAiReply> build({
    required String buildKey,
    required String description,
    List<RoutineAiAnswer> answers = const [],
    bool askQuestions = false,
  });
}

class SupabaseRoutineAiClient implements RoutineAiClient {
  SupabaseRoutineAiClient(this._client, this._prefs);

  static const _function = 'build-routine';
  static const installIdKey = 'pebble.install_id';

  final SupabaseClient? _client;
  final SharedPreferences? _prefs;

  /// A random ID for this install, made once. It is how the free build is
  /// counted before sign-in; it says nothing about the person.
  String? get _installId {
    final prefs = _prefs;
    if (prefs == null) return null;
    final existing = prefs.getString(installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    unawaited(prefs.setString(installIdKey, created));
    return created;
  }

  @override
  Future<RoutineAiStatus> status() async {
    final data = await _post({'action': 'status'});
    if (data == null || data['enabled'] != true) return RoutineAiStatus.off;
    return RoutineAiStatus(
      enabled: true,
      premium: data['premium'] == true,
      freeBuildUsed: data['freeBuildUsed'] == true,
    );
  }

  @override
  Future<RoutineAiReply> build({
    required String buildKey,
    required String description,
    List<RoutineAiAnswer> answers = const [],
    bool askQuestions = false,
  }) async {
    final data = await _post({
      'action': askQuestions ? 'questions' : 'draft',
      'buildKey': buildKey,
      'description': description,
      if (answers.isNotEmpty)
        'answers': [for (final answer in answers) answer.toJson()],
    }, timeout: const Duration(seconds: 30));
    if (data == null) return const RoutineAiReply.refused('offline');
    if (data['ok'] != true) {
      final reason = data['reason'];
      return RoutineAiReply.refused(
        reason is String ? reason : 'couldNotBuild',
      );
    }
    if (askQuestions) {
      final raw = data['questions'];
      final questions = <RoutineAiQuestion>[
        if (raw is List)
          for (final item in raw)
            if (item is Map &&
                item['question'] is String &&
                item['options'] is List)
              RoutineAiQuestion(
                question: item['question'] as String,
                options: [
                  for (final option in item['options'] as List)
                    if (option is String) option,
                ],
              ),
      ];
      return questions.isEmpty
          ? const RoutineAiReply.refused('couldNotBuild')
          : RoutineAiReply.questions(questions);
    }
    final draft = RoutineAiDraft.fromJson(data['draft']);
    return draft == null
        ? const RoutineAiReply.refused('couldNotBuild')
        : RoutineAiReply.draft(draft);
  }

  Future<Map<String, dynamic>?> _post(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = _client;
    final installId = _installId;
    if (client == null || installId == null) return null;
    try {
      final response = await client.functions
          .invoke(_function, body: {...body, 'installId': installId})
          .timeout(timeout);
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      debugPrint('Routine AI: server answered ${error.status}');
    } catch (error) {
      // Never what was typed: outcome only.
      debugPrint('Routine AI: request failed (${error.runtimeType})');
    }
    return null;
  }
}

final routineAiClientProvider = Provider<RoutineAiClient>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return SupabaseRoutineAiClient(ref.watch(supabaseClientProvider), prefs);
});

/// Whether to offer "Build with AI", and whether the free build is still
/// there. Off until the server says otherwise.
final routineAiStatusProvider = FutureProvider<RoutineAiStatus>(
  (ref) => ref.watch(routineAiClientProvider).status(),
);
