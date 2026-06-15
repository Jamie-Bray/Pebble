import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/routines/data/shared_reminder_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_player_photo_picker.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
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
    with WidgetsBindingObserver {
  final GlobalKey<AnimatedVisualAnchorState> _visualAnchorKey =
      GlobalKey<AnimatedVisualAnchorState>();
  static const _pendingCameraCapturePrefsKey =
      'routine_player_pending_camera_capture';
  String? _lastReminderSentRunId;
  bool _isPrimaryPreludeRunning = false;
  AudioPlayer? _chimePlayer;

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
    unawaited(_chimePlayer?.dispose());
    super.dispose();
  }

  /// Opt-in reassurance feedback when a step is checked off.
  void _playStepCompleteFeedback() {
    final playerSettings = ref.read(playerSettingsControllerProvider);
    if (playerSettings.stepCompleteHaptic) {
      unawaited(HapticFeedback.mediumImpact());
    }
    if (playerSettings.stepCompleteSound) {
      unawaited(_playChime());
    }
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
            child: switch (playerState.screenPhase) {
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
              RoutinePlayerScreenPhase.completion => RoutineCompleteScreen(
                routineName:
                    playerState.completionSummary?.routineTitle ??
                    'Routine complete',
                totalStepsCompleted:
                    playerState.completionSummary?.completedSteps ??
                    playerState.completedSteps,
                totalPhotosSaved:
                    playerState.completionSummary?.photoCount ??
                    playerState.proofAssets.length,
                onBackToHome: _goHome,
                onReviewRoutine: _openVault,
              ),
              RoutinePlayerScreenPhase.ready ||
              RoutinePlayerScreenPhase.completing => _buildPlayer(
                context,
                themeData,
                playerState,
              ),
            },
          ),
        ),
      ),
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
    final showGalleryAction =
        playerState.hasPhotoRequirement &&
        currentStep.allowGallery &&
        canAddMore;
    // The proof-photo card is part of the step itself - it shows from the
    // start (with the Add tile) so capture lives on the surface, not behind
    // the primary button.
    final showPhotoSummary = playerState.hasPhotoRequirement;
    final isFreeTier = !premiumPolicy.canUseExtraProofPhotos;
    final isStepLocked = playerState.isCurrentStepLocked;

    return _RoutineStepSurface(
      routineName: session.routineTitleSnapshot,
      stepIndex: playerState.currentStepIndex,
      stepCount: playerState.totalSteps,
      progress: playerState.progress,
      instruction: _stepInstruction(currentStep),
      guidanceAudioCard: currentStep.guidanceAudio != null && !isStepLocked
          ? _PlayerGuidanceAudioCard(
              audio: currentStep.guidanceAudio!,
              storage: guidanceAudioStorage,
            )
          : null,
      isStepLocked: isStepLocked,
      lockedStepCount: playerState.lockedStepCount,
      photoRequired: playerState.hasPhotoRequirement,
      showVisualAnchor:
          playerSettings.showVisualAnchor &&
          !playerState.hasPhotoRequirement &&
          !isStepLocked,
      visualAnchorStepKey: playerState.currentStepIndex,
      visualAnchorKey: _visualAnchorKey,
      isBusy: playerState.isPrimaryBusy || _isPrimaryPreludeRunning,
      primaryLabel: isStepLocked
          ? 'Upgrade to reactivate'
          : playerState.primaryLabel,
      isPrimaryEnabled: isStepLocked || playerState.isPrimaryEnabled,
      onBack: _attemptExit,
      onComplete: isStepLocked ? _openStepLimitPaywall : _handlePrimaryAction,
      photoSummary: showPhotoSummary && !isStepLocked
          ? _PlayerPhotoSummary(
              proofAssets: playerState.proofAssets,
              capturedPhotoCount: playerState.capturedPhotoCount,
              requiredPhotoCount: playerState.requiredPhotoCount,
              maxPhotoCount: playerState.maxProofPhotosPerStep,
              isFreeTier: isFreeTier,
              resolveProofPath: proofStorage.resolveStoredPath,
              onAddPhoto: canAddMore ? _captureCameraPhoto : null,
              onChooseFromGallery: showGalleryAction
                  ? _captureGalleryPhoto
                  : null,
              onOpenPhoto: _openCurrentStepProofGallery,
              onPhotoLimitUpgrade: isFreeTier
                  ? _openProofPhotoLimitPaywall
                  : null,
              onRemovePhoto: !playerState.isForegroundBusy
                  ? (proofId) async {
                      await ref
                          .read(
                            routinePlayerProvider(widget.sessionId).notifier,
                          )
                          .removeProof(proofId);
                    }
                  : null,
            )
          : null,
      secondaryActions: _PlayerSecondaryActionRow(
        showPrevious: playerState.canGoBack,
        onPrevious: playerState.canGoBack
            ? () async {
                await ref
                    .read(routinePlayerProvider(widget.sessionId).notifier)
                    .previousStep();
              }
            : null,
        showSkip: playerState.canSkip,
        onSkip: playerState.canSkip
            ? () async {
                final run = await ref
                    .read(routinePlayerProvider(widget.sessionId).notifier)
                    .skipCurrentStep();
                await _handlePostCompletion(run);
              }
            : null,
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    if (_isPrimaryPreludeRunning || !state.isPrimaryEnabled) {
      return;
    }
    final playerSettings = ref.read(playerSettingsControllerProvider);
    if (playerSettings.enableTransitions) {
      setState(() => _isPrimaryPreludeRunning = true);
      try {
        await _visualAnchorKey.currentState?.playCompletion();
      } finally {
        if (mounted) {
          setState(() => _isPrimaryPreludeRunning = false);
        }
      }
    }

    // The primary button only ever completes the step now. Photo capture is
    // driven by the Add tile in the strip, and the button stays disabled until
    // the step has enough photos, so photoRequired never reaches here enabled.
    _playStepCompleteFeedback();
    final run = await ref
        .read(routinePlayerProvider(widget.sessionId).notifier)
        .completeCurrentStep();
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

  Future<void> _capturePhoto(ImageSource source) async {
    final controller = ref.read(
      routinePlayerProvider(widget.sessionId).notifier,
    );
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    final step = state.currentStep;
    if (step == null || !controller.beginPhotoCapture()) {
      return;
    }

    try {
      if (source == ImageSource.gallery && !step.allowGallery) {
        controller.cancelPhotoCapture();
        return;
      }

      final acceptedPrompt = await _showPhotoPermissionRationale(source);
      if (!acceptedPrompt) {
        controller.cancelPhotoCapture();
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
        controller.cancelPhotoCapture();
        return;
      }

      final attached = await controller.attachProof(picked.path);
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      unawaited(_deletePickerTemp(picked.path));
      if (!attached && mounted) {
        _showPhotoLimitReachedMessage();
      }
    } on PlatformException catch (error) {
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      controller.cancelPhotoCapture();
      _showPhotoCaptureFailure(source, error.code);
    } catch (_) {
      if (source == ImageSource.camera) {
        await _clearPendingCameraCapture();
      }
      controller.cancelPhotoCapture();
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
      await sharedReminders.sendCompletionReminder(
        routineId: session.routineId,
        routineCloudId: routine?.cloudId,
        routineTitle: session.routineTitleSnapshot,
        runId: run.id,
        sessionId: session.sessionId,
        completedAt: session.completedAt ?? DateTime.now(),
        completedSteps: session.completedStepsCount,
        totalSteps: session.totalStepCount,
      );
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _RoutineExitAction.leaveAndSave),
                    child: const Text('Leave and save'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, _RoutineExitAction.stay),
                    child: const Text('Stay here'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _RoutineExitAction.discard),
                    style: TextButton.styleFrom(
                      foregroundColor: themeData.colorScheme.error.withValues(
                        alpha: 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Discard progress'),
                  ),
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
    required this.instruction,
    this.guidanceAudioCard,
    required this.isStepLocked,
    required this.lockedStepCount,
    required this.photoRequired,
    required this.showVisualAnchor,
    required this.visualAnchorStepKey,
    required this.visualAnchorKey,
    required this.isBusy,
    required this.primaryLabel,
    required this.isPrimaryEnabled,
    required this.onBack,
    required this.onComplete,
    required this.secondaryActions,
    this.photoSummary,
  });

  final String routineName;
  final int stepIndex;
  final int stepCount;
  final double progress;
  final String instruction;
  final Widget? guidanceAudioCard;
  final bool isStepLocked;
  final int lockedStepCount;
  final bool photoRequired;
  final bool showVisualAnchor;
  final int visualAnchorStepKey;
  final GlobalKey<AnimatedVisualAnchorState> visualAnchorKey;
  final bool isBusy;
  final String primaryLabel;
  final bool isPrimaryEnabled;
  final Future<void> Function() onBack;
  final Future<void> Function() onComplete;
  final Widget? photoSummary;
  final Widget secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

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
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(
            children: [
              Text(
                routineName.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: onSurface.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Step ${stepIndex + 1} of $stepCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (showVisualAnchor) ...[
                        AnimatedVisualAnchor(
                          key: visualAnchorKey,
                          stepKey: visualAnchorStepKey,
                        ),
                        const SizedBox(height: 34),
                      ],
                      if (isStepLocked) ...[
                        _LockedStepBoundaryBanner(
                          lockedStepCount: lockedStepCount,
                        ),
                        const SizedBox(height: 24),
                      ],
                      ImageFiltered(
                        enabled: isStepLocked,
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 2.4,
                          sigmaY: 2.4,
                        ),
                        child: Opacity(
                          opacity: isStepLocked ? 0.30 : 1,
                          child: Text(
                            instruction,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (photoSummary != null) ...[
                        const SizedBox(height: 24),
                        photoSummary!,
                      ],
                      if (guidanceAudioCard != null) ...[
                        const SizedBox(height: 16),
                        guidanceAudioCard!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _RoutineStepFooter(
          isBusy: isBusy,
          primaryLabel: primaryLabel,
          isPrimaryEnabled: isPrimaryEnabled,
          onComplete: onComplete,
          secondaryActions: secondaryActions,
        ),
      ],
    );
  }
}

class AnimatedVisualAnchor extends StatefulWidget {
  const AnimatedVisualAnchor({super.key, required this.stepKey});

  final int stepKey;

  @override
  State<AnimatedVisualAnchor> createState() => AnimatedVisualAnchorState();
}

class AnimatedVisualAnchorState extends State<AnimatedVisualAnchor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedVisualAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepKey != widget.stepKey) {
      _reset();
    }
  }

  Future<void> playCompletion() async {
    if (!mounted) {
      return;
    }
    setState(() => _showCheck = true);
    _controller.value = 0;
    await _controller.forward();
  }

  void _reset() {
    _controller.value = 0;
    if (_showCheck) {
      setState(() => _showCheck = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = Colors.green.shade600;

    return SizedBox(
      key: const ValueKey('routine-player-visual-anchor'),
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _showCheck ? _curve.value : 0.0;
          final idleAlpha = 1 - t;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.82),
                success.withValues(alpha: 0.12),
                t,
              ),
              border: Border.all(
                width: 2 + (2 * t),
                color: Color.lerp(
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  success,
                  t,
                )!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    success.withValues(alpha: 0.18),
                    t,
                  )!,
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: idleAlpha,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 3,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showCheck)
                    Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.72 + (0.28 * t),
                        child: Icon(
                          LucideIcons.check,
                          size: 54,
                          color: success,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
    required this.isPrimaryEnabled,
    required this.onComplete,
    required this.secondaryActions,
  });

  final bool isBusy;
  final String primaryLabel;
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPrimaryEnabled && !isBusy
                      ? () => unawaited(onComplete())
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 36),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onSurface.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                    color: onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GuidanceAudioPlayButton(
            audio: audio,
            storage: storage,
            compact: true,
          ),
        ],
      ),
    );
  }
}

