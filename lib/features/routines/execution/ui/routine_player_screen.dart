import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/ui/pebble_buttons.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/routines/execution/ui/step_check_off.dart';

export 'package:pebble_routines/features/routines/execution/ui/routine_complete_screen.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/shared/ui/guidance_audio_play_button.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';

class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RoutinePlayerScreen> createState() =>
      _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _pendingCameraCapturePrefsKey =
      'routine_player_pending_camera_capture';
  String? _lastReminderSentRunId;

  /// What happened to this run's completion email, shown on the completion
  /// screen. Null when no email was due.
  String? _completionEmailNote;
  AudioPlayer? _chimePlayer;

  /// Moment 1. The check is saved the instant it is tapped; this controller
  /// only plays the motion over the already-saved state.
  late final AnimationController _checkOff = AnimationController(
    vsync: this,
    duration: CheckOffTimeline.duration,
  )..addStatusListener(_onCheckOffStatus);

  /// The step that was just checked, shown while it settles into the trail.
  CheckedStepSnapshot? _outgoing;
  bool _checkOffReduced = false;

  /// True for [CheckOffTimeline.inputGuard] after a check: a double tap must
  /// never check two steps.
  bool _inputGuarded = false;

  /// Keeps the final step on screen while its check draws, before the
  /// completion screen fades in.
  bool _holdCompletion = false;
  final List<Timer> _checkOffTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_recoverLostCameraPhoto());
  }

  /// Android can destroy the activity while the system camera is open, which
  /// drops the pickImage result on the floor. image_picker parks the captured
  /// file until retrieveLostData is called, so re-attach it to the restored
  /// session instead of silently losing the user's photo.
  Future<void> _recoverLostCameraPhoto() async {
    final lost = await ref
        .read(routinePlayerPhotoPickerProvider)
        .retrieveLostPhoto();
    if (lost == null) {
      await _clearPendingCameraCapture();
      return;
    }

    final pendingCapture = await _readPendingCameraCapture();
    if (pendingCapture == null || !mounted) {
      unawaited(_deletePickerTemp(lost.path));
      return;
    }

    final ready = await _waitForPlayerReady();
    if (!ready || !mounted) {
      await _clearPendingCameraCapture();
      unawaited(_deletePickerTemp(lost.path));
      return;
    }

    final playerState = ref.read(routinePlayerProvider(widget.sessionId));
    final session = playerState.session;
    final isExpectedCapture =
        session?.sessionId == pendingCapture.sessionId &&
        playerState.currentStepIndex == pendingCapture.stepIndex &&
        playerState.capturedPhotoCount == pendingCapture.capturedPhotoCount;
    if (!isExpectedCapture ||
        !playerState.hasPhotoRequirement ||
        !playerState.canAddMorePhotos) {
      await _clearPendingCameraCapture();
      unawaited(_deletePickerTemp(lost.path));
      return;
    }
    // Re-attach best-effort; the temp copy is cleared either way so a failed
    // attach can't leave an orphaned file behind.
    await ref
        .read(routinePlayerProvider(widget.sessionId).notifier)
        .attachProof(lost.path);
    await _clearPendingCameraCapture();
    unawaited(_deletePickerTemp(lost.path));
  }

  Future<bool> _waitForPlayerReady() {
    final initial = ref.read(routinePlayerProvider(widget.sessionId));
    if (initial.screenPhase != RoutinePlayerScreenPhase.loading) {
      return Future.value(
        initial.screenPhase == RoutinePlayerScreenPhase.ready,
      );
    }
    final completer = Completer<bool>();
    late final ProviderSubscription<RoutinePlayerUiState> subscription;
    subscription = ref.listenManual(routinePlayerProvider(widget.sessionId), (
      previous,
      next,
    ) {
      if (next.screenPhase == RoutinePlayerScreenPhase.loading ||
          completer.isCompleted) {
        return;
      }
      completer.complete(next.screenPhase == RoutinePlayerScreenPhase.ready);
      subscription.close();
    });
    return completer.future;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCheckOffTimers();
    _checkOff.dispose();
    unawaited(_chimePlayer?.dispose());
    unawaited(_completionPlayer?.dispose());
    super.dispose();
  }

  void _onCheckOffStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && _outgoing != null) {
      setState(() => _outgoing = null);
    }
  }

  void _cancelCheckOffTimers() {
    for (final timer in _checkOffTimers) {
      timer.cancel();
    }
    _checkOffTimers.clear();
  }

  /// Under Reduce Motion (or with transitions off) the check-off is a plain
  /// cross-fade. Haptics are not motion, so they stay.
  bool _reduceMotion() =>
      MediaQuery.disableAnimationsOf(context) ||
      !ref.read(playerSettingsControllerProvider).enableTransitions;

  /// Jumps any running check-off to its end, so a fast second tap starts the
  /// next one cleanly instead of queueing behind it.
  void _finishRunningCheckOff() {
    _cancelCheckOffTimers();
    if (_checkOff.isAnimating) {
      _checkOff.value = 1;
    }
    _outgoing = null;
    _holdCompletion = false;
    _inputGuarded = false;
  }

  void _scheduleCheckOff(Duration delay, VoidCallback action) {
    _checkOffTimers.add(
      Timer(delay, () {
        if (mounted) action();
      }),
    );
  }

  /// "Tap, stroke, stamp, settle": a light tap now and, as the stroke
  /// lands, a second click plus the optional stone-tap sound.
  void _playCheckFeedback() {
    final playerSettings = ref.read(playerSettingsControllerProvider);
    if (playerSettings.stepCompleteHaptic) {
      unawaited(HapticFeedback.lightImpact());
    }
    _scheduleCheckOff(CheckOffTimeline.secondCue, () {
      final settings = ref.read(playerSettingsControllerProvider);
      if (settings.stepCompleteHaptic) {
        unawaited(HapticFeedback.selectionClick());
      }
      if (settings.stepCompleteSound) {
        unawaited(_playChime());
      }
    });
  }

  void _announce(String message) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  AudioPlayer? _completionPlayer;

  /// Three quick stone taps, rising: the cairn being stacked. Opt-in, with
  /// the step sound.
  void _playCompletionSound() {
    unawaited(() async {
      try {
        var player = _completionPlayer;
        if (player == null) {
          player = AudioPlayer();
          _completionPlayer = player;
          await player.setAsset('assets/audio/routine_complete.wav');
        }
        await player.seek(Duration.zero);
        await player.play();
      } catch (_) {
        // Feedback is best-effort; never let it interfere with the routine.
      }
    }());
  }

  Future<void> _playChime() async {
    try {
      var player = _chimePlayer;
      if (player == null) {
        player = AudioPlayer();
        _chimePlayer = player;
        await player.setAsset('assets/audio/step_complete.wav');
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Feedback is best-effort; never let it interfere with the routine.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final playerState = ref.read(routinePlayerProvider(widget.sessionId));
      if (playerState.isForegroundBusy) {
        return;
      }
      unawaited(
        ref
            .read(routinePlayerProvider(widget.sessionId).notifier)
            .persistCurrentProgress(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(routinePlayerProvider(widget.sessionId));
    final controller = ref.read(
      routinePlayerProvider(widget.sessionId).notifier,
    );
    final themeData = ref.watch(currentThemeDataProvider);
    final pebbleTheme = themeData.extension<PebbleThemeX>();

    ref.listen<RoutinePlayerUiState>(routinePlayerProvider(widget.sessionId), (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage || !mounted) {
        return;
      }
      ZenNotifications.showError(context, message: message);
      controller.clearErrorMessage();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (playerState.isCompletionVisible) {
          _goHome();
          return;
        }
        unawaited(_attemptExit());
      },
      child: Scaffold(
        backgroundColor: pebbleTheme?.gradient != null
            ? Colors.transparent
            : themeData.colorScheme.surface,
        body: Container(
          decoration: pebbleTheme?.gradient != null
              ? BoxDecoration(gradient: pebbleTheme!.gradient)
              : BoxDecoration(color: themeData.colorScheme.surface),
          child: SafeArea(
            bottom: false,
            child: _PhaseSwitcher(
              reduceMotion: MediaQuery.disableAnimationsOf(context),
              child: _buildPhase(context, themeData, playerState, controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(
    BuildContext context,
    ThemeData themeData,
    RoutinePlayerUiState playerState,
    RoutinePlayerController controller,
  ) {
    // The final step's check draws before the completion screen fades in,
    // even though the run is already saved.
    final phase =
        playerState.screenPhase == RoutinePlayerScreenPhase.completion &&
            _holdCompletion
        ? RoutinePlayerScreenPhase.completing
        : playerState.screenPhase;
    return KeyedSubtree(
      key: ValueKey(
        phase == RoutinePlayerScreenPhase.completing
            ? RoutinePlayerScreenPhase.ready
            : phase,
      ),
      child: switch (phase) {
              RoutinePlayerScreenPhase.loading => const _PlayerStatusView(
                title: 'Loading routine',
                message: 'Restoring your place.',
                icon: LucideIcons.loaderCircle,
              ),
              RoutinePlayerScreenPhase.error => _PlayerStatusView(
                title: 'Could not load routine',
                message:
                    playerState.errorMessage ?? 'Please try again in a moment.',
                icon: LucideIcons.circleAlert,
                primaryLabel: 'Retry',
                onPrimary: () => unawaited(controller.refresh()),
                secondaryLabel: 'Back to Home',
                onSecondary: _goHome,
              ),
              RoutinePlayerScreenPhase.empty => _PlayerStatusView(
                title: playerState.session?.routineTitleSnapshot ?? 'Routine',
                message: 'This routine does not have any steps yet.',
                icon: LucideIcons.listTodo,
                primaryLabel: 'Back to Home',
                onPrimary: _goHome,
                topAction: _TopBackButton(onBack: _attemptExit),
              ),
              RoutinePlayerScreenPhase.completion => _buildCompletion(playerState),
              RoutinePlayerScreenPhase.ready ||
              RoutinePlayerScreenPhase.completing => _buildPlayer(
                context,
                themeData,
                playerState,
              ),
      },
    );
  }

  Widget _buildCompletion(RoutinePlayerUiState playerState) {
    final summary = playerState.completionSummary;
    final session = playerState.session;
    final proofStorage = ref.read(routineSessionProofStorageProvider);
    final settings = ref.read(playerSettingsControllerProvider);
    final proofs = <RoutineSessionProofAsset>[
      for (final stepState
          in session?.stepStates ?? const <RoutineSessionStepState>[])
        ...stepState.proofAssets,
    ];
    final hasPhotoSteps =
        session?.routineSnapshotSteps.any((step) => step.hasPhotoRequirement) ??
        true;
    final photoCount = summary?.photoCount ?? proofs.length;
    return RoutineCompleteScreen(
      routineName:
          summary?.routineTitle ?? session?.routineTitleSnapshot ?? 'Routine',
      routineId: session?.routineId,
      totalStepsCompleted:
          summary?.completedSteps ?? playerState.completedSteps,
      totalPhotosSaved: photoCount,
      totalSteps: session?.routineSnapshotSteps.length,
      skippedSteps: summary?.skippedSteps ?? 0,
      showPhotoSummary: photoCount > 0 || hasPhotoSteps,
      finishedAt: summary?.run.finishedAt ?? session?.completedAt,
      photos: [
        for (final proof in proofs)
          CompletionPhoto(
            id: proof.proofId,
            load: () => proofStorage.resolveProofAssetFile(proof),
          ),
      ],
      storage: CompletionStorage.fromSyncStatus(summary?.run.syncStatus),
      completionEmailNote: _completionEmailNote,
      haptics: settings.stepCompleteHaptic,
      onLanded: settings.stepCompleteSound ? _playCompletionSound : null,
      onOpenPhoto: (index) => _openRunPhotos(proofs, index),
      onBackToHome: _goHome,
      onReviewRoutine: _openVault,
    );
  }

  Future<void> _openRunPhotos(
    List<RoutineSessionProofAsset> proofs,
    int initialIndex,
  ) async {
    if (proofs.isEmpty || !mounted) return;
    final proofStorage = ref.read(routineSessionProofStorageProvider);
    await PebblePhotoGalleryViewer.open(
      context,
      photos: [
        for (var i = 0; i < proofs.length; i++)
          PebbleGalleryPhoto(
            id: proofs[i].proofId,
            storedPath: proofs[i].localRelativePath,
            title: 'Photo ${i + 1} of ${proofs.length}',
          ),
      ],
      initialIndex: initialIndex.clamp(0, proofs.length - 1),
      resolvePhotoFile: (storedPath) async {
        for (final asset in proofs) {
          if (asset.localRelativePath == storedPath) {
            return proofStorage.resolveProofAssetFile(asset);
          }
        }
        return proofStorage.resolveStoredFile(storedPath);
      },
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    ThemeData themeData,
    RoutinePlayerUiState playerState,
  ) {
    final currentStep = playerState.currentStep;
    final session = playerState.session;
    if (currentStep == null || session == null) {
      return _PlayerStatusView(
        title: 'Routine unavailable',
        message: 'We could not find the current step.',
        icon: LucideIcons.circleAlert,
        primaryLabel: 'Back to Home',
        onPrimary: _goHome,
        topAction: _TopBackButton(onBack: _attemptExit),
      );
    }

    final proofStorage = ref.read(routineSessionProofStorageProvider);
    final guidanceAudioStorage = ref.read(guidanceAudioStorageProvider);
    final premiumPolicy = ref.watch(premiumFeaturePolicyProvider);
    final playerSettings = ref.read(playerSettingsControllerProvider);
    final canAddMore = playerState.canAddMorePhotos;
    final isStepLocked = playerState.isCurrentStepLocked;
    final readyPhase =
        playerState.screenPhase == RoutinePlayerScreenPhase.ready;
    // Shown by photo count, not by canAddMore, so a photo save in progress
    // doesn't blink the footer; the capture itself refuses while busy.
    final showGalleryAction =
        readyPhase &&
        playerState.hasPhotoRequirement &&
        currentStep.allowGallery &&
        !isStepLocked &&
        playerState.capturedPhotoCount < playerState.maxProofPhotosPerStep;
    // The proof-photo card is part of the step itself and shows from the start.
    // The first photo is the requirement; any later photos are optional.
    final showPhotoSummary = playerState.hasPhotoRequirement;
    final isFreeTier = !premiumPolicy.canUseExtraProofPhotos;
    final showRing =
        playerSettings.showVisualAnchor &&
        !playerState.hasPhotoRequirement &&
        !isStepLocked;
    final type = PebbleType.of(context);
    final instructionStyle = type.step.copyWith(
      color: themeData.colorScheme.onSurface,
    );

    final photoSummary = showPhotoSummary && !isStepLocked
        ? _PlayerPhotoSummary(
            proofAssets: playerState.proofAssets,
            capturedPhotoCount: playerState.capturedPhotoCount,
            maxPhotoCount: playerState.maxProofPhotosPerStep,
            isFreeTier: isFreeTier,
            resolveProofPath: proofStorage.resolveStoredPath,
            // The empty frame is a convenient duplicate of the placed,
            // reliable primary camera action.
            onAddPhoto: canAddMore ? _captureCameraPhoto : null,
            onOpenPhoto: _openCurrentStepProofGallery,
            onPhotoLimitUpgrade: isFreeTier ? _openProofPhotoLimitPaywall : null,
            onRemovePhoto: !playerState.isForegroundBusy
                ? (proofId) async {
                    await ref
                        .read(routinePlayerProvider(widget.sessionId).notifier)
                        .removeProof(proofId);
                  }
                : null,
          )
        : null;
    final guidanceAudioCard =
        currentStep.guidanceAudio != null && !isStepLocked
        ? _PlayerGuidanceAudioCard(
            audio: currentStep.guidanceAudio!,
            storage: guidanceAudioStorage,
          )
        : null;

    final incoming = Column(
      key: ValueKey('routine-player-step-${playerState.currentStepIndex}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStepLocked) ...[
          _LockedStepBoundaryBanner(
            lockedStepCount: playerState.lockedStepCount,
          ),
          const SizedBox(height: PebbleSpacing.xl),
        ],
        ImageFiltered(
          enabled: isStepLocked,
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
          child: Opacity(
            opacity: isStepLocked ? 0.30 : 1,
            child: Text(
              _stepInstruction(currentStep),
              textAlign: TextAlign.center,
              style: instructionStyle,
            ),
          ),
        ),
        // Guidance audio sits above the proof card: it tells you how to do
        // the step, the photos record what you did. Keeping it here also
        // means a growing photo mosaic never pushes the recording out of
        // sight.
        if (guidanceAudioCard != null) ...[
          const SizedBox(height: PebbleSpacing.xl),
          guidanceAudioCard,
        ],
        if (photoSummary != null) ...[
          SizedBox(
            height: guidanceAudioCard != null
                ? PebbleSpacing.md
                : PebbleSpacing.xl,
          ),
          photoSummary,
        ],
      ],
    );

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final outgoing = _outgoing;
    final stage = AnimatedBuilder(
      animation: _checkOff,
      builder: (context, _) {
        final timeline = outgoing == null
            ? null
            : CheckOffTimeline(_checkOff.value, reduced: _checkOffReduced);
        return CheckOffStage(
          incoming: incoming,
          incomingRing: showRing,
          instructionStyle: instructionStyle,
          outgoing: outgoing,
          timeline: timeline,
        );
      },
    );
    final trail = AnimatedBuilder(
      animation: _checkOff,
      builder: (context, _) {
        final timeline = outgoing == null
            ? null
            : CheckOffTimeline(_checkOff.value, reduced: _checkOffReduced);
        return StepTrail(
          entries: _trailEntries(session, including: outgoing?.stepIndex),
          revealing: outgoing?.stepIndex,
          reveal: timeline?.trailReveal ?? 1,
          revealOpacity: timeline?.trailOpacity ?? 1,
          visibleRows: textScale >= 1.6 ? 1 : 2,
          maxExpandedHeight: MediaQuery.sizeOf(context).height * 0.4,
        );
      },
    );

    // The footer never flickers through "Saving" for a step save: the check
    // is already on screen, and the save takes a few milliseconds.
    final operation = playerState.activeOperation;
    final holdingFinal = outgoing?.isFinal == true;
    final savingStep = operation == RoutinePlayerOperation.savingStep;
    // While a required photo is missing the primary button is the camera.
    final primaryIsCamera =
        !holdingFinal && !savingStep && playerState.primaryActionIsPhotoCapture;
    final looksEnabled =
        isStepLocked ||
        holdingFinal ||
        primaryIsCamera ||
        (readyPhase &&
            playerState.hasEnoughPhotos &&
            (operation == RoutinePlayerOperation.none || savingStep));
    final primaryLabel = isStepLocked
        ? 'Upgrade to reactivate'
        : holdingFinal
        ? 'Finish routine'
        : savingStep
        ? (playerState.isFinalStep ? 'Finish routine' : 'Complete step')
        : playerState.primaryLabel;
    final isBusy = !holdingFinal && !savingStep && playerState.isPrimaryBusy;

    return _RoutineStepSurface(
      routineName: session.routineTitleSnapshot,
      stepIndex: playerState.currentStepIndex,
      stepCount: playerState.totalSteps,
      progress: playerState.progress,
      trail: trail,
      stage: stage,
      isBusy: isBusy,
      primaryLabel: primaryLabel,
      primaryIcon: primaryIsCamera ? LucideIcons.camera : null,
      isPrimaryEnabled: looksEnabled,
      onBack: _attemptExit,
      onComplete: isStepLocked ? _openStepLimitPaywall : _handlePrimaryAction,
      secondaryActions: _PlayerSecondaryActionRow(
        // Visibility is stable through the few-ms step save so the row never
        // flickers; the handlers re-check canGoBack / canSkip on tap.
        showPrevious: readyPhase && playerState.currentStepIndex > 0,
        onPrevious: _handlePrevious,
        // Gallery stays in the stable footer row for as long as another photo
        // can be added, without growing the proof card with extra copy.
        showChooseFromGallery: showGalleryAction,
        onChooseFromGallery: _captureGalleryPhoto,
        showSkip: readyPhase && currentStep.canSkip && !isStepLocked,
        onSkip: _handleSkip,
      ),
    );
  }

  List<StepTrailEntry> _trailEntries(RoutineSession session, {int? including}) {
    final entries = <StepTrailEntry>[];
    for (final stepState in session.stepStates) {
      if (stepState.status == SessionStepStatus.pending) continue;
      final index = stepState.stepIndex;
      if (index < 0 || index >= session.routineSnapshotSteps.length) continue;
      if (index >= session.currentStepIndex && index != including) continue;
      final at = stepState.completedAt;
      entries.add(
        StepTrailEntry(
          stepIndex: index,
          label: _stepTitle(session.routineSnapshotSteps[index]),
          timeLabel: at == null ? null : formatCheckTime(context, at),
          skipped: stepState.status == SessionStepStatus.skipped,
        ),
      );
    }
    entries.sort((a, b) => a.stepIndex.compareTo(b.stepIndex));
    return entries;
  }

  /// While a required photo is missing the primary button IS the camera, so
  /// the thumb never has to leave the bottom of the screen mid-run. No
  /// check-off motion then: the step isn't done yet. Once the requirement is
  /// met, the same button checks the step off.
  Future<void> _handlePrimaryAction() async {
    if (_inputGuarded) {
      return;
    }
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    if (state.primaryActionIsPhotoCapture) {
      await _capturePhoto(ImageSource.camera);
      return;
    }
    await _checkOffCurrentStep(skipped: false);
  }

  Future<void> _handleSkip() => _checkOffCurrentStep(skipped: true);

  Future<void> _handlePrevious() async {
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    if (!state.canGoBack || _inputGuarded) {
      return;
    }
    _finishRunningCheckOff();
    setState(() {});
    await ref
        .read(routinePlayerProvider(widget.sessionId).notifier)
        .previousStep();
  }

  /// Moment 1: commit first, then play the motion over the saved state.
  ///
  /// The step is saved the instant it is tapped (the time shown is the time
  /// stored). The motion never blocks: taps within [CheckOffTimeline
  /// .inputGuard] are dropped so a double tap checks one step, and a later
  /// tap jumps the running motion to its end. Nothing is ever queued.
  Future<void> _checkOffCurrentStep({required bool skipped}) async {
    if (_inputGuarded) {
      return;
    }
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    final step = state.currentStep;
    if (step == null || state.session == null) {
      return;
    }
    // A check needs the step's photo requirement met. While a required photo
    // is missing the primary tap is routed to the camera instead (see
    // [_handlePrimaryAction]), so it never reaches here.
    if (skipped
        ? !state.canSkip
        : !state.isPrimaryEnabled || state.primaryActionIsPhotoCapture) {
      return;
    }

    final at = DateTime.now();
    final reduced = _reduceMotion();
    final label = _stepTitle(step);
    final timeLabel = formatCheckTime(context, at);
    final playerSettings = ref.read(playerSettingsControllerProvider);
    final isFinal = state.isFinalStep;

    _finishRunningCheckOff();
    setState(() {
      _outgoing = CheckedStepSnapshot(
        stepIndex: state.currentStepIndex,
        instruction: _stepInstruction(step),
        timeLabel: timeLabel,
        skipped: skipped,
        hadRing:
            playerSettings.showVisualAnchor &&
            !state.hasPhotoRequirement &&
            !state.isCurrentStepLocked,
        isFinal: isFinal,
      );
      _checkOffReduced = reduced;
      _inputGuarded = true;
      _holdCompletion = isFinal;
    });
    _checkOff.duration = reduced
        ? CheckOffTimeline.reducedDuration
        : CheckOffTimeline.duration;
    unawaited(_checkOff.forward(from: 0));
    _scheduleCheckOff(CheckOffTimeline.inputGuard, () {
      setState(() => _inputGuarded = false);
    });
    if (isFinal) {
      _scheduleCheckOff(
        reduced ? CheckOffTimeline.reducedDuration : CheckOffTimeline.finalHold,
        () => setState(() => _holdCompletion = false),
      );
    }
    // A skip gets no stroke and no buzz: the run stays honest.
    if (!skipped) {
      _playCheckFeedback();
    }
    _announce(skipped ? '$label, skipped.' : '$label, checked at $timeLabel.');

    final controller = ref.read(
      routinePlayerProvider(widget.sessionId).notifier,
    );
    final run = skipped
        ? await controller.skipCurrentStep(at: at)
        : await controller.completeCurrentStep(at: at);
    await _handlePostCompletion(run);
  }

  Future<void> _captureCameraPhoto() {
    return _capturePhoto(ImageSource.camera);
  }

  Future<void> _captureGalleryPhoto() {
    return _capturePhoto(ImageSource.gallery);
  }

  Future<void> _openCurrentStepProofGallery(String proofId) async {
    final playerState = ref.read(routinePlayerProvider(widget.sessionId));
    final proofs = playerState.proofAssets;
    if (proofs.isEmpty || !mounted) {
      return;
    }

    final initialIndex = proofs.indexWhere((asset) => asset.proofId == proofId);
    if (initialIndex < 0) {
      return;
    }

    final stepTitle = playerState.currentStep == null
        ? 'Proof photo'
        : _stepTitle(playerState.currentStep!);
    final photos = [
      for (var index = 0; index < proofs.length; index += 1)
        PebbleGalleryPhoto(
          id: proofs[index].proofId,
          storedPath: proofs[index].localRelativePath,
          title: proofs.length == 1
              ? 'Proof photo'
              : 'Proof photo ${index + 1}',
          subtitle:
              '$stepTitle - Step ${playerState.currentStepIndex + 1} of ${playerState.totalSteps}',
        ),
    ];
    final proofStorage = ref.read(routineSessionProofStorageProvider);
    await PebblePhotoGalleryViewer.open(
      context,
      photos: photos,
      initialIndex: initialIndex,
      resolvePhotoFile: (storedPath) async {
        for (final asset in proofs) {
          if (asset.localRelativePath == storedPath) {
            return proofStorage.resolveProofAssetFile(asset);
          }
        }
        return proofStorage.resolveStoredFile(storedPath);
      },
    );
  }

  /// Always resolve the notifier fresh: the player provider can rebuild while
  /// the camera is open (any watched policy change disposes the old
  /// controller), and calls on a stale reference are silently dropped in
  /// release builds.
  RoutinePlayerController get _playerController =>
      ref.read(routinePlayerProvider(widget.sessionId).notifier);

  Future<void> _capturePhoto(ImageSource source) async {
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    final step = state.currentStep;
    if (step == null || !_playerController.beginPhotoCapture()) {
      return;
    }

    try {
      if (source == ImageSource.gallery && !step.allowGallery) {
        _playerController.cancelPhotoCapture();
        return;
      }

      final acceptedPrompt = await _showPhotoPermissionRationale(source);
      if (!acceptedPrompt) {
        _playerController.cancelPhotoCapture();
        return;
      }

      if (source == ImageSource.camera) {
        await _markPendingCameraCapture(state);
      }

      final picked = await ref
          .read(routinePlayerPhotoPickerProvider)
          .pickImage(source: source, imageQuality: 50, maxWidth: 800);
      if (picked == null) {
        if (source == ImageSource.camera) {
          await _clearPendingCameraCapture();
        }
        _playerController.cancelPhotoCapture();
        return;
      }

      final attachResult = await _playerController.attachProof(picked.path);
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      unawaited(_deletePickerTemp(picked.path));
      // Save failures already surface their own error toast; only a real
      // limit should show the limit message.
      if (attachResult == RoutinePlayerProofAttachResult.limitReached &&
          mounted) {
        _showPhotoLimitReachedMessage();
      }
    } on PlatformException catch (error) {
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      _playerController.cancelPhotoCapture();
      _showPhotoCaptureFailure(source, error.code);
    } catch (_) {
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      _playerController.cancelPhotoCapture();
      _showPhotoCaptureFailure(source, null);
    }
  }

  Future<void> _markPendingCameraCapture(RoutinePlayerUiState state) async {
    final session = state.session;
    if (session == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingCameraCapturePrefsKey,
      jsonEncode({
        'sessionId': session.sessionId,
        'stepIndex': state.currentStepIndex,
        'capturedPhotoCount': state.capturedPhotoCount,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<_PendingCameraCapture?> _readPendingCameraCapture() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingCameraCapturePrefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _clearPendingCameraCapture();
        return null;
      }
      final pending = _PendingCameraCapture.fromJson(decoded);
      final age = DateTime.now().toUtc().difference(pending.createdAt);
      if (age > const Duration(hours: 1)) {
        await _clearPendingCameraCapture();
        return null;
      }
      return pending;
    } catch (_) {
      await _clearPendingCameraCapture();
      return null;
    }
  }

  Future<void> _clearPendingCameraCapture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCameraCapturePrefsKey);
  }

  /// The picker writes captures to the app cache; once the proof is copied
  /// into app storage (or discarded), the cache copy is just a leftover.
  Future<void> _deletePickerTemp(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup is best-effort.
    }
  }

  void _showPhotoCaptureFailure(ImageSource source, String? code) {
    if (!mounted) {
      return;
    }
    switch (code) {
      case 'camera_access_denied':
        ZenNotifications.showWarning(
          context,
          message:
              'Camera access is turned off for Pebble. '
              'Allow camera in your phone settings to take photos.',
          actionLabel: 'Open settings',
          onAction: () => unawaited(permissions.openAppSettings()),
        );
      case 'photo_access_denied':
        ZenNotifications.showWarning(
          context,
          message:
              'Photos access is turned off for Pebble. '
              'Allow photo access in your phone settings to choose a photo.',
          actionLabel: 'Open settings',
          onAction: () => unawaited(permissions.openAppSettings()),
        );
      default:
        ZenNotifications.showError(
          context,
          message: source == ImageSource.camera
              ? 'Could not open the camera. Please try again.'
              : 'Could not open your photos. Please try again.',
        );
    }
  }

  Future<bool> _showPhotoPermissionRationale(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final isCamera = source == ImageSource.camera;
    final prefsKey = isCamera
        ? 'has_seen_camera_rationale'
        : 'has_seen_gallery_rationale';

    if (prefs.getBool(prefsKey) == true) {
      return true;
    }

    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isCamera ? 'Use camera?' : 'Choose from Photos?'),
          content: Text(
            isCamera
                ? 'Pebble uses the camera only when you choose to capture a proof photo for this routine step.'
                : 'Pebble opens Photos only when you choose an existing image as a proof photo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await prefs.setBool(prefsKey, true);
    }

    return result == true;
  }

  void _showPhotoLimitReachedMessage() {
    final isFreeTier = !ref
        .read(premiumFeaturePolicyProvider)
        .canUseExtraProofPhotos;
    ZenNotifications.showWarning(
      context,
      message: isFreeTier
          ? 'Pebble Free includes one proof photo per step.'
          : 'Maximum photos added for this step.',
      actionLabel: isFreeTier ? 'Plus' : null,
      onAction: isFreeTier ? _openProofPhotoLimitPaywall : null,
    );
  }

  void _openProofPhotoLimitPaywall() {
    GoRouter.of(
      context,
    ).push(premiumRoute(source: PremiumEntrySource.proofPhotoLimit));
  }

  Future<void> _openStepLimitPaywall() async {
    unawaited(
      GoRouter.of(
        context,
      ).push(premiumRoute(source: PremiumEntrySource.stepLimit)),
    );
  }

  Future<void> _handlePostCompletion(RoutineRun? run) async {
    if (run == null) {
      return;
    }
    await _enqueueSharedReminderIfNeeded(run);
  }

  Future<void> _enqueueSharedReminderIfNeeded(RoutineRun run) async {
    if (_lastReminderSentRunId == run.id) {
      return;
    }
    if (!ref.read(premiumFeaturePolicyProvider).canUseSharedAlerts) {
      _lastReminderSentRunId = run.id;
      return;
    }
    final playerState = ref.read(routinePlayerProvider(widget.sessionId));
    final session = playerState.session;
    if (session == null) {
      return;
    }
    final sharedReminders = ref.read(
      sharedReminderPreferencesRepositoryProvider,
    );
    try {
      final routine = await ref
          .read(localDbProvider)
          .routineDao
          .getRoutineById(session.routineId);
      final result = await sharedReminders.sendCompletionReminder(
        routineId: session.routineId,
        routineCloudId: routine?.cloudId,
        routineTitle: session.routineTitleSnapshot,
        runId: run.id,
        sessionId: session.sessionId,
        completedAt: session.completedAt ?? DateTime.now(),
        completedSteps: session.completedStepsCount,
        totalSteps: session.totalStepCount,
      );
      if (mounted) {
        setState(() => _completionEmailNote = result.completionScreenNote);
      }
    } catch (_) {
      // Shared emails should never make a completed routine feel unfinished.
    } finally {
      _lastReminderSentRunId = run.id;
    }
  }

  void _openVault() {
    final summary = ref
        .read(routinePlayerProvider(widget.sessionId))
        .completionSummary;
    if (summary == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineRunDetailScreen(run: summary.run),
      ),
    );
  }

  void _goHome() {
    ref.read(navIndexProvider.notifier).state = 0;
    GoRouter.of(context).go('/');
  }

  Future<void> _attemptExit() async {
    final playerState = ref.read(routinePlayerProvider(widget.sessionId));
    if (playerState.isForegroundBusy) {
      return;
    }

    final action = await showModalBottomSheet<_RoutineExitAction>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final themeData = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: themeData.colorScheme.onSurface.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Leave routine?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: themeData.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your progress is saved and ready to resume.',
                  style: TextStyle(
                    fontSize: 15,
                    color: themeData.colorScheme.onSurface.withValues(
                      alpha: 0.68,
                    ),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                PebbleButton.primary(
                  onPressed: () =>
                      Navigator.pop(context, _RoutineExitAction.leaveAndSave),
                  label: 'Leave and save',
                ),
                const SizedBox(height: PebbleSpacing.sm),
                PebbleButton.secondary(
                  onPressed: () =>
                      Navigator.pop(context, _RoutineExitAction.stay),
                  label: 'Stay here',
                ),
                const SizedBox(height: PebbleSpacing.xs),
                PebbleButton.destructive(
                  expand: true,
                  onPressed: () =>
                      Navigator.pop(context, _RoutineExitAction.discard),
                  label: 'Discard progress',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null || action == _RoutineExitAction.stay) {
      return;
    }

    final controller = ref.read(
      routinePlayerProvider(widget.sessionId).notifier,
    );
    if (action == _RoutineExitAction.leaveAndSave) {
      await controller.persistCurrentProgress();
    } else if (action == _RoutineExitAction.discard) {
      await controller.discardSession();
    }

    if (mounted) {
      // When launched from the home-screen widget or a notification tap, the
      // player is the root of the stack (go() replaced it); popping the last
      // route would leave an empty navigator behind - a black screen that
      // survives re-opening the app. Fall back to Home instead.
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        _goHome();
      }
    }
  }

  String _stepTitle(RoutineStep step) {
    return step.maybeWhen(
      check: (label, _, _, _, _, _, _) => label,
      info: (message) => message,
      timer: (_) => 'Pause',
      orElse: () => 'Step',
    );
  }

  String _stepInstruction(RoutineStep step) {
    final body = _stepBody(step);
    if (body != null && body.isNotEmpty) {
      return body;
    }
    return _stepTitle(step);
  }

  String? _stepBody(RoutineStep step) {
    return step.maybeWhen(
      check: (_, __, ___, ____, _____, ______, _______) => null,
      info: (_) => null,
      timer: (duration) {
        final minutes = Duration(seconds: duration).inMinutes;
        if (minutes > 0) {
          return 'Pause for $minutes minute${minutes == 1 ? '' : 's'}.';
        }
        return 'Pause briefly before continuing.';
      },
      orElse: () => null,
    );
  }
}

class _PendingCameraCapture {
  const _PendingCameraCapture({
    required this.sessionId,
    required this.stepIndex,
    required this.capturedPhotoCount,
    required this.createdAt,
  });

  final String sessionId;
  final int stepIndex;
  final int capturedPhotoCount;
  final DateTime createdAt;

  factory _PendingCameraCapture.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (createdAt == null) {
      throw const FormatException('Missing pending capture timestamp.');
    }
    return _PendingCameraCapture(
      sessionId: json['sessionId']?.toString() ?? '',
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? -1,
      capturedPhotoCount: (json['capturedPhotoCount'] as num?)?.toInt() ?? -1,
      createdAt: createdAt.toUtc(),
    );
  }
}

class _RoutineStepSurface extends StatelessWidget {
  const _RoutineStepSurface({
    required this.routineName,
    required this.stepIndex,
    required this.stepCount,
    required this.progress,
    required this.trail,
    required this.stage,
    required this.isBusy,
    required this.primaryLabel,
    this.primaryIcon,
    required this.isPrimaryEnabled,
    required this.onBack,
    required this.onComplete,
    required this.secondaryActions,
  });

  final String routineName;
  final int stepIndex;
  final int stepCount;
  final double progress;
  final Widget trail;
  final Widget stage;
  final bool isBusy;
  final String primaryLabel;
  final IconData? primaryIcon;
  final bool isPrimaryEnabled;
  final Future<void> Function() onBack;
  final Future<void> Function() onComplete;
  final Widget secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final type = PebbleType.of(context);
    final gutter = PebbleSpacing.gutter(MediaQuery.sizeOf(context).width);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
          child: Row(
            children: [
              _TopBackButton(onBack: onBack),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: PebbleRadius.pillAll,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : PebbleMotion.emphasized,
                    curve: PebbleMotion.emphasizedCurve,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, PebbleSpacing.md, gutter, 0),
          child: Semantics(
            header: true,
            label: '$routineName, step ${stepIndex + 1} of $stepCount',
            excludeSemantics: true,
            child: Text(
              '$routineName · ${stepIndex + 1} of $stepCount',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.caption.copyWith(
                color: context.readableSecondaryText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, PebbleSpacing.sm, gutter, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: trail,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                PebbleSpacing.md,
                gutter,
                PebbleSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    // AnimatedSize can't run at zero duration, so Reduce
                    // Motion simply skips it.
                    child: MediaQuery.disableAnimationsOf(context)
                        ? stage
                        : AnimatedSize(
                            duration: PebbleMotion.standard,
                            curve: PebbleMotion.enter,
                            alignment: Alignment.topCenter,
                            child: stage,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _RoutineStepFooter(
          isBusy: isBusy,
          primaryLabel: primaryLabel,
          primaryIcon: primaryIcon,
          isPrimaryEnabled: isPrimaryEnabled,
          onComplete: onComplete,
          secondaryActions: secondaryActions,
        ),
      ],
    );
  }
}

class _LockedStepBoundaryBanner extends StatelessWidget {
  const _LockedStepBoundaryBanner({required this.lockedStepCount});

  final int lockedStepCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = lockedStepCount <= 0 ? 1 : lockedStepCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.lock, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '+$count more step${count == 1 ? '' : 's'} locked. Upgrade to reactivate.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineStepFooter extends StatelessWidget {
  const _RoutineStepFooter({
    required this.isBusy,
    required this.primaryLabel,
    this.primaryIcon,
    required this.isPrimaryEnabled,
    required this.onComplete,
    required this.secondaryActions,
  });

  final bool isBusy;
  final String primaryLabel;
  final IconData? primaryIcon;
  final bool isPrimaryEnabled;
  final Future<void> Function() onComplete;
  final Widget secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PebbleButton.primary(
                label: primaryLabel,
                icon: primaryIcon,
                busy: isBusy,
                onPressed: isPrimaryEnabled
                    ? () => unawaited(onComplete())
                    : null,
              ),
              const SizedBox(height: 8),
              // Always reserve the secondary row, so the primary button
              // never moves between steps with and without Previous/Skip.
              Container(
                constraints: const BoxConstraints(
                  minHeight: PebbleButton.tertiaryHeight,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: secondaryActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBackButton extends StatelessWidget {
  const _TopBackButton({required this.onBack});

  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => unawaited(onBack()),
        icon: const Icon(LucideIcons.chevronLeft),
        tooltip: 'Back',
      ),
    );
  }
}

class _PlayerGuidanceAudioCard extends StatelessWidget {
  const _PlayerGuidanceAudioCard({required this.audio, required this.storage});

  final StepGuidanceAudio audio;
  final GuidanceAudioStorage storage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final leading = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
      ),
      child: Icon(
        LucideIcons.volume2,
        size: 19,
        color: theme.colorScheme.primary,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice tip',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'A short reminder for this step',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: context.readableSecondaryText,
          ),
        ),
      ],
    );
    final playButton = GuidanceAudioPlayButton(
      audio: audio,
      storage: storage,
      compact: true,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onSurface.withValues(alpha: 0.06)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: playButton),
              ],
            );
          }
          return Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: copy),
              const SizedBox(width: 10),
              playButton,
            ],
          );
        },
      ),
    );
  }
}

