import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_service.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/ai_caption_store.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

export 'package:pebble_routines/features/routines/execution/providers/ai_caption_store.dart'
    show ProofAiDescription, AiCaptionStore, aiCaptionStoreProvider;

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
    this.aiRoutineActive = false,
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

  /// AI descriptions asked for since the app started, by photo id
  /// ([AiCaptionStore]).
  final Map<String, ProofAiDescription> aiDescriptions;

  /// AI photo descriptions are switched on for this routine.
  final bool aiRoutineActive;

  /// Photos taken on the current step are sent to be described.
  bool get describesCurrentStep =>
      aiRoutineActive &&
      session != null &&
      aiPhotoStepIndexes(steps).contains(currentStepIndex);

  /// The description to show under a photo: one asked for just now, or one
  /// saved with the photo earlier. Null when there is nothing to show.
  ProofAiDescription? aiDescriptionFor(RoutineSessionProofAsset asset) {
    final saved = asset.aiDescription;
    final asked = aiDescriptions[asset.proofId];
    if (asked != null && (asked.text != null || saved == null)) return asked;
    return saved == null ? asked : ProofAiDescription.ready(saved);
  }

  /// How many of this run's photos have a description, and how many are
  /// still being described.
  ({int described, int describing}) get runAiDescriptionCounts {
    var described = 0;
    var describing = 0;
    for (final stepState
        in session?.stepStates ?? const <RoutineSessionStepState>[]) {
      for (final asset in stepState.proofAssets) {
        final description = aiDescriptionFor(asset);
        if (description?.text != null) described += 1;
        if (description?.isPending == true) describing += 1;
      }
    }
    return (described: described, describing: describing);
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
    bool? aiRoutineActive,
  }) {
    return RoutinePlayerUiState(
      aiDescriptions: aiDescriptions ?? this.aiDescriptions,
      aiRoutineActive: aiRoutineActive ?? this.aiRoutineActive,
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
    Set<int> aiRoutineIds = const {},
    AiProofDescriber? describeProof,
    AiCaptionStore? captionStore,
  }) : _sessionId = sessionId,
       _repository = repository,
       _proofStorage = proofStorage,
       _aiRoutineIds = aiRoutineIds,
       _ownsCaptions = captionStore == null,
       _captions =
           captionStore ??
           AiCaptionStore(describe: describeProof, repository: repository),
       super(
         RoutinePlayerUiState.loading(
           maxProofPhotosPerStep: maxProofPhotosPerStep,
           routineLimitPolicy: routineLimitPolicy,
         ),
       ) {
    _removeCaptionListener = _captions.addListener((captions) {
      state = state.copyWith(aiDescriptions: captions);
    });
    _load();
  }

  final String _sessionId;
  final RoutineSessionRepository _repository;
  final RoutineSessionProofStorage _proofStorage;

  /// The routines with AI photo descriptions switched on.
  Set<int> _aiRoutineIds;

  /// Descriptions live here rather than in this controller, so one that
  /// arrives after this controller has gone still reaches the photo.
  final AiCaptionStore _captions;
  final bool _ownsCaptions;
  late final void Function() _removeCaptionListener;
  Future<void>? _backgroundSave;
  int _mutationVersion = 0;

  @override
  void dispose() {
    _removeCaptionListener();
    if (_ownsCaptions) _captions.dispose();
    super.dispose();
  }

  /// Applies a Premium change mid-run (photo allowance, locked steps, AI)
  /// without rebuilding the controller: a rebuild would reload the session
  /// from storage and drop whatever is in flight.
  void updatePolicies({
    int? maxProofPhotosPerStep,
    RoutineLimitPolicy? routineLimitPolicy,
    Set<int>? aiRoutineIds,
  }) {
    if (!mounted) return;
    if (aiRoutineIds != null) _aiRoutineIds = aiRoutineIds;
    final session = state.session;
    state = state.copyWith(
      maxProofPhotosPerStep: maxProofPhotosPerStep,
      routineLimitPolicy: routineLimitPolicy,
      aiRoutineActive:
          session != null && _aiRoutineIds.contains(session.routineId),
    );
  }

  Future<void> _load() async {
    try {
      final session = await _repository.getSessionById(_sessionId);
      if (!mounted) return;
      if (session == null) {
        throw StateError('Routine session not found.');
      }
      if (session.status == RoutineSessionStatus.completed) {
        // Finished already (for example on this same page a moment ago):
        // show its completion screen, never an error.
        await _showCompleted(session);
        return;
      }
      if (!session.isActive) {
        throw StateError(
          'This run has ended. Start the routine again from Home.',
        );
      }
      state = state.copyWith(
        screenPhase: session.totalStepCount == 0
            ? RoutinePlayerScreenPhase.empty
            : RoutinePlayerScreenPhase.ready,
        session: session,
        aiRoutineActive: _aiRoutineIds.contains(session.routineId),
        clearErrorMessage: true,
        clearCompletionSummary: true,
      );
    } catch (error) {
      if (!mounted) return;
      state = RoutinePlayerUiState.error(
        maxProofPhotosPerStep: state.maxProofPhotosPerStep,
        routineLimitPolicy: state.routineLimitPolicy,
        errorMessage: error is StateError ? error.message : error.toString(),
      ).copyWith(aiDescriptions: state.aiDescriptions);
    }
  }

  Future<void> _showCompleted(RoutineSession session) async {
    final run = await _repository.findRunForSession(session);
    if (!mounted) return;
    state = state.copyWith(
      screenPhase: RoutinePlayerScreenPhase.completion,
      session: session,
      aiRoutineActive: _aiRoutineIds.contains(session.routineId),
      activeOperation: RoutinePlayerOperation.none,
      completionSummary: run == null
          ? null
          : RoutinePlayerCompletionSummary(
              routineTitle: session.routineTitleSnapshot,
              photoCount: _countPhotos(session),
              completedSteps: session.completedStepsCount,
              skippedSteps: session.skippedStepsCount,
              run: run,
            ),
      clearCompletionSummary: run == null,
      clearErrorMessage: true,
    );
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
      debugPrint("Routine player: couldn't finish (${error.runtimeType})");
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
    } catch (error) {
      debugPrint("Routine player: couldn't finish (${error.runtimeType})");
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
    RoutineSessionProofAsset asset, {
    int? stepIndex,
    bool retry = false,
  }) {
    final index = stepIndex ?? session.currentStepIndex;
    if (!_captions.canDescribe ||
        !_aiRoutineIds.contains(session.routineId) ||
        !aiPhotoStepIndexes(session.routineSnapshotSteps).contains(index)) {
      return;
    }
    final step = session.routineSnapshotSteps[index];
    if (step is! CheckStep) return;
    unawaited(
      _captions.describe(
        sessionId: session.sessionId,
        asset: asset,
        stepLabel: step.label,
        photoDetail: step.stepDescription,
        retry: retry,
      ),
    );
  }

  /// "Try again" under a photo whose description didn't come back. Only ever
  /// on a tap: nothing is retried on its own.
  void retryAiDescription(String proofId) {
    final session = state.session;
    if (session == null) return;
    for (final stepState in session.stepStates) {
      for (final asset in stepState.proofAssets) {
        if (asset.proofId != proofId) continue;
        final current = state.aiDescriptionFor(asset);
        if (current == null || !current.failed || !current.canRetry) return;
        _startDescribing(
          session,
          asset,
          stepIndex: stepState.stepIndex,
          retry: true,
        );
        return;
      }
    }
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
    await _captions.waitForSession(_sessionId, timeout: timeout);
    final session = state.session;
    if (!mounted ||
        session == null ||
        !_aiRoutineIds.contains(session.routineId)) {
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

      _captions.forget(proofId);
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
      // One controller for the whole run. Nothing here is watched: a rebuild
      // would dispose the controller mid-run (Premium and sign-in state are
      // refreshed every time the app comes back from the camera), so policy
      // changes are passed in with updatePolicies instead.
      final controller = RoutinePlayerController(
        sessionId: sessionId,
        repository: ref.read(routineSessionRepositoryProvider),
        proofStorage: ref.read(routineSessionProofStorageProvider),
        maxProofPhotosPerStep: ref.read(maxProofPhotosPerStepProvider),
        routineLimitPolicy: ref.read(routineLimitPolicyProvider),
        aiRoutineIds: ref.read(aiPhotoActiveRoutineIdsProvider),
        captionStore: ref.read(aiCaptionStoreProvider.notifier),
      );
      ref.listen<int>(
        maxProofPhotosPerStepProvider,
        (_, next) => controller.updatePolicies(maxProofPhotosPerStep: next),
      );
      ref.listen<RoutineLimitPolicy>(
        routineLimitPolicyProvider,
        (_, next) => controller.updatePolicies(routineLimitPolicy: next),
      );
      ref.listen<Set<int>>(
        aiPhotoActiveRoutineIdsProvider,
        (_, next) => controller.updatePolicies(aiRoutineIds: next),
      );
      return controller;
    });

final maxProofPhotosPerStepProvider = Provider<int>((ref) {
  final policy = ref.watch(premiumFeaturePolicyProvider);
  return policy.canUseExtraProofPhotos ? 4 : 1;
});