/// Fixed-size proof-photo card from the v3 mockup: a single horizontal strip
/// of ~64px tiles (never a grid, so the surface never has to scroll), a gated
/// subtitle, and capture driven by the Add tile rather than the primary button.
class _PlayerPhotoSummary extends StatelessWidget {
  const _PlayerPhotoSummary({
    required this.proofAssets,
    required this.capturedPhotoCount,
    required this.requiredPhotoCount,
    required this.maxPhotoCount,
    required this.isFreeTier,
    required this.resolveProofPath,
    this.onAddPhoto,
    this.onChooseFromGallery,
    this.onOpenPhoto,
    this.onRemovePhoto,
    this.onPhotoLimitUpgrade,
  });

  static const double _tileSize = 64;
  static const double _tileGap = 12;

  final List<RoutineSessionProofAsset> proofAssets;
  final int capturedPhotoCount;
  final int requiredPhotoCount;
  final int maxPhotoCount;
  final bool isFreeTier;
  final Future<String> Function(String storedPath) resolveProofPath;
  final Future<void> Function()? onAddPhoto;
  final Future<void> Function()? onChooseFromGallery;
  final Future<void> Function(String proofId)? onOpenPhoto;
  final Future<void> Function(String proofId)? onRemovePhoto;
  final VoidCallback? onPhotoLimitUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final hasPhotos = capturedPhotoCount > 0;
    final atMax = capturedPhotoCount >= maxPhotoCount;