/// A calm proof-photo card with one clear requirement and optional capacity.
/// Empty cells are never used to advertise Premium, so the mosaic always reads
/// as a collection of photos already taken rather than an unfinished form.
class _PlayerPhotoSummary extends StatelessWidget {
  const _PlayerPhotoSummary({
    required this.proofAssets,
    required this.capturedPhotoCount,
    required this.maxPhotoCount,
    required this.isFreeTier,
    required this.resolveProofPath,
    this.onAddPhoto,
    this.onOpenPhoto,
    this.onRemovePhoto,
    this.onPhotoLimitUpgrade,
  });

  final List<RoutineSessionProofAsset> proofAssets;
  final int capturedPhotoCount;
  final int maxPhotoCount;
  final bool isFreeTier;
  final Future<String> Function(String storedPath) resolveProofPath;
  final Future<void> Function()? onAddPhoto;
  final Future<void> Function(String proofId)? onOpenPhoto;
  final Future<void> Function(String proofId)? onRemovePhoto;
  final VoidCallback? onPhotoLimitUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final hasPhotos = capturedPhotoCount > 0;
    final atMax = capturedPhotoCount >= maxPhotoCount;
    final subtitle = hasPhotos
        ? '$capturedPhotoCount photo${capturedPhotoCount == 1 ? '' : 's'} added'
        : 'Add one photo to complete this step';
    final subtitleColor = hasPhotos
        ? context.readableSecondaryText
        : context.readableAccentText(theme.colorScheme.primary);

