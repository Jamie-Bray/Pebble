import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/data/remote/supabase_client_provider.dart';

enum SharedAlertContactStatus { pending, accepted, declined, blocked, disabled }

class SharedAlertContact {
  const SharedAlertContact({
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
  final SharedAlertContactStatus status;
  final bool notifyWhenFinished;
  final bool includeRoutineName;
  final bool includeStepCount;
  final DateTime updatedAt;

  bool get canSendCompletionEmail =>
      status == SharedAlertContactStatus.accepted && notifyWhenFinished;

  SharedAlertContact copyWith({
    SharedAlertContactStatus? status,
    bool? notifyWhenFinished,
    DateTime? updatedAt,
  }) {
    return SharedAlertContact(
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

  factory SharedAlertContact.fromJson(Map<String, dynamic> json) {
    return SharedAlertContact(
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

class SharedAlertRepositoryException implements Exception {
  SharedAlertRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SharedAlertCompletionResult {
  const SharedAlertCompletionResult({
    required this.sent,
    this.recipientEmail,
    this.reason,
  });

  final bool sent;
  final String? recipientEmail;
  final String? reason;

  factory SharedAlertCompletionResult.fromJson(Map<String, dynamic> json) {
    return SharedAlertCompletionResult(
      sent: json['sent'] == true,
      recipientEmail: json['recipientEmail']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class SharedAlertPreferencesRepository {
  SharedAlertPreferencesRepository(this._client);

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  String routineKeyFor({required int routineId, String? routineCloudId}) {
    final cloudId = routineCloudId?.trim();
    if (cloudId != null && cloudId.isNotEmpty) {
      return 'cloud:$cloudId';
    }
    return 'local:$routineId';
  }

  Future<SharedAlertContact?> getForRoutine({
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
            throw SharedAlertRepositoryException(
              'Could not check trusted contact status. Please try again.',
            );
          },
        );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedAlertContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    return null;
  }

  Future<SharedAlertContact> requestContact({
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
            throw SharedAlertRepositoryException(
              'The request timed out. Please check your internet connection.',
            );
          },
        );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedAlertContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    throw SharedAlertRepositoryException('Could not create shared alert.');
  }

  Future<SharedAlertContact> setNotifyWhenFinished({
    required SharedAlertContact contact,
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
            throw SharedAlertRepositoryException(
              'Could not update shared alert. Please try again.',
            );
          },
        );
    _throwIfFailed(response);
    final data = response.data;
    if (data is Map && data['contact'] is Map) {
      return SharedAlertContact.fromJson(
        Map<String, dynamic>.from(data['contact'] as Map),
      );
    }
    return contact.copyWith(
      notifyWhenFinished: enabled,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> removeContact({required SharedAlertContact contact}) async {
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
            throw SharedAlertRepositoryException(
              'Could not remove trusted contact. Please try again.',
            );
          },
        );
    _throwIfFailed(response);
  }

  Future<SharedAlertCompletionResult> sendCompletionAlert({
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
      return const SharedAlertCompletionResult(sent: false, reason: 'offline');
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
      return SharedAlertCompletionResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return const SharedAlertCompletionResult(sent: false);
  }

  Future<SupabaseClient> _clientWithSession() async {
    final client = _client;
    if (client == null) {
      throw SharedAlertRepositoryException(
        'Email setup is not available in this build.',
      );
    }
    await _ensureSession(client);
    return client;
  }

  Future<void> _ensureSession(SupabaseClient client) async {
    if (client.auth.currentSession != null) return;
    try {
      final response = await client.auth.signInAnonymously().timeout(
        const Duration(seconds: 10),
      );
      if (response.session == null) {
        throw SharedAlertRepositoryException(
          'Could not start email setup. Please try again.',
        );
      }
    } on AuthException catch (error) {
      if (error.code == 'anonymous_provider_disabled') {
        throw SharedAlertRepositoryException(
          'Email setup needs anonymous access enabled in Supabase.',
        );
      }
      throw SharedAlertRepositoryException(
        'Could not start email setup. Please try again.',
      );
    } on SharedAlertRepositoryException {
      rethrow;
    } catch (_) {
      throw SharedAlertRepositoryException(
        'Could not start email setup. Please try again.',
      );
    }
  }

  void _throwIfFailed(FunctionResponse response) {
    final status = response.status;
    if (status >= 200 && status < 300) return;
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw SharedAlertRepositoryException(data['error'].toString());
    }
    throw SharedAlertRepositoryException(
      'Shared alerts are not available right now.',
    );
  }
}

SharedAlertContactStatus _contactStatusFromString(String? value) {
  return switch (value) {
    'accepted' => SharedAlertContactStatus.accepted,
    'declined' => SharedAlertContactStatus.declined,
    'blocked' => SharedAlertContactStatus.blocked,
    'disabled' => SharedAlertContactStatus.disabled,
    _ => SharedAlertContactStatus.pending,
  };
}

final sharedAlertPreferencesRepositoryProvider =
    Provider<SharedAlertPreferencesRepository>((ref) {
      return SharedAlertPreferencesRepository(
        ref.watch(supabaseClientProvider),
      );
    });