    // One quiet subtitle line carries the gate; no nagging copy.
    final String subtitle;
    final Color subtitleColor;
    final remainingRequired = requiredPhotoCount - capturedPhotoCount;
    if (remainingRequired > 0) {
      if (requiredPhotoCount <= 1) {
        subtitle = 'Required to complete this step';
      } else if (!hasPhotos) {
        subtitle = 'Add $requiredPhotoCount photos to complete';
      } else {
        final label = remainingRequired == 1 ? 'photo' : 'photos';
        subtitle = '$remainingRequired more $label required';
      }
      subtitleColor = primary;
    } else if (!isFreeTier && maxPhotoCount > 1 && !atMax) {
      subtitle = 'Add up to $maxPhotoCount photos';
      subtitleColor = onSurface.withValues(alpha: 0.55);
    } else if (!isFreeTier && maxPhotoCount > 1 && atMax) {
      subtitle = 'All $maxPhotoCount added';
      subtitleColor = onSurface.withValues(alpha: 0.55);
    } else {
      subtitle = '';
      subtitleColor = onSurface.withValues(alpha: 0.55);
    }

    final tiles = <Widget>[
      for (final asset in proofAssets)
        _PhotoStripPhotoTile(
          key: ValueKey('proof-${asset.proofId}'),
          asset: asset,
          size: _tileSize,
          reduceMotion: reduceMotion,
          resolveProofPath: resolveProofPath,
          onOpen: onOpenPhoto == null
              ? null
              : () => onOpenPhoto!(asset.proofId),
          onRemove: onRemovePhoto == null
              ? null
              : () => onRemovePhoto!(asset.proofId),
        ),
      if (!atMax && onAddPhoto != null)
        _PhotoStripActionTile.add(size: _tileSize, onTap: onAddPhoto!),
      // Free tier always carries a calm, ignorable signpost to Premium.
      if (isFreeTier && onPhotoLimitUpgrade != null)
        _PhotoStripActionTile.locked(
          size: _tileSize,
          onTap: onPhotoLimitUpgrade!,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasPhotos
              ? onSurface.withValues(alpha: 0.06)
              : primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proof photo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 2),
          // Reserve the line height so the strip never shifts as copy changes.
          SizedBox(
            height: 17,
            child: subtitle.isEmpty
                ? null
                : Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i += 1) ...[
                  if (i > 0) const SizedBox(width: _tileGap),
                  tiles[i],
                ],
              ],
            ),
          ),
          if (onChooseFromGallery != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => unawaited(onChooseFromGallery!()),
              icon: const Icon(LucideIcons.images, size: 15),
              label: const Text('Choose from library'),
              style: TextButton.styleFrom(
                foregroundColor: onSurface.withValues(alpha: 0.55),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A captured proof in the strip: fixed square, rounded, with a scrim remove
/// button. Animates in with a scale-fade unless reduced-motion is on.
class _PhotoStripPhotoTile extends StatelessWidget {
  const _PhotoStripPhotoTile({
    super.key,
    required this.asset,
    required this.size,
    required this.reduceMotion,
    required this.resolveProofPath,
    this.onOpen,
    this.onRemove,
  });

  final RoutineSessionProofAsset asset;
  final double size;
  final bool reduceMotion;
  final Future<String> Function(String storedPath) resolveProofPath;
  final Future<void> Function()? onOpen;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: FutureBuilder<String>(
                future: resolveProofPath(asset.localRelativePath),
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  final file = path == null ? null : File(path);
                  final exists = file != null && file.existsSync();
                  if (exists) {
                    return Image.file(file, fit: BoxFit.cover);
                  }
                  return Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      LucideIcons.imageOff,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.35,
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
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          if (onOpen != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => unawaited(onOpen!()),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: -14,
              right: -14,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => unawaited(onRemove!()),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0x80161612),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (reduceMotion) {
      return tile;
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
      child: tile,
    );
  }
}

/// The Add and locked-Premium tiles share a square, rounded, labelled shape.
class _PhotoStripActionTile extends StatelessWidget {
  const _PhotoStripActionTile._({
    required this.size,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.locked,
  });

  factory _PhotoStripActionTile.add({
    required double size,
    required Future<void> Function() onTap,
  }) {
    return _PhotoStripActionTile._(
      size: size,
      icon: LucideIcons.camera,
      label: 'Add',
      onTap: () => unawaited(onTap()),
      locked: false,
    );
  }

  factory _PhotoStripActionTile.locked({
    required double size,
    required VoidCallback onTap,
  }) {
    return _PhotoStripActionTile._(
      size: size,
      icon: LucideIcons.lock,
      label: 'Premium',
      onTap: onTap,
      locked: true,
    );
  }

  final double size;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = locked
        ? onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.primary;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: locked ? 16 : 19, color: accent),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: locked ? 10 : 10.5,
            fontWeight: FontWeight.w500,
            color: accent,
          ),
        ),
      ],
    );

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: locked
            ? onSurface.withValues(alpha: 0.03)
            : theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: locked
              ? CustomPaint(
                  painter: _DashedRRectPainter(
                    color: onSurface.withValues(alpha: 0.22),
                    radius: 13,
                  ),
                  child: Center(child: content),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                  ),
                  child: Center(child: content),
                ),
        ),
      ),
    );
  }
}