    // Only captured photos are shown. Before the first capture there is one
    // full-size invitation; optional Premium capacity is never represented as
    // empty cells, so it cannot be mistaken for work the user still owes.
    final cells = <Widget>[
      for (var index = 0; index < proofAssets.length; index += 1)
        _ProofPhotoCell(
          key: ValueKey('proof-${proofAssets[index].proofId}'),
          asset: proofAssets[index],
          reduceMotion: reduceMotion,
          resolveProofPath: resolveProofPath,
          onOpen: onOpenPhoto == null
              ? null
              : () => onOpenPhoto!(proofAssets[index].proofId),
          onRemove: onRemovePhoto == null
              ? null
              : () => onRemovePhoto!(proofAssets[index].proofId),
          openSemanticLabel:
              'Open proof photo ${index + 1} of $capturedPhotoCount',
          removeSemanticLabel: 'Remove proof photo ${index + 1}',
        ),
      if (!hasPhotos) _ProofSlotCell(onTap: onAddPhoto),
    ];

    final showCaptureAction = hasPhotos && !atMax && onAddPhoto != null;
    final showUpgradeAction =
        isFreeTier &&
        hasPhotos &&
        capturedPhotoCount < 4 &&
        onPhotoLimitUpgrade != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasPhotos
              ? onSurface.withValues(alpha: 0.06)
              : theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    capturedPhotoCount > 1 ? 'Proof photos' : 'Proof photo',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                ),
                if (showCaptureAction)
                  _ProofPhotoHeaderAction.capture(onTap: onAddPhoto!)
                else if (showUpgradeAction)
                  _ProofPhotoHeaderAction.upgrade(onTap: onPhotoLimitUpgrade!),
              ],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 13),
          _ProofCollage(cells: cells),
        ],
      ),
    );
  }
}

