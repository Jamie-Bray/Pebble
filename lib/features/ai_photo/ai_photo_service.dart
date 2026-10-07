import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/config/app_version.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';

/// Longest side, in pixels, of the copy sent to be described.
const aiPhotoLongestSide = 600;
const aiPhotoDetailLongestSide = 1000;

class AiPhotoException implements Exception {
  const AiPhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiDescribeResult {
  const AiDescribeResult.described(String this.description)
    : featureOff = false,
      allowanceMessage = null,
      reason = null;
  const AiDescribeResult.failed({
    this.featureOff = false,
    this.allowanceMessage,
    this.reason = 'failed',
  }) : description = null;

  /// Null when the photo couldn't be described, for any reason.
  final String? description;

  /// The server said the feature is switched off for everyone.
  final bool featureOff;
  final String? allowanceMessage;

  /// Why there is no description: the server's `reason` (featureOff,
  /// noActiveEntitlement, noConsent, duplicate, budgetExhausted,
  /// couldNotDescribe, dailyLimit, monthlyLimit), `signedOut`, or `failed`
  /// when the server couldn't be reached or gave an unexpected answer.
  final String? reason;
}

/// A photo that wasn't described for a reason asking again can't fix, with
/// the line to show under it. The step itself is never affected.
class AiPhotoDescribeException implements Exception {
  const AiPhotoDescribeException(this.message, {this.reason});
  final String message;
  final String? reason;
  @override
  String toString() => 'AiPhotoDescribeException($reason)';
}

/// The line shown under a photo for a refusal that a retry can't fix. Null
/// means a retry might work, so "Couldn't describe · Try again" is shown.
String? aiPhotoRefusalMessage(String? reason) => switch (reason) {
  'featureOff' || 'budgetExhausted' => aiPhotoUnavailableMessage,
  'noActiveEntitlement' => aiPhotoNeedsPremiumMessage,
  'noConsent' => aiPhotoNeedsConsentMessage,
  'signedOut' => aiPhotoSignedOutMessage,
  _ => null,
};

class AiPhotoAllowance {
  const AiPhotoAllowance({required this.limit, required this.remaining});
  final int limit;
  final int remaining;
  factory AiPhotoAllowance.fromJson(Map data) {
    final limit = data['limit'];
    final remaining = data['remaining'];
    if (limit is! int ||
        remaining is! int ||
        limit < 1 ||
        remaining < 0 ||
        remaining > limit) {
      throw const FormatException('Invalid AI allowance');
    }
    return AiPhotoAllowance(limit: limit, remaining: remaining);
  }
}

class AiPhotoAllowanceException implements Exception {
  const AiPhotoAllowanceException(this.message);
  final String message;
}

/// Talks to the `describe-proof-photo` Edge Function. The server decides
/// everything that matters: whether the feature is on, Personal Premium,
/// consent and the allowance.
class AiPhotoService {
  AiPhotoService(this._client);

  static const _function = 'describe-proof-photo';
  final SupabaseClient? _client;

