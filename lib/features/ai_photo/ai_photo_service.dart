import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pebble_routines/core/config/app_version.dart';
import 'package:pebble_routines/data/remote/supabase_client_provider.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_constants.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';

/// Longest side, in pixels, of the copy sent to be described.
const aiPhotoLongestSide = 1000;

class AiPhotoException implements Exception {
  const AiPhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiDescribeResult {
  const AiDescribeResult.described(String this.description)
    : featureOff = false;
  const AiDescribeResult.failed({this.featureOff = false}) : description = null;

  /// Null when the photo couldn't be described, for any reason.
  final String? description;

  /// The server said the feature is switched off for everyone.
  final bool featureOff;
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

  /// Never throws: a description must not get in the way of a routine.
  Future<AiDescribeResult> describe({
    required String idempotencyKey,
    required Uint8List jpegBytes,
  }) async {
    try {
      final data = await _post(
        {
          'action': 'describe',
          'idempotencyKey': idempotencyKey,
          'imageBase64': base64Encode(jpegBytes),
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
      return AiDescribeResult.failed(
        featureOff: data['reason'] == 'featureOff',
      );
    } catch (_) {
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
      throw const AiPhotoException('Sign in to use AI descriptions.');
    }
    try {
      final response = await client.functions
          .invoke(_function, body: body)
          .timeout(timeout);
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['code'] == 'consentVersion') {
        throw const AiPhotoException(
          'Update Pebble to turn on AI descriptions.',
        );
      }
    } catch (_) {
      // Offline, timed out or an unexpected reply: the same line either way.
    }
    throw AiPhotoException(failure);
  }
}

final aiPhotoServiceProvider = Provider<AiPhotoService>(
  (ref) => AiPhotoService(ref.watch(supabaseClientProvider)),
);

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
({int minWidth, int minHeight}) aiPhotoResizeBounds(int width, int height) {
  return width >= height
      ? (minWidth: aiPhotoLongestSide, minHeight: 1)
      : (minWidth: 1, minHeight: aiPhotoLongestSide);
}

/// An upright JPEG copy of a saved proof photo, small enough to send. Saved
/// proofs are already re-encoded without EXIF or location data
/// ([LocalRoutineSessionProofStorage.persistCapturedProof]), and this
/// re-encodes again.
Future<Uint8List?> encodeAiPhotoJpeg(File file) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final bounds = aiPhotoResizeBounds(descriptor.width, descriptor.height);
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

/// Describes one saved proof photo, or returns null. Never throws.
typedef AiProofDescriber =
    Future<String?> Function(RoutineSessionProofAsset asset);

final aiProofDescriberProvider = Provider<AiProofDescriber>((ref) {
  return (asset) async {
    try {
      final file = await ref
          .read(routineSessionProofStorageProvider)
          .resolveStoredFile(asset.localRelativePath);
      if (file == null) return null;
      final jpeg = await encodeAiPhotoJpeg(file);
      if (jpeg == null) return null;
      final result = await ref
          .read(aiPhotoServiceProvider)
          .describe(idempotencyKey: asset.proofId, jpegBytes: jpeg);
      if (result.featureOff) {
        ref.invalidate(aiPhotoServerEnabledProvider);
      }
      return result.description;
    } catch (_) {
      return null;
    }
  };
});
