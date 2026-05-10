import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/routines/data/shared_alert_preferences_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/execution/providers/player_state_provider.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/shared/ui/guidance_audio_play_button.dart';

class RoutinePlayerScreen extends ConsumerStatefulWidget {
  const RoutinePlayerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RoutinePlayerScreen> createState() =>
      _RoutinePlayerScreenState();
}

class _RoutinePlayerScreenState extends ConsumerState<RoutinePlayerScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  String? _lastAlertedRunId;
  String? _completionEmailRecipient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
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
              RoutinePlayerScreenPhase.completion => _PlayerCompletionView(
                summary: playerState.completionSummary,
                trustedContactEmail: _completionEmailRecipient,
                onBackToHome: _goHome,
                onViewHistory: _goToHistory,
                onOpenVault: playerState.showCompletionOpenVault
                    ? _openVault
                    : null,
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

    return _RoutinePlayerScaffold(
      top: _PlayerTopContext(
        routineTitle: session.routineTitleSnapshot,
        stepCountLabel:
            'Step ${playerState.currentStepIndex + 1} of ${playerState.totalSteps}',
        stepTitle: _stepTitle(currentStep),
        progress: playerState.progress,
        eyebrowLabel:
            playerState.presentationState ==
                RoutinePlayerPresentationState.finalStep
            ? 'Final step'
            : null,
        onBack: _attemptExit,
      ),
      body: _PlayerStepBody(
        stepBody: _stepBody(currentStep),
        supportingText: _supportingCopy(playerState, currentStep),
        photoSummary: playerState.hasPhotoRequirement
            ? _PlayerPhotoSummary(
                presentationState: playerState.presentationState,
                proofAssets: playerState.proofAssets,
                capturedPhotoCount: playerState.capturedPhotoCount,
                requiredPhotoCount: playerState.requiredPhotoCount,
                maxPhotoCount: playerState.maxProofPhotosPerStep,
                resolveProofPath: proofStorage.resolveStoredPath,
                onRemovePhoto: !playerState.isForegroundBusy
                    ? (proofId) async {
                        HapticFeedback.selectionClick();
                        await ref
                            .read(
                              routinePlayerProvider(widget.sessionId).notifier,
                            )
                            .removeProof(proofId);
                      }
                    : null,
              )
            : null,
      ),
      bottom: _PlayerBottomDock(
        isBusy: playerState.isPrimaryBusy,
        primaryLabel: playerState.primaryLabel,
        isPrimaryEnabled: playerState.isPrimaryEnabled,
        onPrimary: _handlePrimaryAction,
        secondary: _PlayerSecondaryActionRow(
          guidanceAudioButton: currentStep.guidanceAudio != null
              ? GuidanceAudioPlayButton(
                  audio: currentStep.guidanceAudio!,
                  storage: guidanceAudioStorage,
                )
              : null,
          showPrevious: playerState.canGoBack,
          onPrevious: playerState.canGoBack
              ? () async {
                  HapticFeedback.lightImpact();
                  await ref
                      .read(routinePlayerProvider(widget.sessionId).notifier)
                      .previousStep();
                }
              : null,
          showSkip: playerState.canSkip,
          onSkip: playerState.canSkip
              ? () async {
                  HapticFeedback.lightImpact();
                  final run = await ref
                      .read(routinePlayerProvider(widget.sessionId).notifier)
                      .skipCurrentStep();
                  await _handlePostCompletion(run);
                }
              : null,
          showAddAnotherPhoto: playerState.showAddAnotherPhoto,
          onAddAnotherPhoto: playerState.showAddAnotherPhoto
              ? _capturePhoto
              : null,
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    switch (state.presentationState) {
      case RoutinePlayerPresentationState.photoRequired:
        await _capturePhoto();
      case RoutinePlayerPresentationState.standard:
      case RoutinePlayerPresentationState.photoCaptured:
      case RoutinePlayerPresentationState.finalStep:
        final run = await ref
            .read(routinePlayerProvider(widget.sessionId).notifier)
            .completeCurrentStep();
        await _handlePostCompletion(run);
    }
  }

  Future<void> _capturePhoto() async {
    final controller = ref.read(
      routinePlayerProvider(widget.sessionId).notifier,
    );
    final state = ref.read(routinePlayerProvider(widget.sessionId));
    final step = state.currentStep;
    if (step == null || !controller.beginPhotoCapture()) {
      return;
    }

    try {
      final source = await _selectPhotoSource(step);
      if (source == null) {
        controller.cancelPhotoCapture();
        return;
      }

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 800,
      );
      if (picked == null) {
        controller.cancelPhotoCapture();
        return;
      }

      HapticFeedback.mediumImpact();
      final attached = await controller.attachProof(picked.path);
      if (!attached && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo limit reached for this step.')),
        );
      }
    } catch (_) {
      controller.cancelPhotoCapture();
      rethrow;
    }
  }

  Future<ImageSource?> _selectPhotoSource(RoutineStep step) async {
    if (!step.allowGallery) {
      return ImageSource.camera;
    }

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final themeData = Theme.of(context);
        final onSurface = themeData.colorScheme.onSurface;
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
                      color: onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add photo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(LucideIcons.camera),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.images),
                  title: const Text('Choose from library'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePostCompletion(RoutineRun? run) async {
    if (run == null) {
      return;
    }
    await _enqueueSharedAlertIfNeeded(run);
  }

  Future<void> _enqueueSharedAlertIfNeeded(RoutineRun run) async {
    if (_lastAlertedRunId == run.id) {
      return;
    }
    final playerState = ref.read(routinePlayerProvider(widget.sessionId));
    final session = playerState.session;
    if (session == null) {
      return;
    }
    final sharedAlerts = ref.read(sharedAlertPreferencesRepositoryProvider);
    try {
      final routine = await ref
          .read(localDbProvider)
          .routineDao
          .getRoutineById(session.routineId);
      final result = await sharedAlerts.sendCompletionAlert(
        routineId: session.routineId,
        routineCloudId: routine?.cloudId,
        routineTitle: session.routineTitleSnapshot,
        runId: run.id,
        sessionId: session.sessionId,
        completedAt: session.completedAt ?? DateTime.now(),
        completedSteps: session.completedStepsCount,
        totalSteps: session.totalStepCount,
      );
      final recipientEmail = result.recipientEmail?.trim();
      if (mounted &&
          result.sent &&
          recipientEmail != null &&
          recipientEmail.isNotEmpty) {
        setState(() => _completionEmailRecipient = recipientEmail);
      }
    } catch (_) {
      // Shared emails should never make a completed routine feel unfinished.
    } finally {
      _lastAlertedRunId = run.id;
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

  void _goToHistory() {
    ref.read(navIndexProvider.notifier).state = 1;
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
      Navigator.of(context).pop();
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

  String? _supportingCopy(RoutinePlayerUiState state, RoutineStep step) {
    switch (state.presentationState) {
      case RoutinePlayerPresentationState.photoRequired:
      case RoutinePlayerPresentationState.photoCaptured:
      case RoutinePlayerPresentationState.finalStep:
        return null;
      case RoutinePlayerPresentationState.standard:
        return _stepBody(step);
    }
  }
}

class _RoutinePlayerScaffold extends StatelessWidget {
  const _RoutinePlayerScaffold({
    required this.top,
    required this.body,
    required this.bottom,
  });

  final Widget top;
  final Widget body;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        top,
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: body,
          ),
        ),
        bottom,
      ],
    );
  }
}