/// Faint dashed rounded-rect outline for the locked Premium tile.
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
  });

  final bool showPrevious;
  final bool showSkip;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.62);

    final actions = <Widget>[
      if (showPrevious)
        TextButton.icon(
          onPressed: onPrevious == null ? null : () => unawaited(onPrevious!()),
          icon: const Icon(LucideIcons.chevronLeft, size: 16),
          label: const Text('Previous'),
          style: TextButton.styleFrom(foregroundColor: textColor),
        ),
      if (showSkip)
        TextButton(
          onPressed: onSkip == null ? null : () => unawaited(onSkip!()),
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Text('Skip step'),
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

class RoutineCompleteScreen extends StatefulWidget {
  const RoutineCompleteScreen({
    super.key,
    required this.routineName,
    required this.totalStepsCompleted,
    required this.totalPhotosSaved,
    required this.onBackToHome,
    required this.onReviewRoutine,
  });

  final String routineName;
  final int totalStepsCompleted;
  final int totalPhotosSaved;
  final VoidCallback onBackToHome;
  final VoidCallback onReviewRoutine;

  @override
  State<RoutineCompleteScreen> createState() => _RoutineCompleteScreenState();
}

class _RoutineCompleteScreenState extends State<RoutineCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final routineName = widget.routineName.trim().isEmpty
        ? 'Routine complete'
        : widget.routineName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StaggeredEntrance(
                      controller: _controller,
                      interval: const Interval(
                        0,
                        0.58,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.25),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 58,
                              color: theme.colorScheme.onPrimary,
                              weight: 800,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Routine complete',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            routineName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 46),
                    _StaggeredEntrance(
                      controller: _controller,
                      interval: const Interval(
                        0.18,
                        0.78,
                        curve: Curves.easeOutCubic,
                      ),
                      child: _RoutineSummaryCard(
                        totalStepsCompleted: widget.totalStepsCompleted,
                        totalPhotosSaved: widget.totalPhotosSaved,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: _StaggeredEntrance(
              controller: _controller,
              interval: const Interval(0.36, 1, curve: Curves.easeOutCubic),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onBackToHome,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shadowColor: primary.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onReviewRoutine,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.transparent,
                        foregroundColor: primary,
                        side: BorderSide(
                          color: primary.withValues(alpha: 0.36),
                          width: 1.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Review Routine'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineSummaryCard extends StatelessWidget {
  const _RoutineSummaryCard({
    required this.totalStepsCompleted,
    required this.totalPhotosSaved,
  });

  final int totalStepsCompleted;
  final int totalPhotosSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const completionText = Color(0xFF2D2B2A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: completionText.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUMMARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFFADA69F),
            ),
          ),
          const SizedBox(height: 16),
          _RoutineSummaryRow(
            icon: LucideIcons.circleCheck,
            label: 'Steps Completed',
            value: '$totalStepsCompleted / $totalStepsCompleted',
          ),
          Divider(height: 25, color: completionText.withValues(alpha: 0.08)),
          _RoutineSummaryRow(
            icon: LucideIcons.image,
            label: 'Evidence Saved',
            value: '$totalPhotosSaved Photo${totalPhotosSaved == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }
}

class _RoutineSummaryRow extends StatelessWidget {
  const _RoutineSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const completionText = Color(0xFF2D2B2A);
    const mutedText = Color(0xFF8C857E);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: completionText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: mutedText,
          ),
        ),
      ],
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.controller,
    required this.interval,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(parent: controller, curve: interval);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
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
                    FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel!),
                    ),
                  ],
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
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
