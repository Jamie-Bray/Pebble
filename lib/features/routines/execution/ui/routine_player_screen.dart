import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
import 'package:pebble_routines/core/share/pebble_share.dart';
import 'package:pebble_routines/core/share/share_messages.dart';
import 'package:pebble_routines/core/ui/readable_colors.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/routine_palette.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/core/theme/tokens.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/ai_photo/ai_photo_settings.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/sync/backup_status.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/execution/ui/player_proof_zone.dart';
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
              // The routine's own colour paints the checks, trail, progress
              // and the completion cairn.
              child: RoutineAccentScope(
                colorHex: playerState.session == null
                    ? null
                    : ref.watch(
                        routineColorHexProvider(playerState.session!.routineId),
                      ),
                child: _buildPhase(context, themeData, playerState, controller),
              ),
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
          title: "Couldn't load this routine",
          message: playerState.errorMessage ?? 'Try again in a moment.',
          icon: LucideIcons.circleAlert,
          primaryLabel: 'Retry',
          onPrimary: () => unawaited(controller.refresh()),
          secondaryLabel: 'Back to home',
          onSecondary: _goHome,
        ),
        RoutinePlayerScreenPhase.empty => _PlayerStatusView(
          title: playerState.session?.routineTitleSnapshot ?? 'Routine',
          message: "This routine doesn't have any steps yet.",
          icon: LucideIcons.listTodo,
          primaryLabel: 'Back to home',
          onPrimary: _goHome,
          topAction: _TopBackButton(onBack: _attemptExit),
        ),
        RoutinePlayerScreenPhase.completion => _buildCompletion(playerState),
        RoutinePlayerScreenPhase.ready || RoutinePlayerScreenPhase.completing =>
          _buildPlayer(context, themeData, playerState),
      },
    );
  }

  Widget _buildCompletion(RoutinePlayerUiState playerState) {
    final summary = playerState.completionSummary;
    final run = summary == null
        ? null
        : ref.watch(routineRunProvider(summary.run.id)).valueOrNull ??
              summary.run;
    final backup = ref.watch(backupStatusProvider);
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
    final ai = playerState.runAiDescriptionCounts;
    return RoutineCompleteScreen(
      aiDescribedCount: ai.described,
      aiDescribingCount: ai.describing,
      routineName:
          summary?.routineTitle ?? session?.routineTitleSnapshot ?? 'Routine',
      routineId: session?.routineId,
      colorHex: session == null
          ? null
          : ref.watch(routineColorHexProvider(session.routineId)),
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
            hasAiDescription: playerState.aiDescriptionFor(proof)?.text != null,
          ),
      ],
      storage: CompletionStorage.fromBackupStatus(run?.syncStatus, backup),
      completionEmailNote: _completionEmailNote,
      haptics: settings.stepCompleteHaptic,
      onLanded: settings.stepCompleteSound ? _playCompletionSound : null,
      onOpenPhoto: (index) => _openRunPhotos(proofs, index),
      onBackToHome: _goHome,
      onReviewRoutine: _openVault,
      onShare: run == null ? null : (button) => _shareRun(button, run),
    );
  }

  /// Hands this run's steps and times to the share sheet. Photos are never
  /// included.
  void _shareRun(BuildContext button, RoutineRun run) {
    final text = ShareMessages.runSummary(
      routineTitle: run.routineTitle,
      finishedAt: run.finishedAt,
      steps: ShareMessages.stepsFromRun(run),
      formatTime: (at) => formatCheckTime(button, at),
    );
    unawaited(ref.read(pebbleShareProvider).shareText(button, text));
  }

  /// The AI description under a photo in the full-screen viewer, kept up
  /// to date while it is on its way.
  Widget _liveCaption(RoutineSessionProofAsset proof) {
    return Consumer(
      builder: (context, ref, _) {
        final description = ref
            .watch(routinePlayerProvider(widget.sessionId))
            .aiDescriptionFor(proof);
        if (description == null) return const SizedBox.shrink();
        return ProofCaptionSlot(
          description: description,
          onRetry: () => _playerController.retryAiDescription(proof.proofId),
        );
      },
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
      captionBuilder: (context, index) => _liveCaption(proofs[index]),
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
        title: "Can't continue this routine",
        message: "Pebble couldn't find the step you were on.",
        icon: LucideIcons.circleAlert,
        primaryLabel: 'Back to home',
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
    final canUseLibrary = canAddMore && currentStep.allowGallery;
    // The proof-photo card is part of the step itself and shows from the start.
    // The first photo is the requirement; any later photos are optional.
    final showPhotoSummary = playerState.hasPhotoRequirement;
    final isFreeTier = !premiumPolicy.canUseExtraProofPhotos;
    final showRing =
        playerSettings.showVisualAnchor &&
        !playerState.hasPhotoRequirement &&
        !isStepLocked;
    final type = PebbleType.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Display type: a little smaller on narrow phones, and it grows with the
    // text-size setting only to 1.25x, so long words stay on one line.
    // Photo steps use a slightly smaller title, so the photo has the room.
    final stepSize =
        (MediaQuery.sizeOf(context).width < 375 ? 32.0 : 38.0) *
        (playerState.hasPhotoRequirement ? 0.84 : 1.0) *
        math.min(1.0, 1.25 / textScale);
    final instructionStyle = type.step.copyWith(
      fontSize: stepSize,
      color: themeData.colorScheme.onSurface,
    );

    final photoSummary = showPhotoSummary && !isStepLocked
        ? PlayerProofZone(
            proofAssets: playerState.proofAssets,
            aiDescriptionFor: playerState.aiDescriptionFor,
            showCaptionSlot: playerState.describesCurrentStep,
            isFreeTier: isFreeTier,
            resolveProofPath: proofStorage.resolveStoredPath,
            // The empty tile is a larger copy of the primary camera button.
            onTakePhoto: canAddMore ? _captureCameraPhoto : null,
            onChooseFromLibrary: canUseLibrary ? _captureGalleryPhoto : null,
            onOpenPhoto: _openCurrentStepProofGallery,
            onPhotoLimitUpgrade: isFreeTier
                ? _openProofPhotoLimitPaywall
                : null,
            onRetryCaption: _playerController.retryAiDescription,
            onRemovePhoto: !playerState.isForegroundBusy
                ? (proofId) async {
                    await ref
                        .read(routinePlayerProvider(widget.sessionId).notifier)
                        .removeProof(proofId);
                  }
                : null,
          )
        : null;
    final guidanceAudioCard = currentStep.guidanceAudio != null && !isStepLocked
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
        if (currentStep.stepDescription != null && !isStepLocked) ...[
          const SizedBox(height: PebbleSpacing.sm),
          _StepDescription(text: currentStep.stepDescription!),
        ],
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
          // A photo step needs the room for its photo, so the trail is one
          // quiet line there ("✓ Front door · 08:12").
          compact: photoSummary != null,
          visibleRows: textScale >= 1.6 || photoSummary != null ? 1 : 2,
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
        ? 'Renew to unlock'
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
      alignTop: playerState.hasPhotoRequirement,
      secondaryActions: _PlayerSecondaryActionRow(
        // Visibility is stable through the few-ms step save so the row never
        // flickers; the handlers re-check canGoBack / canSkip on tap.
        showPrevious: readyPhase && playerState.currentStepIndex > 0,
        onPrevious: _handlePrevious,
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
      captionBuilder: (context, index) => _liveCaption(proofs[index]),
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
              'Camera access is off for Pebble. '
              'Turn it on in your phone settings to take a photo.',
          actionLabel: 'Open settings',
          onAction: () => unawaited(permissions.openAppSettings()),
        );
      case 'photo_access_denied':
        ZenNotifications.showWarning(
          context,
          message:
              'Photo access is off for Pebble. '
              'Turn it on in your phone settings to choose a photo.',
          actionLabel: 'Open settings',
          onAction: () => unawaited(permissions.openAppSettings()),
        );
      default:
        ZenNotifications.showError(
          context,
          message: source == ImageSource.camera
              ? "Couldn't open the camera. Try again."
              : "Couldn't open your photos. Try again.",
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
                ? 'Pebble only uses the camera when you take a photo for a step.'
                : 'Pebble only opens Photos when you pick a photo for a step.',
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
          ? 'Free includes one photo per step.'
          : "That's the most photos this step can hold.",
      actionLabel: isFreeTier ? 'Premium' : null,
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
      // Only when the person chose to add them for this routine. The
      // server filters them again and never emails a photo.
      final ai = ref.read(aiPhotoControllerProvider);
      final descriptions = ai.emailDescriptionsFor(session.routineId)
          ? await _playerController.aiDescriptionsForEmail()
          : const <String>[];
      final result = await sharedReminders.sendCompletionReminder(
        descriptions: descriptions,
        routineId: session.routineId,
        routineCloudId: routine?.cloudId,
        routineTitle: session.routineTitleSnapshot,
        runId: run.id,
        sessionId: session.sessionId,
        completedAt: session.completedAt ?? DateTime.now(),
        completedSteps: session.completedStepsCount,
        totalSteps: session.totalStepCount,
        steps: completionEmailSteps(session),
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

  Future<void> _openVault() async {
    final summary = ref
        .read(routinePlayerProvider(widget.sessionId))
        .completionSummary;
    if (summary == null) {
      return;
    }
    // Read the run again: an AI description can be saved onto it after the
    // routine finished.
    final run =
        await ref
            .read(localDbProvider)
            .routineRunDao
            .getRunById(summary.run.id) ??
        summary.run;
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoutineRunDetailScreen(run: run)),
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
                  'You can save your progress and carry on later, or discard it.',
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
        return 'Take a short pause before the next step.';
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
    this.alignTop = false,
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

  /// Photo steps sit at the top, so the photo area never shifts as
  /// photos and their descriptions arrive.
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final type = PebbleType.of(context);
    final gutter = PebbleSpacing.gutter(MediaQuery.sizeOf(context).width);

    return Column(
      children: [
        // Top bar: leave on the left, the routine and one segment per step
        // in the middle, "2 of 4" on the right. Nothing else up here.
        Padding(
          padding: EdgeInsets.fromLTRB(4, 6, gutter, 0),
          child: Row(
            children: [
              _TopBackButton(
                onBack: onBack,
                icon: LucideIcons.x,
                tooltip: 'Leave routine',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Semantics(
                  header: true,
                  label: '$routineName, step ${stepIndex + 1} of $stepCount',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        routineName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption.copyWith(
                          color: context.readableSecondaryText,
                        ),
                      ),
                      const SizedBox(height: PebbleSpacing.xs),
                      _SegmentedProgress(
                        stepIndex: stepIndex,
                        stepCount: stepCount,
                        complete: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: PebbleSpacing.sm),
              ExcludeSemantics(
                child: Text(
                  '${stepIndex + 1} of $stepCount',
                  style: type.caption.copyWith(
                    color: context.readableSecondaryText,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
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
                child: Align(
                  alignment: alignTop ? Alignment.topCenter : Alignment.center,
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
              '$count more step${count == 1 ? '' : 's'} locked. Renew Premium to unlock ${count == 1 ? 'it' : 'them'}.',
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
  const _TopBackButton({
    required this.onBack,
    this.icon = LucideIcons.chevronLeft,
    this.tooltip = 'Back',
  });

  final Future<void> Function() onBack;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => unawaited(onBack()),
        icon: Icon(icon),
        tooltip: tooltip,
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

/// Under the primary button: Previous on the left, Skip step on the right.
/// Photo library access lives in the photo tile, not down here.
class _PlayerSecondaryActionRow extends StatelessWidget {
  const _PlayerSecondaryActionRow({
    required this.showPrevious,
    required this.showSkip,
    this.onPrevious,
    this.onSkip,
  });

  final bool showPrevious;
  final bool showSkip;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showPrevious)
          Flexible(
            child: PebbleButton.tertiary(
              onPressed: onPrevious == null
                  ? null
                  : () => unawaited(onPrevious!()),
              icon: LucideIcons.chevronLeft,
              label: 'Previous',
            ),
          ),
        const Spacer(),
        if (showSkip)
          Flexible(
            child: PebbleButton.tertiary(
              onPressed: onSkip == null ? null : () => unawaited(onSkip!()),
              label: 'Skip step',
            ),
          ),
      ],
    );
  }
}

/// Step text under the title, two lines at most until "More" is tapped.
class _StepDescription extends StatefulWidget {
  const _StepDescription({required this.text});

  final String text;

  @override
  State<_StepDescription> createState() => _StepDescriptionState();
}

class _StepDescriptionState extends State<_StepDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 16,
      height: 1.45,
      color: context.readableSecondaryText,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        final text = Text(
          widget.text,
          key: const ValueKey('routine-step-description'),
          textAlign: TextAlign.center,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: style,
        );
        if (!overflows) return text;
        return Column(
          children: [
            text,
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: context.readableAccentText(
                  Theme.of(context).colorScheme.primary,
                ),
                textStyle: PebbleFonts.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_expanded ? 'Less' : 'More'),
            ),
          ],
        );
      },
    );
  }
}

/// One thin segment per step: done, current (half strength) and to come.
/// Falls back to one continuous bar when there are too many steps for
/// segments to read.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.stepIndex,
    required this.stepCount,
    required this.complete,
  });

  final int stepIndex;
  final int stepCount;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = context.done;
    final current = done.withValues(alpha: 0.45);
    final todo = theme.colorScheme.onSurface.withValues(alpha: 0.10);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : PebbleMotion.standard;
    if (stepCount <= 0) return const SizedBox(height: 4);
    if (stepCount > 16) {
      return ClipRRect(
        borderRadius: PebbleRadius.pillAll,
        child: LinearProgressIndicator(
          value: complete ? 1 : (stepIndex + 1) / stepCount,
          minHeight: 4,
          backgroundColor: todo,
          valueColor: AlwaysStoppedAnimation<Color>(done),
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < stepCount; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: duration,
              curve: PebbleMotion.enter,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: PebbleRadius.pillAll,
                color: complete || i < stepIndex
                    ? done
                    : i == stepIndex
                    ? current
                    : todo,
              ),
            ),
          ),
        ],
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
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