class _PlayerTopContext extends StatelessWidget {
  const _PlayerTopContext({
    required this.routineTitle,
    required this.stepCountLabel,
    required this.stepTitle,
    required this.progress,
    this.eyebrowLabel,
    required this.onBack,
  });

  final String routineTitle;
  final String stepCountLabel;
  final String stepTitle;
  final double progress;
  final String? eyebrowLabel;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBackButton(onBack: onBack),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            routineTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stepCountLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: onSurface.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 18),
          if (eyebrowLabel != null) ...[
            Text(
              eyebrowLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            stepTitle,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: onSurface,
            ),
          ),
        ],
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

class _PlayerStepBody extends StatelessWidget {
  const _PlayerStepBody({
    required this.stepBody,
    required this.supportingText,
    this.photoSummary,
  });

  final String? stepBody;
  final String? supportingText;
  final Widget? photoSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stepBody != null &&
            stepBody!.isNotEmpty &&
            stepBody != supportingText) ...[
          Text(
            stepBody!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: onSurface.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (supportingText != null && supportingText!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow.withValues(
                alpha: 0.88,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: onSurface.withValues(alpha: 0.06)),
            ),
            child: Text(
              supportingText!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: onSurface.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
        if (photoSummary != null) ...[
          const SizedBox(height: 18),
          photoSummary!,
        ],
      ],
    );
  }
}

class _PlayerPhotoSummary extends StatelessWidget {
  const _PlayerPhotoSummary({
    required this.presentationState,
    required this.proofAssets,
    required this.capturedPhotoCount,
    required this.requiredPhotoCount,
    required this.maxPhotoCount,
    required this.resolveProofPath,
    this.onRemovePhoto,
  });

