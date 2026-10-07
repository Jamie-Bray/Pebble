import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';

/// Where the AI description of one photo has got to. The step never waits
/// for it: a photo step is complete as soon as its photo is saved.
@immutable
class ProofAiDescription {
  const ProofAiDescription.pending()
    : text = null,
      failed = false,
      failureMessage = null,
      canRetry = false;

  /// No description. [failureMessage] is the line to show when the server
  /// said why (an allowance or a refusal a retry can't fix); otherwise the
  /// player shows "Couldn't describe · Try again" when [canRetry].
  const ProofAiDescription.failed({this.failureMessage, this.canRetry = false})
    : text = null,
      failed = true;
  const ProofAiDescription.ready(String this.text)
    : failed = false,
      failureMessage = null,
      canRetry = false;

  final String? text;
  final bool failed;
  final String? failureMessage;
  final bool canRetry;

  bool get isPending => text == null && !failed;

  @override
  bool operator ==(Object other) =>
      other is ProofAiDescription &&
      other.text == text &&
      other.failed == failed &&
      other.failureMessage == failureMessage &&
      other.canRetry == canRetry;

  @override
  int get hashCode => Object.hash(text, failed, failureMessage, canRetry);
}

class _DescribeRequest {
  const _DescribeRequest({
    required this.sessionId,
    required this.asset,
    required this.stepLabel,
    required this.photoDetail,
  });

  final String sessionId;
  final RoutineSessionProofAsset asset;
  final String stepLabel;
  final String? photoDetail;
}

/// Every AI description asked for since the app started, by photo id.
///
/// It lives for the whole app process, not for one player screen: the
/// player can be rebuilt while a photo is being described (for example when
/// the app comes back from the camera), and the answer must still reach the
/// photo, the saved session and the run. Each answer is also written to the
/// stored session (and its run, once finished) as it arrives.
class AiCaptionStore extends StateNotifier<Map<String, ProofAiDescription>> {
  AiCaptionStore({
    required AiProofDescriber? describe,
    required RoutineSessionRepository repository,
    Random? random,
  }) : _describe = describe,
       _repository = repository,
       _random = random ?? Random(),
       super(const {});

  final AiProofDescriber? _describe;
  final RoutineSessionRepository _repository;
  final Random _random;
  final Map<String, _DescribeRequest> _requests = {};
  final Map<String, Future<void>> _inFlight = {};
  final Map<String, int> _attempts = {};

  bool get canDescribe => _describe != null;

  /// Asks for a description of [asset], unless one is already on its way.
  /// [retry] asks again after a failure, under a new idempotency key so the
  /// server treats it as a new request rather than a duplicate.
  Future<void> describe({
    required String sessionId,
    required RoutineSessionProofAsset asset,
    required String stepLabel,
    String? photoDetail,
    bool retry = false,
  }) {
    final describe = _describe;
    final proofId = asset.proofId;
    final running = _inFlight[proofId];
    if (describe == null) return Future<void>.value();
    if (running != null) return running;
    if (!retry && state[proofId] != null) return Future<void>.value();

    final request = _DescribeRequest(
      sessionId: sessionId,
      asset: asset,
      stepLabel: stepLabel,
      photoDetail: photoDetail,
    );
    _requests[proofId] = request;
    final attempt = (_attempts[proofId] ?? 0) + 1;
    _attempts[proofId] = attempt;
    // The server only accepts letters, digits, "-" and "_" (8 to 80
    // characters). The random part keeps a retry after an app restart, when
    // the attempt count starts again, from reusing an earlier key.
    final key = attempt == 1
        ? proofId
        : '$proofId-r$attempt${_random.nextInt(1 << 30).toRadixString(36)}';
    _set(proofId, const ProofAiDescription.pending());

    final work = _run(describe, request, key);
    _inFlight[proofId] = work;
    return work.whenComplete(() => _inFlight.remove(proofId));
  }

  Future<void> _run(
    AiProofDescriber describe,
    _DescribeRequest request,
    String key,
  ) async {
    final proofId = request.asset.proofId;
    ProofAiDescription outcome;
    String? text;
    try {
      text = await describe(
        request.asset,
        request.stepLabel,
        request.photoDetail,
        key,
      );
      outcome = text == null
          ? const ProofAiDescription.failed(canRetry: true)
          : ProofAiDescription.ready(text);
    } on AiPhotoAllowanceException catch (error) {
      outcome = ProofAiDescription.failed(failureMessage: error.message);
    } on AiPhotoDescribeException catch (error) {
      outcome = ProofAiDescription.failed(failureMessage: error.message);
    } catch (error) {
      debugPrint('AI photo: describe failed (${error.runtimeType})');
      outcome = const ProofAiDescription.failed(canRetry: true);
    }
    if (!identical(_requests[proofId], request)) {
      // The photo was removed while it was being described.
      return;
    }
    _set(proofId, outcome);
    if (text == null) return;
    try {
      await _repository.saveProofDescription(
        sessionId: request.sessionId,
        proofId: proofId,
        description: text,
      );
    } catch (error) {
      // Still held here, and written with the player's next save.
      debugPrint('AI photo: description not saved (${error.runtimeType})');
    }
  }

  /// Drops a photo's description, for example when the photo is removed. An
  /// answer still on its way for it is then ignored.
  void forget(String proofId) {
    _requests.remove(proofId);
    if (!state.containsKey(proofId) || !mounted) return;
    state = {...state}..remove(proofId);
  }

  /// Waits, up to [timeout], for the descriptions still on their way for
  /// [sessionId].
  Future<void> waitForSession(
    String sessionId, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final pending = [
      for (final entry in _inFlight.entries)
        if (_requests[entry.key]?.sessionId == sessionId) entry.value,
    ];
    if (pending.isEmpty) return;
    await Future.wait(pending).timeout(timeout, onTimeout: () => const []);
  }

  void _set(String proofId, ProofAiDescription description) {
    if (!mounted) return;
    state = {...state, proofId: description};
  }
}

final aiCaptionStoreProvider =
    StateNotifierProvider<AiCaptionStore, Map<String, ProofAiDescription>>((
      ref,
    ) {
      return AiCaptionStore(
        describe: ref.watch(aiProofDescriberProvider),
        repository: ref.watch(routineSessionRepositoryProvider),
      );
    });
