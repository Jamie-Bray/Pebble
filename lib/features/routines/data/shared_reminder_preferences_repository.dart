import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';

enum SharedReminderContactStatus {
  pending,
  accepted,
  declined,
  blocked,
  disabled,
}

class SharedReminderContact {
  const SharedReminderContact({
    required this.id,
    required this.routineKey,
    required this.recipientEmail,
    required this.status,
    required this.notifyWhenFinished,
    required this.includeRoutineName,
    required this.includeStepCount,
    required this.updatedAt,
  });

  final String id;
  final String routineKey;
  final String recipientEmail;
  final SharedReminderContactStatus status;
  final bool notifyWhenFinished;
  final bool includeRoutineName;
  final bool includeStepCount;
  final DateTime updatedAt;

  bool get canSendCompletionEmail =>
      status == SharedReminderContactStatus.accepted && notifyWhenFinished;

  SharedReminderContact copyWith({
    SharedReminderContactStatus? status,
    bool? notifyWhenFinished,
    bool? includeRoutineName,
    bool? includeStepCount,
    DateTime? updatedAt,
  }) {
    return SharedReminderContact(
      id: id,
      routineKey: routineKey,
      recipientEmail: recipientEmail,
      status: status ?? this.status,
      notifyWhenFinished: notifyWhenFinished ?? this.notifyWhenFinished,
      includeRoutineName: includeRoutineName ?? this.includeRoutineName,
      includeStepCount: includeStepCount ?? this.includeStepCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SharedReminderContact.fromJson(Map<String, dynamic> json) {
    return SharedReminderContact(
      id: json['id']?.toString() ?? '',
      routineKey: json['routineKey']?.toString() ?? '',
      recipientEmail: json['recipientEmail']?.toString() ?? '',
      status: _contactStatusFromString(json['status']?.toString()),
      notifyWhenFinished: json['notifyWhenFinished'] == true,
      includeRoutineName: json['includeRoutineName'] != false,
      includeStepCount: json['includeStepCount'] != false,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SharedReminderRepositoryException implements Exception {
  SharedReminderRepositoryException(this.message, {this.code, this.status});

  final String message;

  /// Machine-readable reason from the server, such as `senderDailyLimit`.
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

/// Outcome of trying to send a completion email after a run.
///
/// [reason] is one of the server's reasons (`noAcceptedContact`,
/// `noActiveEntitlement`, `rateLimited`, `duplicateRun`, `alreadySent`) or,
/// from the app, `offline` / `failed` when the email could not be sent.
class SharedReminderCompletionResult {
  const SharedReminderCompletionResult({
    required this.sent,
    this.recipientEmail,
    this.reason,
  });

  final bool sent;
  final String? recipientEmail;
  final String? reason;

  factory SharedReminderCompletionResult.fromJson(Map<String, dynamic> json) {
    return SharedReminderCompletionResult(
      sent: json['sent'] == true,
      recipientEmail: json['recipientEmail']?.toString(),
      reason: json['alreadySent'] == true
          ? 'alreadySent'
          : json['reason']?.toString(),
    );
  }

  /// A short line for the completion screen, or null when there is nothing
  /// worth saying (no contact set up, emails turned off, or already sent).
  String? get completionScreenNote {
    if (sent) {
      if (reason == 'alreadySent') return null;
      final to = recipientEmail?.trim();
      return to == null || to.isEmpty
          ? 'Completion email sent.'
          : 'Completion email sent to $to.';
    }
    return switch (reason) {
      'rateLimited' =>
        'Completion email not sent. This contact has had several recently.',
      'offline' => "Completion email not sent because there's no connection.",
      'failed' => "Completion email couldn't be sent this time.",
      _ => null,
    };
  }
}

class SharedReminderPreferencesRepository {
  SharedReminderPreferencesRepository(this._client);

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  String routineKeyFor({required int routineId, String? routineCloudId}) {
    final cloudId = routineCloudId?.trim();
    if (cloudId != null && cloudId.isNotEmpty) {
      return 'cloud:$cloudId';
    }
    return 'local:$routineId';
  }

  Future<SharedReminderContact?> getForRoutine({
    required int routineId,
    String? routineCloudId,
  }) async {
    final client = await _clientWithSession();
    final response = await _invoke(
      client,
      'request-shared-alert-contact',
      method: HttpMethod.get,
      queryParameters: {
        'routineKey': routineKeyFor(
          routineId: routineId,
          routineCloudId: routineCloudId,
        ),
      },
      timeoutMessage: "Couldn't check the contact. Try again.",
    );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedReminderContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    return null;
  }

  Future<SharedReminderContact> requestContact({
    required int routineId,
    required String recipientEmail,
    String? routineCloudId,
    bool resend = false,
    bool includeRoutineName = true,
    bool includeStepCount = true,
  }) async {
    final client = await _clientWithSession();
    final response = await _invoke(
      client,
      'request-shared-alert-contact',
      body: {
        'routineKey': routineKeyFor(
          routineId: routineId,
          routineCloudId: routineCloudId,
        ),
        'recipientEmail': recipientEmail,
        'resend': resend,
        'includeRoutineName': includeRoutineName,
        'includeStepCount': includeStepCount,
      },
      timeout: const Duration(seconds: 20),
      timeoutMessage:
          'The invite timed out. Check your connection and try again.',
    );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedReminderContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    throw SharedReminderRepositoryException(
      "Couldn't send the invite. Try again.",
    );
  }

  Future<SharedReminderContact> setNotifyWhenFinished({
    required SharedReminderContact contact,
    required bool enabled,
  }) async {
    final client = await _clientWithSession();
    final response = await _invoke(
      client,
      'request-shared-alert-contact',
      method: HttpMethod.patch,
      body: {'contactId': contact.id, 'notifyWhenFinished': enabled},
      timeoutMessage: "Couldn't update completion emails. Try again.",
    );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedReminderContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    return contact.copyWith(
      notifyWhenFinished: enabled,
      updatedAt: DateTime.now(),
    );
  }

  /// Chooses what completion emails show. Allowed without Premium, because
  /// it only ever shares less or the same.
  Future<SharedReminderContact> setSharingOptions({
    required SharedReminderContact contact,
    bool? includeRoutineName,
    bool? includeStepCount,
  }) async {
    final client = await _clientWithSession();
    final response = await _invoke(
      client,
      'request-shared-alert-contact',
      method: HttpMethod.patch,
      body: {
        'contactId': contact.id,
        if (includeRoutineName != null)
          'includeRoutineName': includeRoutineName,
        if (includeStepCount != null) 'includeStepCount': includeStepCount,
      },
      timeoutMessage: "Couldn't update completion emails. Try again.",
    );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedReminderContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    return contact.copyWith(
      includeRoutineName: includeRoutineName,
      includeStepCount: includeStepCount,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> removeContact({required SharedReminderContact contact}) async {
    final client = await _clientWithSession();
    final response = await _invoke(
      client,
      'request-shared-alert-contact',
      method: HttpMethod.delete,
      body: {'contactId': contact.id},
      timeoutMessage: "Couldn't remove this contact. Try again.",
    );
    _throwIfFailed(response);
  }

  /// Emails the routine's accepted contact, if there is one. Never throws: a
  /// completion email must not make a finished routine look unfinished.
  ///
  /// A failed send is retried once after [retryDelay]. The server emails each
  /// run at most once, so a retry can never produce a duplicate email.
  Future<SharedReminderCompletionResult> sendCompletionReminder({
    required int routineId,
    required String routineTitle,
    required String runId,
    required String sessionId,
    required DateTime completedAt,
    required int completedSteps,
    required int totalSteps,
    String? routineCloudId,
    List<String> descriptions = const [],
    List<CompletionEmailStep> steps = const [],
    Duration retryDelay = const Duration(seconds: 4),
  }) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      return const SharedReminderCompletionResult(sent: false);
    }
    final body = completionRequestBody(
      routineKey: routineKeyFor(
        routineId: routineId,
        routineCloudId: routineCloudId,
      ),
      routineTitle: routineTitle,
      runId: runId,
      sessionId: sessionId,
      completedAt: completedAt,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      descriptions: descriptions,
      steps: steps,
    );
    var result = await _sendCompletionOnce(client, body);
    if (!result.sent &&
        (result.reason == 'failed' || result.reason == 'offline')) {
      await Future<void>.delayed(retryDelay);
      result = await _sendCompletionOnce(client, body);
    }
    return result;
  }

  Future<SharedReminderCompletionResult> _sendCompletionOnce(
    SupabaseClient client,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _invoke(
        client,
        'send-routine-completion-alert',
        body: body,
        timeout: const Duration(seconds: 25),
        timeoutMessage: 'timeout',
      );
      final data = response.data;
      if (data is Map) {
        return SharedReminderCompletionResult.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return const SharedReminderCompletionResult(sent: false);
    } on SharedReminderRepositoryException catch (error) {
      final offline = error.code == 'network' || error.code == 'timeout';
      return SharedReminderCompletionResult(
        sent: false,
        reason: offline ? 'offline' : 'failed',
      );
    }
  }

  /// Calls an Edge Function and turns its non-2xx responses (which
  /// supabase_flutter throws as [FunctionException]) into
  /// [SharedReminderRepositoryException] carrying the server's own message.
  Future<FunctionResponse> _invoke(
    SupabaseClient client,
    String function, {
    required String timeoutMessage,
    Duration timeout = const Duration(seconds: 10),
    HttpMethod method = HttpMethod.post,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    try {
      return await client.functions
          .invoke(
            function,
            method: method,
            body: body,
            queryParameters: queryParameters,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw SharedReminderRepositoryException(timeoutMessage, code: 'timeout');
    } on FunctionException catch (error) {
      throw sharedReminderExceptionFromFunctionError(error);
    } on SharedReminderRepositoryException {
      rethrow;
    } catch (_) {
      throw SharedReminderRepositoryException(
        'No connection. Check your network and try again.',
        code: 'network',
      );
    }
  }

  Future<SupabaseClient> _clientWithSession() async {
    final client = _client;
    if (client == null) {
      throw SharedReminderRepositoryException(
        "Completion emails aren't available in this version of Pebble.",
      );
    }
    await _ensureSession(client);
    return client;
  }

  Future<void> _ensureSession(SupabaseClient client) async {
    if (client.auth.currentSession != null) return;
    throw SharedReminderRepositoryException(
      'Sign in to manage who gets notified.',
    );
  }

  void _throwIfFailed(FunctionResponse response) {
    final status = response.status;
    if (status >= 200 && status < 300) return;
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw SharedReminderRepositoryException(data['error'].toString());
    }
    throw SharedReminderRepositoryException(
      "Completion emails aren't available right now. Try again later.",
    );
  }
}

/// Request body for `send-routine-completion-alert`. The time is sent in UTC
/// with the device's offset, so the email shows the sender's local time.
///
/// [descriptions] are AI photo descriptions, passed only when the person
/// chose to add them to this routine's email. Photos are never sent.
///
/// [steps] are listed in the email with the time each was checked, but only
/// when the contact's "Steps" setting is on (the server decides). The server
/// never stores them.
Map<String, dynamic> completionRequestBody({
  required String routineKey,
  required String routineTitle,
  required String runId,
  required String sessionId,
  required DateTime completedAt,
  required int completedSteps,
  required int totalSteps,
  List<String> descriptions = const [],
  List<CompletionEmailStep> steps = const [],
}) {
  return {
    if (descriptions.isNotEmpty) 'descriptions': descriptions,
    if (steps.isNotEmpty) 'steps': [for (final step in steps) step.toJson()],
    'routineKey': routineKey,
    'routineTitle': routineTitle,
    'runId': runId,
    'sessionId': sessionId,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'utcOffsetMinutes': completedAt.toLocal().timeZoneOffset.inMinutes,
    'completedSteps': completedSteps,
    'totalSteps': totalSteps,
  };
}

/// One step of a finished run, as the completion email lists it.
class CompletionEmailStep {
  const CompletionEmailStep({
    required this.title,
    required this.skipped,
    this.completedAt,
    this.note,
  });

  final String title;
  final bool skipped;
  final DateTime? completedAt;

  /// The note written on the step, shown under it in the email.
  final String? note;

  Map<String, dynamic> toJson() => {
    'title': title,
    'status': skipped ? 'skipped' : 'done',
    if (!skipped && completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (note != null) 'note': note,
  };
}

/// The run's steps in order, for the completion email. A step that was
/// neither checked nor skipped is left out, so nothing is shown as done that
/// wasn't.
List<CompletionEmailStep> completionEmailSteps(RoutineSession session) {
  final steps = <CompletionEmailStep>[];
  for (final state in session.stepStates) {
    if (state.status == SessionStepStatus.pending) continue;
    final index = state.stepIndex;
    if (index < 0 || index >= session.routineSnapshotSteps.length) continue;
    final title = completionEmailStepTitle(
      session.routineSnapshotSteps[index],
    ).trim();
    if (title.isEmpty) continue;
    steps.add(
      CompletionEmailStep(
        title: title,
        skipped: state.status == SessionStepStatus.skipped,
        completedAt: state.completedAt,
        note: state.note,
      ),
    );
  }
  return steps;
}

/// The same title the player shows for a step.
String completionEmailStepTitle(RoutineStep step) {
  return step.maybeWhen(
    check: (label, _, _, _, _, _, _) => label,
    info: (message) => message,
    timer: (_) => 'Pause',
    orElse: () => 'Step',
  );
}

/// Maps a non-2xx Edge Function response to an exception carrying the
/// server's user-facing message, or a plain fallback when there isn't one.
SharedReminderRepositoryException sharedReminderExceptionFromFunctionError(
  FunctionException error,
) {
  final details = error.details;
  String? message;
  String? code;
  if (details is Map) {
    message = details['error']?.toString();
    code = details['code']?.toString();
  }
  return SharedReminderRepositoryException(
    message == null || message.trim().isEmpty
        ? "Completion emails aren't available right now. Try again later."
        : message.trim(),
    code: code,
    status: error.status,
  );
}

SharedReminderContactStatus _contactStatusFromString(String? value) {
  return switch (value) {
    'accepted' => SharedReminderContactStatus.accepted,
    'declined' => SharedReminderContactStatus.declined,
    'blocked' => SharedReminderContactStatus.blocked,
    'disabled' => SharedReminderContactStatus.disabled,
    _ => SharedReminderContactStatus.pending,
  };
}

final sharedReminderPreferencesRepositoryProvider =
    Provider<SharedReminderPreferencesRepository>((ref) {
      return SharedReminderPreferencesRepository(
        ref.watch(supabaseClientProvider),
      );
    });