class _ProofPhotoHeaderAction extends StatelessWidget {
  const _ProofPhotoHeaderAction._({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isUpgrade,
  });

  factory _ProofPhotoHeaderAction.capture({
    required Future<void> Function() onTap,
  }) {
    return _ProofPhotoHeaderAction._(
      label: 'Add photo',
      icon: LucideIcons.plus,
      onTap: () => unawaited(onTap()),
      isUpgrade: false,
    );
  }

  factory _ProofPhotoHeaderAction.upgrade({required VoidCallback onTap}) {
    return _ProofPhotoHeaderAction._(
      label: 'Add more',
      icon: LucideIcons.lock,
      onTap: onTap,
      isUpgrade: true,
    );
  }

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isUpgrade
        ? context.readableSecondaryText
        : context.readableAccentText(theme.colorScheme.primary);
    return Semantics(
      button: true,
      onTap: onTap,
      label: isUpgrade
          ? 'Add more proof photos with Premium'
          : 'Add another proof photo',
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 15),
          label: Text(label),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: foreground,
            backgroundColor: foreground.withValues(alpha: 0.07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: PebbleFonts.sans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Arranges proof cells into a mosaic of stable overall height: one hero frame
/// for a single photo, halves for two, a hero plus a stacked pair for three,
/// and a quartered grid for four. The height responds to available width but
/// stays fixed while photos land, so the surrounding player does not jump.
class _ProofCollage extends StatelessWidget {
  const _ProofCollage({required this.cells});

  static const double _gap = 8;

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 0.58).clamp(156.0, 208.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: _layout(),
        );
      },
    );
  }

  Widget _layout() {
    switch (cells.length) {
      case 1:
        return cells[0];
      case 2:
        return Row(
          children: [
            Expanded(child: cells[0]),
            const SizedBox(width: _gap),
            Expanded(child: cells[1]),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(flex: 3, child: cells[0]),
            const SizedBox(width: _gap),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: cells[1]),
                  const SizedBox(height: _gap),
                  Expanded(child: cells[2]),
                ],
              ),
            ),
          ],
        );
      default:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cells[0]),
                  const SizedBox(width: _gap),
                  Expanded(child: cells[1]),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cells[2]),
                  const SizedBox(width: _gap),
                  Expanded(child: cells[3]),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// A captured proof filling its mosaic cell, with a scrim remove button.