  final RoutinePlayerPresentationState presentationState;
  final List<RoutineSessionProofAsset> proofAssets;
  final int capturedPhotoCount;
  final int requiredPhotoCount;
  final int maxPhotoCount;
  final Future<String> Function(String storedPath) resolveProofPath;
  final Future<void> Function(String proofId)? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final statusTitle = capturedPhotoCount > 0
        ? '$capturedPhotoCount photo${capturedPhotoCount == 1 ? '' : 's'} added'
        : 'Photo needed';
    final statusBody = capturedPhotoCount < requiredPhotoCount
        ? 'Add a photo before completing this step.'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              presentationState == RoutinePlayerPresentationState.photoRequired
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          if (statusBody != null) ...[
            const SizedBox(height: 8),
            Text(
              statusBody,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (proofAssets.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (maxPhotoCount > 1)
              GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 4 / 3,
                ),
                itemCount: proofAssets.length,
                itemBuilder: (context, index) {
                  final asset = proofAssets[index];
                  return _PlayerPhotoThumbnail(
                    asset: asset,
                    resolveProofPath: resolveProofPath,
                    onRemove: onRemovePhoto == null
                        ? null
                        : () => onRemovePhoto!(asset.proofId),
                  );
                },
              )
            else
              ...proofAssets.map(
                (asset) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlayerPhotoThumbnail(
                    asset: asset,
                    resolveProofPath: resolveProofPath,
                    onRemove: onRemovePhoto == null
                        ? null
                        : () => onRemovePhoto!(asset.proofId),
                  ),
                ),
              ),
          ],
          if (capturedPhotoCount >= maxPhotoCount) ...[
            const SizedBox(height: 4),
            Text(
              'Photo limit reached.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onSurface.withValues(alpha: 0.52),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerPhotoThumbnail extends StatelessWidget {
  const _PlayerPhotoThumbnail({
    required this.asset,
    required this.resolveProofPath,
    this.onRemove,
  });

  final RoutineSessionProofAsset asset;
  final Future<String> Function(String storedPath) resolveProofPath;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
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
                      size: 36,
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
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black.withValues(alpha: 0.42),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => unawaited(onRemove!()),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(LucideIcons.x, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerBottomDock extends StatelessWidget {
  const _PlayerBottomDock({
    required this.primaryLabel,
    required this.isPrimaryEnabled,
    required this.onPrimary,
    required this.secondary,
    required this.isBusy,
  });

  final String primaryLabel;
  final bool isPrimaryEnabled;
  final Future<void> Function() onPrimary;
  final Widget secondary;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPrimaryEnabled && !isBusy
                      ? () => unawaited(onPrimary())
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(minHeight: 40),
                child: Align(alignment: Alignment.center, child: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSecondaryActionRow extends StatelessWidget {
  const _PlayerSecondaryActionRow({
    required this.showPrevious,
    required this.showSkip,
    required this.showAddAnotherPhoto,
    this.guidanceAudioButton,
    this.onPrevious,
    this.onSkip,
    this.onAddAnotherPhoto,
  });

  final bool showPrevious;
  final bool showSkip;
  final bool showAddAnotherPhoto;
  final Widget? guidanceAudioButton;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onSkip;
  final Future<void> Function()? onAddAnotherPhoto;

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
      if (showAddAnotherPhoto)
        TextButton(
          onPressed: onAddAnotherPhoto == null
              ? null
              : () => unawaited(onAddAnotherPhoto!()),
          style: TextButton.styleFrom(foregroundColor: textColor),
          child: const Text('Add another photo'),
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
        if (guidanceAudioButton != null)
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: guidanceAudioButton,
            ),
          ),
        if (guidanceAudioButton != null && actions.isNotEmpty)
          const SizedBox(width: 8),
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

class _PlayerCompletionView extends StatelessWidget {
  const _PlayerCompletionView({
    required this.summary,
    required this.trustedContactEmail,
    required this.onBackToHome,
    required this.onViewHistory,
    this.onOpenVault,
  });

  final RoutinePlayerCompletionSummary? summary;
  final String? trustedContactEmail;
  final VoidCallback onBackToHome;
  final VoidCallback onViewHistory;
  final VoidCallback? onOpenVault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = summary?.routineTitle ?? 'Routine complete';
    final photoCount = summary?.photoCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            LucideIcons.badgeCheck,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Routine complete',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 18),
            // TODO: Expand this into a fuller calm completion summary once the
            // photo-review surface is refined.
            Text(
              photoCount > 0
                  ? '$photoCount photo${photoCount == 1 ? '' : 's'} saved.'
                  : 'All steps are complete.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ],
          if (trustedContactEmail != null &&
              trustedContactEmail!.isNotEmpty) ...[
            const SizedBox(height: 18),
            _CompletionEmailReceipt(email: trustedContactEmail!),
          ],
          const Spacer(),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onBackToHome,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Back to Home'),
                  ),
                ),
                const SizedBox(height: 12),
                if (onOpenVault != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onOpenVault,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('View photos'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onViewHistory,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('View history'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionEmailReceipt extends StatelessWidget {
  const _CompletionEmailReceipt({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.mailCheck,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email sent to trusted contact',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
