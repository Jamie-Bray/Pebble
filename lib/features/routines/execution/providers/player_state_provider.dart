import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

enum RoutinePlayerScreenPhase {
  loading,
  ready,
  empty,
  error,
  completing,
  completion,
}

enum RoutinePlayerPresentationState {
  standard,
  photoRequired,
  photoCaptured,
  finalStep,
}

/// Why a proof attach did or did not land, so the UI can respond precisely:
/// only a real limit shows the limit message, and failures rely on the
/// controller's errorMessage instead of a misleading limit toast.
enum RoutinePlayerProofAttachResult { attached, limitReached, notAttached }

enum RoutinePlayerOperation {
  none,
  savingStep,
  savingPhoto,
  completing,
  discarding,
}

/// Where the AI description of one photo has got to. The step never waits
/// for it: a photo step is complete as soon as its photo is saved.
class ProofAiDescription {
  const ProofAiDescription.pending()
    : text = null,
      failed = false,
      failureMessage = null;
  const ProofAiDescription.failed({this.failureMessage})
    : text = null,
      failed = true;
  const ProofAiDescription.ready(String this.text)
    : failed = false,
      failureMessage = null;

  final String? text;
  final bool failed;
  final String? failureMessage;

  bool get isPending => text == null && !failed;
}

class RoutinePlayerCompletionSummary {
  const RoutinePlayerCompletionSummary({
    required this.routineTitle,
    required this.photoCount,
    required this.completedSteps,
    required this.skippedSteps,
    required this.run,
  });

  final String routineTitle;
  final int photoCount;
  final int completedSteps;
  final int skippedSteps;
  final RoutineRun run;

  bool get hasPhotos => photoCount > 0;
}

class RoutinePlayerUiState {
  const RoutinePlayerUiState({
    required this.screenPhase,
    required this.maxProofPhotosPerStep,
    required this.routineLimitPolicy,
    this.activeOperation = RoutinePlayerOperation.none,
    this.session,
    this.completionSummary,
    this.errorMessage,
    this.aiDescriptions = const {},
  });

  factory RoutinePlayerUiState.loading({
    required int maxProofPhotosPerStep,
    required RoutineLimitPolicy routineLimitPolicy,
  }) {
    return RoutinePlayerUiState(
      screenPhase: RoutinePlayerScreenPhase.loading,
      maxProofPhotosPerStep: maxProofPhotosPerStep,
      routineLimitPolicy: routineLimitPolicy,
    );
  }

  factory RoutinePlayerUiState.error({
    required int maxProofPhotosPerStep,
    required RoutineLimitPolicy routineLimitPolicy,
    required String errorMessage,
    RoutineSession? session,
  }) {
    return RoutinePlayerUiState(
      screenPhase: RoutinePlayerScreenPhase.error,
      maxProofPhotosPerStep: maxProofPhotosPerStep,
      routineLimitPolicy: routineLimitPolicy,
      session: session,
      errorMessage: errorMessage,
    );
  }

  final RoutinePlayerScreenPhase screenPhase;
  final RoutineSession? session;
  final int maxProofPhotosPerStep;
  final RoutineLimitPolicy routineLimitPolicy;
  final RoutinePlayerOperation activeOperation;
  final RoutinePlayerCompletionSummary? completionSummary;
  final String? errorMessage;

  /// AI descriptions asked for in this sitting, by photo id.
  final Map<String, ProofAiDescription> aiDescriptions;

  /// The description to show under a photo: one asked for just now, or one
  /// saved with the photo earlier. Null when there is nothing to show.
  ProofAiDescription? aiDescriptionFor(RoutineSessionProofAsset asset) {
    final saved = asset.aiDescription;
    return aiDescriptions[asset.proofId] ??
        (saved == null ? null : ProofAiDescription.ready(saved));
  }