/// Animates in with a scale-fade unless reduced-motion is on.
class _ProofPhotoCell extends StatelessWidget {
  const _ProofPhotoCell({
    super.key,
    required this.asset,
    required this.reduceMotion,
    required this.resolveProofPath,
    required this.openSemanticLabel,
    required this.removeSemanticLabel,
    this.onOpen,
    this.onRemove,
  });

  final RoutineSessionProofAsset asset;
  final bool reduceMotion;
  final Future<String> Function(String storedPath) resolveProofPath;
  final String openSemanticLabel;
  final String removeSemanticLabel;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cell = Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FutureBuilder<String>(
              future: resolveProofPath(asset.localRelativePath),
              builder: (context, snapshot) {
                final path = snapshot.data;
                final file = path == null ? null : File(path);
                final exists = file != null && file.existsSync();
                return ExcludeSemantics(
                  child: exists
                      ? Image.file(file, fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            LucideIcons.imageOff,
                            size: 22,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
        if (onOpen != null)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: openSemanticLabel,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => unawaited(onOpen!()),
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Semantics(
                button: true,
                label: removeSemanticLabel,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => unawaited(onRemove!()),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.inverseSurface.withValues(
                            alpha: 0.72,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.x,
                          size: 14,
                          color: theme.colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (reduceMotion) {
      return cell;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.94 + (0.06 * t), child: child),
        );
      },
      child: cell,
    );
  }
}

/// An empty frame for a photo the step still needs, drawn as a dashed outline
/// at full cell size so the card shows the shape of what is being collected.
class _ProofSlotCell extends StatelessWidget {
  const _ProofSlotCell({this.onTap});

  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: accent.withValues(alpha: 0.34),
        radius: 14,
      ),
      child: Semantics(
        button: onTap != null,
        label: 'Take a proof photo',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap == null ? null : () => unawaited(onTap!()),
            child: Center(
              child: Icon(
                LucideIcons.camera,
                size: 24,
                color: accent.withValues(alpha: 0.48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint dashed rounded-rect outline for empty proof frames.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _PlayerSecondaryActionRow extends StatelessWidget {
  const _PlayerSecondaryActionRow({
    required this.showPrevious,
    required this.showSkip,
    this.onPrevious,
    this.onSkip,
    this.showChooseFromGallery = false,
    this.onChooseFromGallery,
  });

  final bool showPrevious;
  final bool showSkip;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onSkip;

  /// Gallery pick lives down here beside the primary button, not up in the
  /// photo card: on a photo step the hand is already at the bottom of the
  /// screen, and reaching mid-screen for it was the flow-breaker.
  final bool showChooseFromGallery;
  final Future<void> Function()? onChooseFromGallery;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (showPrevious)
        PebbleButton.tertiary(
          onPressed: onPrevious == null ? null : () => unawaited(onPrevious!()),
          icon: LucideIcons.chevronLeft,
          label: 'Previous',
        ),
      if (showChooseFromGallery)
        PebbleButton.tertiary(
          onPressed: onChooseFromGallery == null
              ? null
              : () => unawaited(onChooseFromGallery!()),
          icon: LucideIcons.images,
          label: 'From library',
        ),
      if (showSkip)
        PebbleButton.tertiary(
          onPressed: onSkip == null ? null : () => unawaited(onSkip!()),
          label: 'Skip step',
        ),
    ];

    return Row(
      children: [
        if (actions.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }
}

class _PlayerStatusView extends StatelessWidget {
  const _PlayerStatusView({
    required this.title,
    required this.message,
    required this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.topAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? topAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (topAction != null) topAction!,
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                  if (primaryLabel != null && onPrimary != null) ...[
                    const SizedBox(height: 24),
                    PebbleButton.primary(
                      onPressed: onPrimary,
                      label: primaryLabel!,
                    ),
                  ],
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: PebbleSpacing.xs),
                    PebbleButton.tertiary(
                      onPressed: onSecondary,
                      label: secondaryLabel!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _RoutineExitAction { stay, leaveAndSave, discard }

/// Fade-through between player phases (DESIGN_DIRECTION.md Moment 2): the
/// player fades out over the first 90 ms, the next phase in over the next
/// 210. Reduce Motion gets a 120 ms cross-fade.
class _PhaseSwitcher extends StatelessWidget {
  const _PhaseSwitcher({required this.reduceMotion, required this.child});

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: reduceMotion
          ? PebbleMotion.reduced
          : PebbleMotion.quick + PebbleMotion.quick,
      switchInCurve: reduceMotion
          ? Curves.linear
          : const Interval(0.3, 1, curve: PebbleMotion.enter),
      switchOutCurve: reduceMotion
          ? Curves.linear
          : const Interval(0.7, 1, curve: Curves.easeOut),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
