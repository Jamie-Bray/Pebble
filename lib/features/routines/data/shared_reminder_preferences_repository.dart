import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

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
    DateTime? updatedAt,
  }) {
    return SharedReminderContact(
      id: id,
      routineKey: routineKey,
      recipientEmail: recipientEmail,
      status: status ?? this.status,
      notifyWhenFinished: notifyWhenFinished ?? this.notifyWhenFinished,
      includeRoutineName: includeRoutineName,
      includeStepCount: includeStepCount,
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
  SharedReminderRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
      reason: json['reason']?.toString(),
    );
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
    final response = await client.functions
        .invoke(
          'request-shared-alert-contact',
          method: HttpMethod.get,
          queryParameters: {
            'routineKey': routineKeyFor(
              routineId: routineId,
              routineCloudId: routineCloudId,
            ),
          },
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw SharedReminderRepositoryException(
              'Could not check contact status. Please try again.',
            );
          },
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
  }) async {
    final client = await _clientWithSession();
    final response = await client.functions
        .invoke(
          'request-shared-alert-contact',
          body: {
            'routineKey': routineKeyFor(
              routineId: routineId,
              routineCloudId: routineCloudId,
            ),
            'recipientEmail': recipientEmail,
            'resend': resend,
            'includeRoutineName': true,
            'includeStepCount': true,
          },
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw SharedReminderRepositoryException(
              'The request timed out. Please check your internet connection.',
            );
          },
        );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedReminderContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    throw SharedReminderRepositoryException(
      'Could not create shared reminder.',
    );
  }

  Future<SharedReminderContact> setNotifyWhenFinished({
    required SharedReminderContact contact,
    required bool enabled,
  }) async {
    final client = await _clientWithSession();
    final response = await client.functions
        .invoke(
          'request-shared-alert-contact',
          method: HttpMethod.patch,
          body: {'contactId': contact.id, 'notifyWhenFinished': enabled},
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw SharedReminderRepositoryException(
              'Could not update shared reminder. Please try again.',
            );
          },
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

  Future<void> removeContact({required SharedReminderContact contact}) async {
    final client = await _clientWithSession();
    final response = await client.functions
        .invoke(
          'request-shared-alert-contact',
          method: HttpMethod.delete,
          body: {'contactId': contact.id},
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw SharedReminderRepositoryException(
              'Could not remove this contact. Please try again.',
            );
          },
        );
    _throwIfFailed(response);
  }

  Future<SharedReminderCompletionResult> sendCompletionReminder({
    required int routineId,
    required String routineTitle,
    required String runId,
    required String sessionId,
    required DateTime completedAt,
    required int completedSteps,
    required int totalSteps,
    String? routineCloudId,
  }) async {
    final client = _client;
    if (client == null) {
      return const SharedReminderCompletionResult(
        sent: false,
        reason: 'offline',
      );
    }
    await _ensureSession(client);
    final response = await client.functions.invoke(
      'send-routine-completion-alert',
      body: {
        'routineKey': routineKeyFor(
          routineId: routineId,
          routineCloudId: routineCloudId,
        ),
        'routineTitle': routineTitle,
        'runId': runId,
        'sessionId': sessionId,
        'completedAt': completedAt.toIso8601String(),
        'completedSteps': completedSteps,
        'totalSteps': totalSteps,
      },
    );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map) {
      return SharedReminderCompletionResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return const SharedReminderCompletionResult(sent: false);
  }

  Future<SupabaseClient> _clientWithSession() async {
    final client = _client;
    if (client == null) {
      throw SharedReminderRepositoryException(
        'Email setup is not available in this build.',
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
      'Shared reminders are not available right now.',
    );
  }
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