  /// Whether the server has the feature switched on. Any failure reads as off.
  Future<bool> fetchEnabled() async {
    final client = _client;
    if (client == null) return false;
    try {
      final response = await client.functions
          .invoke(_function, method: HttpMethod.get)
          .timeout(const Duration(seconds: 10));
      final data = response.data;
      return data is Map && data['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Records consent on the server. Throws [AiPhotoException] with a line for
  /// the person when it could not be recorded; AI then stays off.
  Future<void> recordConsent({required String routineKey}) async {
    final data = await _post({
      'action': 'consent',
      'consentVersion': aiPhotoConsentVersion,
      'routineKey': routineKey,
      'appVersion': await readAppVersion(),
    }, failure: "Couldn't turn on AI descriptions. Try again.");
    if (data['consented'] == true) return;
    throw AiPhotoException(switch (data['reason']) {
      'featureOff' => aiPhotoUnavailableMessage,
      'noActiveEntitlement' =>
        'AI descriptions need Personal Premium on this account.',
      _ => "Couldn't turn on AI descriptions. Try again.",
    });
  }

  Future<void> withdrawConsent() async {
    final data = await _post({
      'action': 'withdraw',
    }, failure: "Couldn't reach Pebble to record this.");
    if (data['withdrawn'] != true) {
      throw const AiPhotoException("Couldn't reach Pebble to record this.");
    }
  }

  Future<AiPhotoAllowance?> fetchAllowance() async {
    try {
      final data = await _post({'action': 'allowance'}, failure: 'failed');
      return data['allowance'] is Map
          ? AiPhotoAllowance.fromJson(data['allowance'] as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Never throws: a description must not get in the way of a routine.
  Future<AiDescribeResult> describe({
    required String idempotencyKey,
    required Uint8List jpegBytes,
    required String stepLabel,
    String? photoDetail,
  }) async {
    try {
      final data = await _post(
        {
          'action': 'describe',
          'idempotencyKey': idempotencyKey,
          'imageBase64': base64Encode(jpegBytes),
          'stepLabel': stepLabel,
          if (photoDetail != null) 'photoDetail': photoDetail,
        },
        failure: 'failed',
        timeout: const Duration(seconds: 30),
      );
      final description = data['description'];
      if (data['described'] == true &&
          description is String &&
          description.trim().isNotEmpty) {
        return AiDescribeResult.described(description.trim());
      }
      final reason = data['reason'] is String
          ? data['reason'] as String
          : 'unexpectedReply';
      // Outcome codes only: never the photo or the description.
      debugPrint('AI photo: not described ($reason)');
      return AiDescribeResult.failed(
        featureOff: reason == 'featureOff',
        reason: reason,
        allowanceMessage: switch (reason) {
          'monthlyLimit' => aiPhotoMonthlyLimitMessage,
          'dailyLimit' => aiPhotoDailyLimitMessage,
          _ => null,
        },
      );
    } on AiPhotoException catch (error) {
      final reason = error.message == aiPhotoSignedOutMessage
          ? 'signedOut'
          : 'failed';
      debugPrint('AI photo: not described ($reason)');
      return AiDescribeResult.failed(reason: reason);
    } catch (error) {
      debugPrint('AI photo: not described (${error.runtimeType})');
      return const AiDescribeResult.failed();
    }
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    required String failure,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      throw const AiPhotoException(aiPhotoSignedOutMessage);
    }
    try {
      final response = await client.functions
          .invoke(_function, body: body)
          .timeout(timeout);
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      debugPrint('AI photo: unexpected reply (${data.runtimeType})');
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['code'] is String
          ? ' ${details['code']}'
          : '';
      debugPrint('AI photo: server answered ${error.status}$code');
      if (details is Map && details['code'] == 'consentVersion') {
        throw const AiPhotoException(
          'Update Pebble to turn on AI descriptions.',
        );
      }
    } on TimeoutException {
      debugPrint('AI photo: request timed out');
    } catch (error) {
      // Offline or an unexpected reply: the same line either way.
      debugPrint('AI photo: request failed (${error.runtimeType})');
    }
    throw AiPhotoException(failure);
  }
}

final aiPhotoServiceProvider = Provider<AiPhotoService>(
  (ref) => AiPhotoService(ref.watch(supabaseClientProvider)),
);

final aiPhotoAllowanceProvider = FutureProvider.autoDispose<AiPhotoAllowance?>((
  ref,
) {
  if (!ref.watch(authSessionProvider).isSignedIn) return null;
  return ref.watch(aiPhotoServiceProvider).fetchAllowance();
});

/// The server's feature switch, which is the source of truth. Off until the
/// server says otherwise, and after any failure to ask. A refresh keeps
/// showing the last answer while it loads.
final aiPhotoServerEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(aiPhotoServiceProvider).fetchEnabled(),
);

/// The size limits to pass to the image compressor so that the longest side
/// of a [width] x [height] photo comes out at [aiPhotoLongestSide] or less.
/// The compressor scales by the smaller of width/minWidth and
/// height/minHeight and never enlarges.
({int minWidth, int minHeight}) aiPhotoResizeBounds(
  int width,
  int height, {
  int longestSide = aiPhotoLongestSide,
}) {
  return width >= height
      ? (minWidth: longestSide, minHeight: 1)
      : (minWidth: 1, minHeight: longestSide);
}

/// An upright JPEG copy of a saved proof photo, small enough to send. Saved
/// proofs are already re-encoded without EXIF or location data
/// ([LocalRoutineSessionProofStorage.persistCapturedProof]), and this
/// re-encodes again.
Future<Uint8List?> encodeAiPhotoJpeg(File file, {bool detailed = false}) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final bounds = aiPhotoResizeBounds(
    descriptor.width,
    descriptor.height,
    longestSide: detailed ? aiPhotoDetailLongestSide : aiPhotoLongestSide,
  );
  descriptor.dispose();
  buffer.dispose();
  return FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: bounds.minWidth,
    minHeight: bounds.minHeight,
    quality: 80,
    format: CompressFormat.jpeg,
  );
}

/// Describes one saved proof photo. Returns the description, or null when
/// it couldn't be described and asking again might help. Throws
/// [AiPhotoAllowanceException] or [AiPhotoDescribeException], each with a
/// line for the person, when the server refused for a reason a retry can't
/// fix.
///
/// [idempotencyKey] is the photo's id on the first attempt and a new key on
/// each retry: the server answers a key it has already seen with `duplicate`
/// and never describes it a second time.
typedef AiProofDescriber =
    Future<String?> Function(
      RoutineSessionProofAsset asset,
      String stepLabel,
      String? photoDetail,
      String idempotencyKey,
    );

final aiProofDescriberProvider = Provider<AiProofDescriber>((ref) {
  return (asset, stepLabel, photoDetail, idempotencyKey) async {
    try {
      final file = await ref
          .read(routineSessionProofStorageProvider)
          .resolveStoredFile(asset.localRelativePath);
      if (file == null) {
        debugPrint('AI photo: not described (photoMissing)');
        return null;
      }
      final detail = photoDetail?.trim();
      final cue = detail == null || detail.isEmpty || detail == 'Take a photo'
          ? null
          : detail;
      final jpeg = await encodeAiPhotoJpeg(file, detailed: cue != null);
      if (jpeg == null) {
        debugPrint('AI photo: not described (encodeFailed)');
        return null;
      }
      final result = await ref
          .read(aiPhotoServiceProvider)
          .describe(
            idempotencyKey: idempotencyKey,
            jpegBytes: jpeg,
            stepLabel: stepLabel,
            photoDetail: cue,
          );
      ref.invalidate(aiPhotoAllowanceProvider);
      if (result.featureOff) {
        ref.invalidate(aiPhotoServerEnabledProvider);
      }
      if (result.allowanceMessage != null) {
        throw AiPhotoAllowanceException(result.allowanceMessage!);
      }
      final refusal = aiPhotoRefusalMessage(result.reason);
      if (result.description == null && refusal != null) {
        throw AiPhotoDescribeException(refusal, reason: result.reason);
      }
      return result.description;
    } on AiPhotoAllowanceException {
      rethrow;
    } on AiPhotoDescribeException {
      rethrow;
    } catch (error) {
      debugPrint('AI photo: not described (${error.runtimeType})');
      return null;
    }
  };
});
