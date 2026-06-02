import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
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
    this.activeOperation = RoutinePlayerOperation.none,
    this.session,
    this.completionSummary,
    this.errorMessage,
  });

  factory RoutinePlayerUiState.loading({required int maxProofPhotosPerStep}) {
    return RoutinePlayerUiState(
      screenPhase: RoutinePlayerScreenPhase.loading,
      maxProofPhotosPerStep: maxProofPhotosPerStep,
    );
  }

  factory RoutinePlayerUiState.error({
    required int maxProofPhotosPerStep,
    required String errorMessage,
    RoutineSession? session,
  }) {
    return RoutinePlayerUiState(
      screenPhase: RoutinePlayerScreenPhase.error,
      maxProofPhotosPerStep: maxProofPhotosPerStep,
      session: session,
      errorMessage: errorMessage,
    );
  }

  final RoutinePlayerScreenPhase screenPhase;
  final RoutineSession? session;
  final int maxProofPhotosPerStep;
  final RoutinePlayerOperation activeOperation;
  final RoutinePlayerCompletionSummary? completionSummary;
  final String? errorMessage;

  RoutinePlayerUiState copyWith({
    RoutinePlayerScreenPhase? screenPhase,
    RoutineSession? session,
    int? maxProofPhotosPerStep,
    RoutinePlayerOperation? activeOperation,
    RoutinePlayerCompletionSummary? completionSummary,
    bool clearCompletionSummary = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RoutinePlayerUiState(
      screenPhase: screenPhase ?? this.screenPhase,
      session: session ?? this.session,
      maxProofPhotosPerStep:
          maxProofPhotosPerStep ?? this.maxProofPhotosPerStep,
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

  int get requiredPhotoCount => currentStep?.requiredPhotoCount ?? 0;

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
      !isForegroundBusy;

  bool get canAddMorePhotos =>
      session != null &&
      screenPhase == RoutinePlayerScreenPhase.ready &&
      !isForegroundBusy &&
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

  bool get isPrimaryEnabled {
    if (session == null ||
        currentStep == null ||
        screenPhase != RoutinePlayerScreenPhase.ready ||
        isForegroundBusy) {
      return false;
    }

    switch (presentationState) {
      case RoutinePlayerPresentationState.photoRequired:
        return canAddMorePhotos;
      case RoutinePlayerPresentationState.standard:
      case RoutinePlayerPresentationState.photoCaptured:
      case RoutinePlayerPresentationState.finalStep:
        return hasEnoughPhotos;
    }
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
      case RoutinePlayerPresentationState.photoRequired:
        return 'Take photo';
      case RoutinePlayerPresentationState.finalStep:
        return 'Finish routine';
      case RoutinePlayerPresentationState.standard:
      case RoutinePlayerPresentationState.photoCaptured:
        return 'Complete step';
    }
  }

  bool get showAddAnotherPhoto =>
      hasPhotoRequirement &&
      hasEnoughPhotos &&
      canAddMorePhotos &&
      screenPhase == RoutinePlayerScreenPhase.ready &&
      !isForegroundBusy;

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
}

class RoutinePlayerController extends StateNotifier<RoutinePlayerUiState> {
  RoutinePlayerController({
    required String sessionId,
    required RoutineSessionRepository repository,
    required RoutineSessionProofStorage proofStorage,
    required int maxProofPhotosPerStep,
  }) : _sessionId = sessionId,
       _repository = repository,
       _proofStorage = proofStorage,
       super(
         RoutinePlayerUiState.loading(
           maxProofPhotosPerStep: maxProofPhotosPerStep,
         ),
       ) {
    _load();
  }

  final String _sessionId;
  final RoutineSessionRepository _repository;
  final RoutineSessionProofStorage _proofStorage;
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
      final saved = await _repository.saveSessionSnapshot(session);
      if (version == _mutationVersion &&
          !state.isForegroundBusy &&
          state.session?.sessionId == saved.sessionId) {
        state = state.copyWith(session: saved, clearErrorMessage: true);
        return;
      }

      final latest = state.session;
      if (latest != null && latest.isActive && latest.sessionId == _sessionId) {
        await _repository.saveSessionSnapshot(latest);
      }
    } catch (_) {
      if (version == _mutationVersion && !state.isForegroundBusy) {
        state = state.copyWith(
          errorMessage: 'Could not save progress. Please try again.',
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

  Future<RoutineRun?> completeCurrentStep() {
    final operation = state.isFinalStep
        ? RoutinePlayerOperation.completing
        : RoutinePlayerOperation.savingStep;
    return _runForeground<RoutineRun?>(
      operation,
      fallback: null,
      task: _completeCurrentStep,
    );
  }

  Future<RoutineRun?> _completeCurrentStep() async {
    final session = _requireSession();
    final stepState = session.currentStepState;
    if (stepState == null || !session.isActive || !state.hasEnoughPhotos) {
      return null;
    }

    final now = DateTime.now();
    final updatedStates = List<RoutineSessionStepState>.from(
      session.stepStates,
    );
    updatedStates[session.currentStepIndex] = stepState.copyWith(
      status: SessionStepStatus.completed,
      completedAt: now,
    );

    final updatedSession = session.copyWith(
      stepStates: updatedStates,
      currentStepIndex: session.isFinalStep
          ? session.currentStepIndex
          : session.currentStepIndex + 1,
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
        errorMessage: 'Could not finish routine. Please try again.',
      );
      return null;
    }
  }

  Future<RoutineRun?> skipCurrentStep() {
    final operation = state.isFinalStep
        ? RoutinePlayerOperation.completing
        : RoutinePlayerOperation.savingStep;
    return _runForeground<RoutineRun?>(
      operation,
      fallback: null,
      task: _skipCurrentStep,
    );
  }

  Future<RoutineRun?> _skipCurrentStep() async {
    final session = _requireSession();
    final step = state.currentStep;
    final stepState = session.currentStepState;
    if (step == null ||
        stepState == null ||
        !step.canSkip ||
        !session.isActive) {
      return null;
    }

    final updatedStates = List<RoutineSessionStepState>.from(
      session.stepStates,
    );
    updatedStates[session.currentStepIndex] = stepState.copyWith(
      status: SessionStepStatus.skipped,
      completedAt: DateTime.now(),
    );

    final updatedSession = session.copyWith(
      stepStates: updatedStates,
      currentStepIndex: session.isFinalStep
          ? session.currentStepIndex
          : session.currentStepIndex + 1,
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
        errorMessage: 'Could not finish routine. Please try again.',
      );
      return null;
    }
  }

  Future<bool> attachProof(String sourcePath) {
    final alreadyCapturing =
        state.activeOperation == RoutinePlayerOperation.savingPhoto;
    if (!alreadyCapturing &&
        !_beginForegroundOperation(RoutinePlayerOperation.savingPhoto)) {
      return Future<bool>.value(false);
    }

    return _attachProof(sourcePath).whenComplete(() {
      _clearForegroundOperation(RoutinePlayerOperation.savingPhoto);
    });
  }

  Future<bool> _attachProof(String sourcePath) async {
    final session = _requireSession();
    final stepState = session.currentStepState;
    if (stepState == null ||
        !session.isActive ||
        stepState.proofAssets.length >= state.maxProofPhotosPerStep) {
      return false;
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
      return true;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Could not save photo. Please try again.',
      );
      return false;
    }
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
        errorMessage: 'Could not remove photo. Please try again.',
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
        errorMessage: 'Could not save progress. Please try again.',
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
      );
    });

final maxProofPhotosPerStepProvider = Provider<int>((ref) {
  final policy = ref.watch(premiumFeaturePolicyProvider);
  return policy.canUseExtraProofPhotos ? 4 : 1;
});