  RoutinePlayerUiState copyWith({
    RoutinePlayerScreenPhase? screenPhase,
    RoutineSession? session,
    int? maxProofPhotosPerStep,
    RoutineLimitPolicy? routineLimitPolicy,
    RoutinePlayerOperation? activeOperation,
    RoutinePlayerCompletionSummary? completionSummary,
    bool clearCompletionSummary = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<String, ProofAiDescription>? aiDescriptions,
  }) {
    return RoutinePlayerUiState(
      aiDescriptions: aiDescriptions ?? this.aiDescriptions,
      screenPhase: screenPhase ?? this.screenPhase,
      session: session ?? this.session,
      maxProofPhotosPerStep:
          maxProofPhotosPerStep ?? this.maxProofPhotosPerStep,
      routineLimitPolicy: routineLimitPolicy ?? this.routineLimitPolicy,
      activeOperation: activeOperation ?? this.activeOperation,
      completionSummary: clearCompletionSummary
          ? null
          : completionSummary ?? this.completionSummary,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  List<RoutineStep> get steps => session?.routineSnapshotSteps ?? const [];

  int get currentStepIndex => session?.currentStepIndex ?? 0;

  int get totalSteps => session?.totalStepCount ?? 0;

  double get progress {
    if (screenPhase == RoutinePlayerScreenPhase.completion) {
      return 1;
    }
    if (totalSteps <= 0) {
      return 0;
    }
    return (currentStepIndex + 1) / totalSteps;
  }

  RoutineStep? get currentStep => session?.currentStep;

  RoutineSessionStepState? get currentStepState => session?.currentStepState;

  List<RoutineSessionProofAsset> get proofAssets =>
      currentStepState?.proofAssets ?? const <RoutineSessionProofAsset>[];

  bool get isFirstStep => currentStepIndex <= 0;

  bool get isFinalStep => session?.isFinalStep ?? false;

  bool get hasPhotoRequirement => currentStep?.hasPhotoRequirement ?? false;

  /// A proof step is satisfied by one photo for every tier. Premium expands
  /// how many optional photos can be kept with the step; it never raises the
  /// completion requirement.
  int get requiredPhotoCount => hasPhotoRequirement ? 1 : 0;

  int get capturedPhotoCount => proofAssets.length;

  bool get hasEnoughPhotos =>
      !hasPhotoRequirement || capturedPhotoCount >= requiredPhotoCount;

  bool get canGoBack =>
      session != null && totalSteps > 0 && !isFirstStep && !isForegroundBusy;

  int get maxReachableStepIndex {
    final loadedSession = session;
    if (loadedSession == null || totalSteps <= 0) {
      return 0;
    }
    var highestFinishedStep = -1;
    for (final stepState in loadedSession.stepStates) {
      if (stepState.status == SessionStepStatus.completed ||
          stepState.status == SessionStepStatus.skipped) {
        highestFinishedStep = highestFinishedStep < stepState.stepIndex
            ? stepState.stepIndex
            : highestFinishedStep;
      }
    }
    final reached = highestFinishedStep + 1;
    final current = loadedSession.currentStepIndex;
    final maxIndex = totalSteps - 1;
    return reached > current
        ? reached.clamp(0, maxIndex)
        : current.clamp(0, maxIndex);
  }

  bool get canSkip =>
      currentStep?.canSkip == true &&
      session != null &&
      screenPhase == RoutinePlayerScreenPhase.ready &&
      !isCurrentStepLocked &&
      !isForegroundBusy;

  bool get canAddMorePhotos =>
      session != null &&
      screenPhase == RoutinePlayerScreenPhase.ready &&
      !isForegroundBusy &&
      !isCurrentStepLocked &&
      capturedPhotoCount < maxProofPhotosPerStep;

  bool get isForegroundBusy =>
      activeOperation != RoutinePlayerOperation.none ||
      screenPhase == RoutinePlayerScreenPhase.completing;

  bool get isSavingPhoto =>
      activeOperation == RoutinePlayerOperation.savingPhoto;

  bool get isPrimaryBusy => isForegroundBusy;

  bool get isCompletionVisible =>
      screenPhase == RoutinePlayerScreenPhase.completion;

  RoutinePlayerPresentationState get presentationState {
    if (session == null || currentStep == null) {
      return RoutinePlayerPresentationState.standard;
    }
    if (isFinalStep && hasEnoughPhotos) {
      return RoutinePlayerPresentationState.finalStep;
    }
    if (hasPhotoRequirement && !hasEnoughPhotos) {
      return RoutinePlayerPresentationState.photoRequired;
    }
    if (hasPhotoRequirement && hasEnoughPhotos) {
      return RoutinePlayerPresentationState.photoCaptured;
    }
    return RoutinePlayerPresentationState.standard;
  }

  /// While a required proof photo is missing, the primary button IS the
  /// camera: one thumb position drives the whole run instead of sending the
  /// hand up to the photo strip mid-flow.
  bool get primaryActionIsPhotoCapture =>
      presentationState == RoutinePlayerPresentationState.photoRequired &&
      canAddMorePhotos;

  bool get isPrimaryEnabled {
    if (session == null ||
        currentStep == null ||
        screenPhase != RoutinePlayerScreenPhase.ready ||
        isCurrentStepLocked ||
        isForegroundBusy) {
      return false;
    }

    // Completion is always gated on having enough photos, but the button
    // never goes dead while a photo is missing: it flips into "Take photo"
    // (primaryActionIsPhotoCapture) so the tap-through rhythm at the bottom
    // of the screen carries straight into capture.
    return hasEnoughPhotos || primaryActionIsPhotoCapture;
  }

  String get primaryLabel {
    switch (activeOperation) {
      case RoutinePlayerOperation.savingPhoto:
        return 'Saving photo';
      case RoutinePlayerOperation.savingStep:
        return 'Saving';
      case RoutinePlayerOperation.completing:
        return 'Finishing';
      case RoutinePlayerOperation.discarding:
        return 'Saving';
      case RoutinePlayerOperation.none:
        break;
    }

    switch (presentationState) {
      case RoutinePlayerPresentationState.finalStep:
        return 'Finish routine';
      case RoutinePlayerPresentationState.photoRequired:
        if (primaryActionIsPhotoCapture) {
          return 'Take photo';
        }
        // Capture is unavailable (e.g. at the per-step photo cap while still
        // short of required); fall back to the disabled completion verb.
        return isFinalStep ? 'Finish routine' : 'Complete step';
      case RoutinePlayerPresentationState.standard:
      case RoutinePlayerPresentationState.photoCaptured:
        return 'Complete step';
    }
  }

  bool get showCompletionOpenVault =>
      completionSummary != null && completionSummary!.hasPhotos;

  int get completedSteps =>
      session?.stepStates
          .where((state) => state.status == SessionStepStatus.completed)
          .length ??
      0;

  int get skippedSteps =>
      session?.stepStates
          .where((state) => state.status == SessionStepStatus.skipped)
          .length ??
      0;

  bool get isCurrentStepLocked =>
      session != null && routineLimitPolicy.isStepRestricted(currentStepIndex);

  int get lockedStepCount => routineLimitPolicy.lockedStepCount(totalSteps);
}

class RoutinePlayerController extends StateNotifier<RoutinePlayerUiState> {
  RoutinePlayerController({
    required String sessionId,
    required RoutineSessionRepository repository,
    required RoutineSessionProofStorage proofStorage,
    required int maxProofPhotosPerStep,
    required RoutineLimitPolicy routineLimitPolicy,
    int? aiRoutineId,
    AiProofDescriber? describeProof,
  }) : _sessionId = sessionId,
       _repository = repository,
       _proofStorage = proofStorage,
       _aiRoutineId = aiRoutineId,
       _describeProof = describeProof,
       super(
         RoutinePlayerUiState.loading(
           maxProofPhotosPerStep: maxProofPhotosPerStep,
           routineLimitPolicy: routineLimitPolicy,
         ),
       ) {
    _load();
  }

  final String _sessionId;
  final RoutineSessionRepository _repository;
  final RoutineSessionProofStorage _proofStorage;

  /// The routine with AI photo descriptions switched on, if any.
  final int? _aiRoutineId;
  final AiProofDescriber? _describeProof;
  final Set<Future<void>> _describing = {};
  Future<void>? _backgroundSave;
  int _mutationVersion = 0;

  Future<void> _load() async {
    try {
      final session = await _repository.getSessionById(_sessionId);
      if (session == null) {
        throw StateError('Routine session not found.');
      }
      if (!session.isActive) {
        throw StateError('This routine session is no longer resumable.');
      }
      state = state.copyWith(
        screenPhase: session.totalStepCount == 0
            ? RoutinePlayerScreenPhase.empty
            : RoutinePlayerScreenPhase.ready,
        session: session,
        clearErrorMessage: true,
        clearCompletionSummary: true,
      );
    } catch (error) {
      state = RoutinePlayerUiState.error(
        maxProofPhotosPerStep: state.maxProofPhotosPerStep,
        routineLimitPolicy: state.routineLimitPolicy,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refresh() => _load();

  void clearErrorMessage() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> persistCurrentProgress() {
    final session = state.session;
    if (session == null || !session.isActive || state.isForegroundBusy) {
      return Future<void>.value();
    }

    final currentBackgroundSave = _backgroundSave;
    if (currentBackgroundSave != null) {
      return currentBackgroundSave;
    }

    final version = _mutationVersion;
    final save = _persistLifecycleSnapshot(session, version);
    _backgroundSave = save.whenComplete(() {
      _backgroundSave = null;
    });
    return _backgroundSave!;
  }

  Future<void> _persistLifecycleSnapshot(
    RoutineSession session,
    int version,
  ) async {
    if (!session.isActive) {
      return;
    }
    try {
      final saved = await _repository.saveSessionSnapshot(
        _withAiDescriptions(session),
      );
      if (version == _mutationVersion &&
          !state.isForegroundBusy &&
          state.session?.sessionId == saved.sessionId) {
        state = state.copyWith(session: saved, clearErrorMessage: true);
        return;
      }

      final latest = state.session;
      if (latest != null && latest.isActive && latest.sessionId == _sessionId) {
        await _repository.saveSessionSnapshot(_withAiDescriptions(latest));
      }
    } catch (_) {
      if (version == _mutationVersion && !state.isForegroundBusy) {
        state = state.copyWith(
          errorMessage: "Couldn't save your progress. Try again.",
        );
      }
    }
  }

  Future<void> previousStep() {
    return _runForeground<void>(
      RoutinePlayerOperation.savingStep,
      fallback: null,
      task: _previousStep,
    );
  }

  Future<void> _previousStep() async {
    final session = _requireSession();
    if (session.currentStepIndex <= 0 || !session.isActive) {
      return;
    }
    await _persistSession(
      session.copyWith(currentStepIndex: session.currentStepIndex - 1),
    );
  }

  Future<void> goToStep(int targetIndex) {
    return _runForeground<void>(
      RoutinePlayerOperation.savingStep,
      fallback: null,
      task: () => _goToStep(targetIndex),
    );
  }

  Future<void> _goToStep(int targetIndex) async {
    final session = _requireSession();
    if (!session.isActive || session.totalStepCount <= 0) {
      return;
    }
    final boundedTarget = targetIndex.clamp(0, state.maxReachableStepIndex);
    if (boundedTarget == session.currentStepIndex) {
      return;
    }
    await _persistSession(session.copyWith(currentStepIndex: boundedTarget));
  }

  /// Checks the current step. [at] is the moment of the tap, so the time the
  /// screen shows is exactly the time that is saved.
  Future<RoutineRun?> completeCurrentStep({DateTime? at}) {
    final operation = state.isFinalStep
        ? RoutinePlayerOperation.completing
        : RoutinePlayerOperation.savingStep;
    return _runForeground<RoutineRun?>(
      operation,
      fallback: null,
      task: () => _completeCurrentStep(at ?? DateTime.now()),
    );
  }

  Future<RoutineRun?> _completeCurrentStep(DateTime now) async {
    final session = _requireSession();
    final stepState = session.currentStepState;
    if (stepState == null ||
        !session.isActive ||
        state.isCurrentStepLocked ||
        !state.hasEnoughPhotos) {
      return null;
    }

    final updatedStates = List<RoutineSessionStepState>.from(
      session.stepStates,
    );
    updatedStates[session.currentStepIndex] = stepState.copyWith(
      status: SessionStepStatus.completed,
      completedAt: now,
    );

    final updatedSession = _withAiDescriptions(
      session.copyWith(
        stepStates: updatedStates,
        currentStepIndex: session.isFinalStep
            ? session.currentStepIndex
            : session.currentStepIndex + 1,
      ),
    );

    if (!session.isFinalStep) {
      await _persistSession(updatedSession);
      return null;
    }

    state = state.copyWith(
      screenPhase: RoutinePlayerScreenPhase.completing,
      activeOperation: RoutinePlayerOperation.completing,
      clearErrorMessage: true,
    );

    try {
      final run = await _repository.completeSessionAndWriteRun(updatedSession);
      final completedSession = updatedSession.copyWith(
        status: RoutineSessionStatus.completed,
        completedAt: run.finishedAt,
        updatedAt: run.finishedAt,
      );
      state = state.copyWith(
        screenPhase: RoutinePlayerScreenPhase.completion,
        session: completedSession,
        activeOperation: RoutinePlayerOperation.none,
        completionSummary: RoutinePlayerCompletionSummary(
          routineTitle: completedSession.routineTitleSnapshot,
          photoCount: _countPhotos(completedSession),
          completedSteps: completedSession.completedStepsCount,
          skippedSteps: completedSession.skippedStepsCount,
          run: run,
        ),
        clearErrorMessage: true,
      );
      return run;
    } catch (error) {
      state = state.copyWith(
        screenPhase: RoutinePlayerScreenPhase.ready,
        session: updatedSession,
        activeOperation: RoutinePlayerOperation.none,
        errorMessage: "Couldn't finish the routine. Try again.",
      );
      return null;
    }
  }

  Future<RoutineRun?> skipCurrentStep({DateTime? at}) {
    final operation = state.isFinalStep
        ? RoutinePlayerOperation.completing
        : RoutinePlayerOperation.savingStep;
    return _runForeground<RoutineRun?>(
      operation,
      fallback: null,
      task: () => _skipCurrentStep(at ?? DateTime.now()),
    );
  }

  Future<RoutineRun?> _skipCurrentStep(DateTime now) async {
    final session = _requireSession();
    final step = state.currentStep;
    final stepState = session.currentStepState;
    if (step == null ||
        stepState == null ||
        state.isCurrentStepLocked ||
        !step.canSkip ||
        !session.isActive) {
      return null;
    }

    final updatedStates = List<RoutineSessionStepState>.from(
      session.stepStates,
    );
    updatedStates[session.currentStepIndex] = stepState.copyWith(
      status: SessionStepStatus.skipped,
      completedAt: now,
    );

    final updatedSession = _withAiDescriptions(
      session.copyWith(
        stepStates: updatedStates,
        currentStepIndex: session.isFinalStep
            ? session.currentStepIndex
            : session.currentStepIndex + 1,
      ),
    );

    if (!session.isFinalStep) {
      await _persistSession(updatedSession);
      return null;
    }

    state = state.copyWith(
      screenPhase: RoutinePlayerScreenPhase.completing,
      activeOperation: RoutinePlayerOperation.completing,
      clearErrorMessage: true,
    );

    try {
      final run = await _repository.completeSessionAndWriteRun(updatedSession);
      final completedSession = updatedSession.copyWith(
        status: RoutineSessionStatus.completed,
        completedAt: run.finishedAt,
        updatedAt: run.finishedAt,
      );
      state = state.copyWith(
        screenPhase: RoutinePlayerScreenPhase.completion,
        session: completedSession,
        activeOperation: RoutinePlayerOperation.none,
        completionSummary: RoutinePlayerCompletionSummary(
          routineTitle: completedSession.routineTitleSnapshot,
          photoCount: _countPhotos(completedSession),
          completedSteps: completedSession.completedStepsCount,
          skippedSteps: completedSession.skippedStepsCount,
          run: run,
        ),
        clearErrorMessage: true,
      );
      return run;
    } catch (_) {
      state = state.copyWith(
        screenPhase: RoutinePlayerScreenPhase.ready,
        session: updatedSession,
        activeOperation: RoutinePlayerOperation.none,
        errorMessage: "Couldn't finish the routine. Try again.",
      );
      return null;
    }
  }

  Future<RoutinePlayerProofAttachResult> attachProof(String sourcePath) {
    final alreadyCapturing =
        state.activeOperation == RoutinePlayerOperation.savingPhoto;
    if (!alreadyCapturing &&
        !_beginForegroundOperation(RoutinePlayerOperation.savingPhoto)) {
      return Future.value(RoutinePlayerProofAttachResult.notAttached);
    }

    return _attachProof(sourcePath).whenComplete(() {
      _clearForegroundOperation(RoutinePlayerOperation.savingPhoto);
    });
  }

  Future<RoutinePlayerProofAttachResult> _attachProof(String sourcePath) async {
    final session = _requireSession();
    final stepState = session.currentStepState;
    if (stepState == null || !session.isActive || state.isCurrentStepLocked) {
      return RoutinePlayerProofAttachResult.notAttached;
    }
    if (stepState.proofAssets.length >= state.maxProofPhotosPerStep) {
      return RoutinePlayerProofAttachResult.limitReached;
    }

    try {
      final proofAsset = await _proofStorage.persistCapturedProof(
        sessionId: session.sessionId,
        sourcePath: sourcePath,
      );
      final updatedStates = List<RoutineSessionStepState>.from(
        session.stepStates,
      );
      updatedStates[session.currentStepIndex] = stepState.copyWith(
        proofAssets: [...stepState.proofAssets, proofAsset],
      );

      await _persistSession(session.copyWith(stepStates: updatedStates));
      _startDescribing(session, proofAsset);
      return RoutinePlayerProofAttachResult.attached;
    } catch (_) {
      state = state.copyWith(
        errorMessage: "Couldn't save the photo. Try again.",
      );
      return RoutinePlayerProofAttachResult.notAttached;
    }
  }

  /// Asks for an AI description of a photo just saved on an AI step. Runs
  /// in the background and never throws: the step is already complete, and
  /// nothing about the routine depends on the answer.
  void _startDescribing(
    RoutineSession session,
    RoutineSessionProofAsset asset,
  ) {
    final describe = _describeProof;
    if (describe == null ||
        _aiRoutineId != session.routineId ||
        !aiPhotoStepIndexes(
          session.routineSnapshotSteps,
        ).contains(session.currentStepIndex)) {
      return;
    }
    _setAiDescription(asset.proofId, const ProofAiDescription.pending());
    late final Future<void> work;
    work = () async {
      String? text;
      String? failureMessage;
      try {
        final step =
            session.routineSnapshotSteps[session.currentStepIndex] as CheckStep;
        text = await describe(asset, step.label, step.stepDescription);
      } on AiPhotoAllowanceException catch (error) {
        failureMessage = error.message;
      } catch (_) {
        // Offline, refused or failed: the same quiet line, no retry.
      }
      _setAiDescription(
        asset.proofId,
        text == null
            ? ProofAiDescription.failed(failureMessage: failureMessage)
            : ProofAiDescription.ready(text),
      );
      if (text != null) {
        try {
          await _repository.saveProofDescription(
            sessionId: _sessionId,
            proofId: asset.proofId,
            description: text,
          );
        } catch (_) {
          // Still held in memory and written with the next save.
        }
      }
    }().whenComplete(() => _describing.remove(work));
    _describing.add(work);
  }

  void _setAiDescription(String proofId, ProofAiDescription description) {
    if (!mounted) return;
    state = state.copyWith(
      aiDescriptions: {...state.aiDescriptions, proofId: description},
    );
  }

  /// Copies descriptions that have arrived onto their photos, so that a
  /// snapshot taken before one arrived can't overwrite it when saved.
  RoutineSession _withAiDescriptions(RoutineSession session) {
    final ready = {
      for (final entry in state.aiDescriptions.entries)
        if (entry.value.text != null) entry.key: entry.value.text!,
    };
    if (ready.isEmpty) return session;
    return session.copyWith(
      stepStates: [
        for (final stepState in session.stepStates)
          stepState.copyWith(
            proofAssets: [
              for (final asset in stepState.proofAssets)
                ready.containsKey(asset.proofId)
                    ? asset.copyWith(aiDescription: ready[asset.proofId])
                    : asset,
            ],
          ),
      ],
    );
  }

  /// The descriptions for this run's completion email, in step order: only
  /// photos from the AI steps, at most five. Waits up to [timeout] for any
  /// still on their way, because the email goes out as the routine finishes.
  Future<List<String>> aiDescriptionsForEmail({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_describing.isNotEmpty) {
      await Future.wait(
        _describing.toList(),
      ).timeout(timeout, onTimeout: () => const []);
    }
    final session = state.session;
    if (!mounted || session == null || _aiRoutineId != session.routineId) {
      return const [];
    }
    final aiSteps = aiPhotoStepIndexes(session.routineSnapshotSteps);
    return [
      for (final stepState in _withAiDescriptions(session).stepStates)
        if (aiSteps.contains(stepState.stepIndex))
          for (final asset in stepState.proofAssets)
            if (asset.aiDescription != null) asset.aiDescription!,
    ].take(5).toList();
  }

  Future<void> removeProof(String proofId) {
    return _runForeground<void>(
      RoutinePlayerOperation.savingPhoto,
      fallback: null,
      task: () => _removeProof(proofId),
    );
  }

  Future<void> _removeProof(String proofId) async {
    final session = _requireSession();
    final stepState = session.currentStepState;
    if (stepState == null || !session.isActive) {
      return;
    }

    RoutineSessionProofAsset? asset;
    for (final proof in stepState.proofAssets) {
      if (proof.proofId == proofId) {
        asset = proof;
        break;
      }
    }
    if (asset == null) {
      return;
    }

    try {
      final updatedStates = List<RoutineSessionStepState>.from(
        session.stepStates,
      );
      updatedStates[session.currentStepIndex] = stepState.copyWith(
        proofAssets: stepState.proofAssets
            .where((proof) => proof.proofId != proofId)
            .toList(),
      );

      await _proofStorage.deleteProofAsset(asset);
      await _persistSession(session.copyWith(stepStates: updatedStates));
    } catch (_) {
      state = state.copyWith(
        errorMessage: "Couldn't remove the photo. Try again.",
      );
    }
  }

  Future<void> discardSession() {
    return _runForeground<void>(
      RoutinePlayerOperation.discarding,
      fallback: null,
      task: _discardSession,
    );
  }

  Future<void> _discardSession() async {
    final session = _requireSession();
    await _repository.discardSession(session.sessionId);
    state = state.copyWith(
      session: session.copyWith(
        status: RoutineSessionStatus.discarded,
        discardedAt: DateTime.now(),
      ),
      activeOperation: RoutinePlayerOperation.none,
    );
  }

  bool beginPhotoCapture() {
    if (!state.canAddMorePhotos) {
      return false;
    }
    return _beginForegroundOperation(RoutinePlayerOperation.savingPhoto);
  }

  void cancelPhotoCapture() {
    _clearForegroundOperation(RoutinePlayerOperation.savingPhoto);
  }

  Future<T> _runForeground<T>(
    RoutinePlayerOperation operation, {
    required T fallback,
    required Future<T> Function() task,
  }) async {
    if (!_beginForegroundOperation(operation)) {
      return fallback;
    }
    try {
      return await task();
    } finally {
      _clearForegroundOperation(operation);
    }
  }

  bool _beginForegroundOperation(RoutinePlayerOperation operation) {
    if (state.isForegroundBusy) {
      return false;
    }
    _mutationVersion += 1;
    state = state.copyWith(activeOperation: operation, clearErrorMessage: true);
    return true;
  }

  void _clearForegroundOperation(RoutinePlayerOperation operation) {
    if (state.activeOperation != operation ||
        state.screenPhase == RoutinePlayerScreenPhase.completion) {
      return;
    }
    state = state.copyWith(activeOperation: RoutinePlayerOperation.none);
  }

  RoutineSession _requireSession() {
    final session = state.session;
    if (session == null) {
      throw StateError('Routine session is not loaded.');
    }
    return session;
  }

  Future<RoutineSession> _persistSession(RoutineSession session) async {
    session = _withAiDescriptions(session);
    final optimistic = session.copyWith(updatedAt: DateTime.now());
    state = state.copyWith(
      screenPhase: optimistic.totalStepCount == 0
          ? RoutinePlayerScreenPhase.empty
          : RoutinePlayerScreenPhase.ready,
      session: optimistic,
      clearErrorMessage: true,
    );
    try {
      final saved = await _repository.saveSessionSnapshot(session);
      state = state.copyWith(
        screenPhase: saved.totalStepCount == 0
            ? RoutinePlayerScreenPhase.empty
            : RoutinePlayerScreenPhase.ready,
        session: saved,
        clearErrorMessage: true,
      );
      return saved;
    } catch (_) {
      state = state.copyWith(
        screenPhase: RoutinePlayerScreenPhase.ready,
        errorMessage: "Couldn't save your progress. Try again.",
      );
      rethrow;
    }
  }

  int _countPhotos(RoutineSession session) {
    var total = 0;
    for (final stepState in session.stepStates) {
      total += stepState.proofAssets.length;
    }
    return total;
  }
}

final routinePlayerProvider = StateNotifierProvider.autoDispose
    .family<RoutinePlayerController, RoutinePlayerUiState, String>((
      ref,
      sessionId,
    ) {
      final maxProofPhotosPerStep = ref.watch(maxProofPhotosPerStepProvider);
      return RoutinePlayerController(
        sessionId: sessionId,
        repository: ref.read(routineSessionRepositoryProvider),
        proofStorage: ref.read(routineSessionProofStorageProvider),
        maxProofPhotosPerStep: maxProofPhotosPerStep,
        routineLimitPolicy: ref.watch(routineLimitPolicyProvider),
        aiRoutineId: ref.watch(aiPhotoActiveRoutineIdProvider),
        describeProof: ref.read(aiProofDescriberProvider),
      );
    });

final maxProofPhotosPerStepProvider = Provider<int>((ref) {
  final policy = ref.watch(premiumFeaturePolicyProvider);
  return policy.canUseExtraProofPhotos ? 4 : 1;
});
