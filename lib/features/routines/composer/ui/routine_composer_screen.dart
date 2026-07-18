import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/routines/composer/data/guidance_audio_storage.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_config.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_state.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:pebble_routines/features/routines/composer/providers/routine_composer_provider.dart';
import 'package:pebble_routines/features/routines/composer/ui/routine_composer_step_row.dart';
import 'package:pebble_routines/features/routines/shared/ui/guidance_audio_play_button.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/features/subscription/ui/subscription_guard.dart';
import 'package:pebble_routines/core/ui/adaptive_layout.dart';
import 'package:pebble_routines/core/ui/zen_notifications.dart';
import 'package:record/record.dart';

class RoutineComposerScreen extends ConsumerStatefulWidget {
  RoutineComposerScreen.newDraft({
    super.key,
    this.onSaveComplete,
    bool forceNewDraft = false,
  }) : config = RoutineComposerConfig.newDraft(forceNewDraft: forceNewDraft);

  // ignore: prefer_const_constructors_in_immutables
  RoutineComposerScreen.edit({
    super.key,
    required Routine routine,
    this.onSaveComplete,
    RoutineComposerSeedData? seedData,
    String? initialStepId,
    int? initialStepIndex,
  }) : config = RoutineComposerConfig.edit(
         routine: routine,
         seedData: seedData,
         initialStepId: initialStepId,
         initialStepIndex: initialStepIndex,
       );

  final RoutineComposerConfig config;
  final ValueChanged<Routine>? onSaveComplete;

  @override
  ConsumerState<RoutineComposerScreen> createState() =>
      _RoutineComposerScreenState();
}

class _RoutineComposerScreenState extends ConsumerState<RoutineComposerScreen>
    with WidgetsBindingObserver {
  static const _newRowAnimationDuration = Duration(milliseconds: 180);

  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _stepControllers = <String, TextEditingController>{};
  final _stepFocusNodes = <String, FocusNode>{};
  final _rowKeys = <String, GlobalKey>{};
  late final RoutineComposerViewModel _viewModel;

  String? _focusedStepId;
  AudioRecorder? _guidanceAudioRecorder;
  Timer? _guidanceAudioTimer;
  String? _guidanceRecordingStepId;
  String? _guidanceRecordingPath;
  DateTime? _guidanceRecordingStartedAt;
  Duration _guidanceRecordingElapsed = Duration.zero;
  bool _guidanceRecordingStarting = false;
  bool _guidanceRecordingStopping = false;
  bool _guidanceStopAfterStart = false;
  bool _guidanceCancelAfterStart = false;
  bool _isClosing = false;
  bool _didAutofocusInitialStep = false;
  bool _didApplyInitialStepTarget = false;
  StateSetter? _guidanceAudioSheetSetState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ref.read(
      routineComposerViewModelProvider(widget.config).notifier,
    );
    _titleFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_viewModel.flushDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelGuidanceAudioRecordingForDispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    for (final controller in _stepControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _stepFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      routineComposerViewModelProvider(
        widget.config,
      ).select((state) => state.errorMessage),
      (previous, next) {
        if (next == null || next == previous || !mounted) return;
        ZenNotifications.showError(context, message: next);
      },
    );

    final composerState = ref.watch(
      routineComposerViewModelProvider(widget.config),
    );
    _syncEditingState(composerState);
    _maybeFocusInitialStepTarget(composerState);
    _maybeAutofocusInitialStep(composerState);

    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isClosing) return;
        await _handleBack(composerState);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: cs.surface,
        appBar: _buildAppBar(context, composerState),
        body: SafeArea(
          top: false,
          child: composerState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : AdaptiveContentWidth(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 112),
                    children: [
                      _buildTitleField(context),
                      const SizedBox(height: 20),
                      if (composerState.steps.isEmpty)
                        _buildEmptyState(context)
                      else ...[
                        _buildStepsLabel(context, composerState),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < composerState.steps.length;
                          index += 1
                        )
                          RoutineComposerStepRow(
                            rowKey: _rowKeys[composerState.steps[index].id]!,
                            index: index,
                            step: composerState.steps[index],
                            isPrimaryEntryPoint: _isPrimaryEntryPoint(
                              composerState,
                              composerState.steps[index],
                              index,
                            ),
                            controller:
                                _stepControllers[composerState
                                    .steps[index]
                                    .id]!,
                            focusNode:
                                _stepFocusNodes[composerState.steps[index].id]!,
                            isExpanded:
                                composerState.expandedStepId ==
                                composerState.steps[index].id,
                            onTap: () =>
                                _handleStepTap(composerState.steps[index].id),
                            onChanged: (value) => _viewModel.updateStepText(
                              composerState.steps[index].id,
                              value,
                            ),
                            onSubmitted: () => _handleStepSubmitted(
                              composerState,
                              composerState.steps[index],
                            ),
                            onDelete: () => _handleDeleteStep(
                              composerState,
                              composerState.steps[index].id,
                            ),
                            onToggleRequiresPhoto: () =>
                                _viewModel.toggleRequiresPhoto(
                                  composerState.steps[index].id,
                                ),
                            onToggleAllowSkip: () => _viewModel.toggleAllowSkip(
                              composerState.steps[index].id,
                            ),
                            onVoiceTip: () => _showGuidanceAudioSheet(
                              composerState.steps[index],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: _buildBottomBar(context, composerState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    RoutineComposerState state,
  ) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => _handleBack(state),
        icon: const Icon(LucideIcons.chevronLeft, size: 18),
      ),
      title: Text(
        _composerTitle(state),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: cs.onSurface.withValues(alpha: 0.62),
        ),
      ),
      actions: [_DoneAction(state: state, onPressed: () => _handleDone(state))],
    );
  }

  String _composerTitle(RoutineComposerState state) {
    if (state.mode == RoutineComposerMode.edit) {
      return 'Edit Routine';
    }
    return 'New Routine';
  }

  Widget _buildTitleField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFocused = _titleFocusNode.hasFocus;
    return AnimatedContainer(
      duration: _newRowAnimationDuration,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isFocused
                ? cs.onSurface.withValues(alpha: 0.24)
                : cs.onSurface.withValues(alpha: 0.08),
            width: isFocused ? 1 : 0.6,
          ),
        ),
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        onChanged: _viewModel.updateTitle,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: cs.onSurface,
          height: 1.15,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Routine name (optional)',
          hintStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: cs.onSurface.withValues(alpha: 0.24),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Start with a step and keep the list flowing.',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurface.withValues(alpha: 0.5),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildStepsLabel(BuildContext context, RoutineComposerState state) {
    final cs = Theme.of(context).colorScheme;
    final count = state.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    return Text(
      'STEPS - $count ADDED',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: cs.onSurface.withValues(alpha: 0.32),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, RoutineComposerState state) {
    final cs = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final safeInset = MediaQuery.of(context).padding.bottom;

    return AnimatedPadding(
      duration: _newRowAnimationDuration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: math.max(keyboardInset, safeInset)),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.72)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AddStepButton(
                label: _addStepButtonLabel(state),
                onPressed: state.isPublishing
                    ? null
                    : () => _handleAddStep(state),
                subdued: _shouldSubdueAddStep(state),
              ),
              if (_shouldShowAddStepHint(state)) ...[
                const SizedBox(height: 8),
                Text(
                  'Add step creates the next one',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.48),
                  ),
                ),
              ],
              if (!state.isPublishing &&
                  (state.isSavingDraft || state.showSavedConfirmation)) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _DraftSaveStatus(
                    isSaving: state.isSavingDraft,
                    showSaved: state.showSavedConfirmation,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _addStepButtonLabel(RoutineComposerState state) {
    final nonEmptyStepCount = state.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    return nonEmptyStepCount == 0 ? 'Add step' : 'Add next step';
  }

  bool _shouldShowAddStepHint(RoutineComposerState state) {
    return _focusedStepId != null && !state.isPublishing;
  }

  Future<void> _handleBack(RoutineComposerState state) async {
    if (_isClosing) return;
    _isClosing = true;
    await _settleTextInput();
    if (!mounted) return;
    final latestState = ref.read(
      routineComposerViewModelProvider(widget.config),
    );

    final hasMeaningfulContent =
        latestState.title.trim().isNotEmpty ||
        latestState.steps.any((step) => step.text.trim().isNotEmpty);

    if (!widget.config.isEdit && !hasMeaningfulContent) {
      await _viewModel.discardDraft();
    } else if (!widget.config.isEdit) {
      _isClosing = false;
      final action = await _showDraftExitSheet(latestState);
      if (!mounted ||
          action == null ||
          action == _DraftExitAction.continueEditing) {
        return;
      }
      _isClosing = true;
      if (action == _DraftExitAction.discard) {
        await _viewModel.discardDraft();
      } else {
        await _viewModel.flushDraft();
      }
    } else {
      await _viewModel.flushDraft();
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<_DraftExitAction?> _showDraftExitSheet(
    RoutineComposerState state,
  ) async {
    final nonEmptyStepCount = state.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    return showModalBottomSheet<_DraftExitAction>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
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
                      color: cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Keep this draft?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You have $nonEmptyStepCount step${nonEmptyStepCount == 1 ? '' : 's'} in progress. Keep it to resume from Create later, or discard it now.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _DraftExitAction.keep),
                    child: const Text('Keep draft'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _DraftExitAction.continueEditing,
                    ),
                    child: const Text('Continue editing'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _DraftExitAction.discard),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error.withValues(alpha: 0.78),
                    ),
                    child: const Text('Discard draft'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDone(RoutineComposerState state) async {
    await _settleTextInput();
    if (!mounted) return;
    final latestState = ref.read(
      routineComposerViewModelProvider(widget.config),
    );

    final nonEmptyStepCount = latestState.steps
        .where((step) => step.text.trim().isNotEmpty)
        .length;
    if (!widget.config.isEdit) {
      final currentRoutineCount =
          ref.read(routineListProvider).valueOrNull?.length ?? 0;
      if (!SubscriptionGuard.canCreateRoutine(
        context,
        ref,
        currentRoutineCount,
        stepCount: nonEmptyStepCount,
      )) {
        return;
      }
    }

    final routine = await _viewModel.publish();
    if (routine == null || !mounted) return;

    widget.onSaveComplete?.call(routine);
    if (widget.onSaveComplete == null && mounted) {
      _isClosing = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _settleTextInput() async {
    _commitControllerValues();

    final primaryFocus = FocusManager.instance.primaryFocus;
    primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } catch (_) {
      // Best-effort on platforms where the text input channel is unavailable.
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  void _commitControllerValues() {
    final latestState = ref.read(
      routineComposerViewModelProvider(widget.config),
    );
    final normalizedTitle = _normalizeInlineText(_titleController.text);
    if (normalizedTitle != latestState.title) {
      _syncControllerValue(_titleController, normalizedTitle);
      _viewModel.updateTitle(normalizedTitle);
    }

    for (final step in latestState.steps) {
      final controller = _stepControllers[step.id];
      if (controller == null) continue;
      final normalizedText = _normalizeInlineText(controller.text);
      if (normalizedText != controller.text) {
        _setControllerText(
          controller,
          normalizedText,
          moveCaretToEnd: normalizedText.isNotEmpty,
        );
      }
      if (normalizedText != step.text) {
        _viewModel.updateStepText(step.id, normalizedText);
      }
    }
  }

  String _normalizeInlineText(String value) {
    return value.replaceAll(RegExp(r'[\r\n]+'), ' ');
  }

  RoutineComposerStepDraft? _firstEmptyPrimaryStep(RoutineComposerState state) {
    if (widget.config.isEdit ||
        state.title.trim().isNotEmpty ||
        state.steps.isEmpty) {
      return null;
    }

    final firstStep = state.steps.first;
    if (firstStep.text.trim().isNotEmpty) {
      return null;
    }

    return firstStep;
  }

  bool _shouldSubdueAddStep(RoutineComposerState state) {
    return _firstEmptyPrimaryStep(state) != null;
  }

  bool _isPrimaryEntryPoint(
    RoutineComposerState state,
    RoutineComposerStepDraft step,
    int index,
  ) {
    final firstEmptyStep = _firstEmptyPrimaryStep(state);
    return index == 0 && firstEmptyStep?.id == step.id;
  }

  void _maybeAutofocusInitialStep(RoutineComposerState state) {
    if (_didAutofocusInitialStep || !mounted) return;
    if (_didApplyInitialStepTarget) return;
    final firstEmptyStep = _firstEmptyPrimaryStep(state);
    if (firstEmptyStep == null) return;
    if (_focusedStepId != null || _titleFocusNode.hasFocus) return;

    _didAutofocusInitialStep = true;
    _queueFocus(firstEmptyStep.id, adjustSelection: false);
  }

  void _maybeFocusInitialStepTarget(RoutineComposerState state) {
    if (_didApplyInitialStepTarget || !mounted || state.isLoading) return;
    if (widget.config.initialStepId == null &&
        widget.config.initialStepIndex == null) {
      return;
    }

    final targetId = _resolveInitialStepTarget(state);
    if (targetId == null) {
      _didApplyInitialStepTarget = true;
      return;
    }

    _didApplyInitialStepTarget = true;
    _queueFocus(targetId, adjustSelection: false);
  }

  String? _resolveInitialStepTarget(RoutineComposerState state) {
    if (state.steps.isEmpty) return null;

    final initialStepId = widget.config.initialStepId;
    if (initialStepId != null &&
        state.steps.any((step) => step.id == initialStepId)) {
      return initialStepId;
    }

    final initialStepIndex = widget.config.initialStepIndex;
    if (initialStepIndex == null ||
        initialStepIndex < 0 ||
        initialStepIndex >= state.steps.length) {
      return null;
    }
    return state.steps[initialStepIndex].id;
  }

  void _handleStepTap(String stepId) {
    _viewModel.setExpandedStep(stepId);
    _queueFocus(stepId, adjustSelection: false);
  }

  void _handleAddStep(RoutineComposerState state) {
    final firstEmptyStep = _firstEmptyPrimaryStep(state);
    if (firstEmptyStep != null) {
      _queueFocus(firstEmptyStep.id, adjustSelection: false);
      return;
    }

    if (!SubscriptionGuard.canAddStep(context, ref, state.steps.length)) {
      return;
    }

    final anchorStepId =
        _focusedStepId ?? (state.steps.isEmpty ? null : state.steps.last.id);
    final newStepId = _viewModel.insertStepAfter(anchorStepId);
    _queueFocus(newStepId);
  }

  void _handleStepSubmitted(
    RoutineComposerState state,
    RoutineComposerStepDraft step,
  ) {
    if (step.text.trim().isEmpty) return;
    if (!SubscriptionGuard.canAddStep(context, ref, state.steps.length)) {
      return;
    }

    final newStepId = _viewModel.insertStepAfter(step.id);
    _queueFocus(newStepId);
  }

  void _handleDeleteStep(RoutineComposerState state, String stepId) {
    final nextFocusId = _neighborStepId(state.steps, stepId);
    _viewModel.deleteStep(stepId);
    if (nextFocusId != null) {
      _queueFocus(nextFocusId);
    } else {
      _titleFocusNode.requestFocus();
    }
  }

  Future<void> _showGuidanceAudioSheet(RoutineComposerStepDraft step) async {
    _commitControllerValues();
    _viewModel.setExpandedStep(step.id);
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _guidanceAudioSheetSetState = setModalState;
            final latestStep = _latestStepById(step.id) ?? step;
            final canUseGuidanceAudio = ref
                .read(premiumFeaturePolicyProvider)
                .canUseGuidanceAudio;
            final progress =
                (_guidanceRecordingElapsed.inMilliseconds /
                        GuidanceAudioStorage.maxDuration.inMilliseconds)
                    .clamp(0.0, 1.0)
                    .toDouble();

            return _GuidanceAudioSheet(
              step: latestStep,
              storage: ref.read(guidanceAudioStorageProvider),
              canUseGuidanceAudio: canUseGuidanceAudio,
              isRecording: _guidanceRecordingStepId == step.id,
              isStarting: _guidanceRecordingStarting,
              progress: progress,
              elapsed: _guidanceRecordingElapsed,
              onRecordStart: () => _handleGuidanceAudioPressStart(latestStep),
              onRecordEnd: () => _handleGuidanceAudioPressEnd(latestStep),
              onRecordCancel: () => _handleGuidanceAudioPressCancel(latestStep),
              onRemove: () => _handleRemoveGuidanceAudio(latestStep),
              onUpgrade: () {
                Navigator.of(sheetContext).pop();
                GoRouter.of(
                  context,
                ).push(premiumRoute(source: PremiumEntrySource.guidanceAudio));
              },
            );
          },
        );
      },
    ).whenComplete(() {
      final shouldCancelRecording = _guidanceRecordingStepId == step.id;
      _guidanceAudioSheetSetState = null;
      if (shouldCancelRecording) {
        unawaited(_stopGuidanceAudioRecording(step.id, cancel: true));
      }
    });
  }

  RoutineComposerStepDraft? _latestStepById(String stepId) {
    final state = ref.read(routineComposerViewModelProvider(widget.config));
    for (final step in state.steps) {
      if (step.id == stepId) {
        return step;
      }
    }
    return null;
  }

  void _handleGuidanceAudioPressStart(RoutineComposerStepDraft step) {
    if (!ref.read(premiumFeaturePolicyProvider).canUseGuidanceAudio) {
      GoRouter.of(
        context,
      ).push(premiumRoute(source: PremiumEntrySource.guidanceAudio));
      return;
    }
    unawaited(_startGuidanceAudioRecording(step.id));
  }

  void _handleGuidanceAudioPressEnd(RoutineComposerStepDraft step) {
    unawaited(_stopGuidanceAudioRecording(step.id));
  }

  void _handleGuidanceAudioPressCancel(RoutineComposerStepDraft step) {
    unawaited(_stopGuidanceAudioRecording(step.id, cancel: true));
  }

  Future<void> _startGuidanceAudioRecording(String stepId) async {
    if (_guidanceRecordingStepId != null ||
        _guidanceRecordingStarting ||
        _guidanceRecordingStopping) {
      return;
    }

    _commitControllerValues();
    _viewModel.setExpandedStep(stepId);
    FocusScope.of(context).unfocus();

    final recorder = AudioRecorder();
    final storage = ref.read(guidanceAudioStorageProvider);

    _setGuidanceRecordingState(() {
      _guidanceAudioRecorder = recorder;
      _guidanceRecordingStepId = stepId;
      _guidanceRecordingElapsed = Duration.zero;
      _guidanceRecordingStarting = true;
      _guidanceRecordingStopping = false;
      _guidanceStopAfterStart = false;
      _guidanceCancelAfterStart = false;
    });

    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        await _disposeGuidanceRecorder(recorder);
        if (!mounted) return;
        _resetGuidanceRecordingState();
        _showGuidanceAudioError('Microphone access is needed to record audio.');
        return;
      }

      final targetPath = await storage.prepareRecordingPath();
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: targetPath,
      );

      if (!mounted) {
        await _cancelAndDisposeGuidanceRecorder(recorder);
        return;
      }

      final startedAt = DateTime.now();
      _setGuidanceRecordingState(() {
        _guidanceRecordingPath = targetPath;
        _guidanceRecordingStartedAt = startedAt;
        _guidanceRecordingStarting = false;
      });

      _guidanceAudioTimer?.cancel();
      _guidanceAudioTimer = Timer.periodic(const Duration(milliseconds: 70), (
        _,
      ) {
        final activeStartedAt = _guidanceRecordingStartedAt;
        final activeStepId = _guidanceRecordingStepId;
        if (activeStartedAt == null || activeStepId == null) return;
        final elapsed = DateTime.now().difference(activeStartedAt);
        if (elapsed >= GuidanceAudioStorage.maxDuration) {
          _guidanceAudioTimer?.cancel();
          _setGuidanceRecordingState(
            () => _guidanceRecordingElapsed = GuidanceAudioStorage.maxDuration,
          );
          unawaited(
            _stopGuidanceAudioRecording(
              activeStepId,
              forcedDuration: GuidanceAudioStorage.maxDuration,
            ),
          );
          return;
        }
        if (mounted) {
          _setGuidanceRecordingState(() => _guidanceRecordingElapsed = elapsed);
        }
      });

      if (_guidanceStopAfterStart || _guidanceCancelAfterStart) {
        final cancel = _guidanceCancelAfterStart;
        _guidanceStopAfterStart = false;
        _guidanceCancelAfterStart = false;
        unawaited(_stopGuidanceAudioRecording(stepId, cancel: cancel));
      }
    } catch (_) {
      await _cancelAndDisposeGuidanceRecorder(recorder);
      if (!mounted) return;
      _resetGuidanceRecordingState();
      _showGuidanceAudioError('Failed to start recording.');
    }
  }

  Future<void> _stopGuidanceAudioRecording(
    String stepId, {
    bool cancel = false,
    Duration? forcedDuration,
  }) async {
    if (_guidanceRecordingStepId != stepId || _guidanceRecordingStopping) {
      return;
    }

    if (_guidanceRecordingStarting) {
      _guidanceStopAfterStart = true;
      _guidanceCancelAfterStart = cancel;
      return;
    }

    final recorder = _guidanceAudioRecorder;
    if (recorder == null) {
      _resetGuidanceRecordingState();
      return;
    }

    _guidanceRecordingStopping = true;
    _guidanceAudioTimer?.cancel();

    final startedAt = _guidanceRecordingStartedAt;
    final duration =
        forcedDuration ??
        (startedAt == null
            ? _guidanceRecordingElapsed
            : DateTime.now().difference(startedAt));

    try {
      if (cancel || duration.inMilliseconds < 400) {
        await _cancelAndDisposeGuidanceRecorder(recorder);
        if (!mounted) return;
        _resetGuidanceRecordingState();
        if (!cancel) {
          _showGuidanceAudioError('Hold longer to record.');
        }
        return;
      }

      final path = await recorder.stop() ?? _guidanceRecordingPath;
      if (path == null) {
        throw StateError('No audio file was recorded.');
      }

      final storage = ref.read(guidanceAudioStorageProvider);
      final audio = await storage.createMetadataForRecordedFile(
        absolutePath: path,
        duration: duration,
      );
      await _disposeGuidanceRecorder(recorder);
      if (!mounted) return;

      final latestState = ref.read(
        routineComposerViewModelProvider(widget.config),
      );
      RoutineComposerStepDraft? latestStep;
      for (final step in latestState.steps) {
        if (step.id == stepId) {
          latestStep = step;
          break;
        }
      }
      final existing = latestStep?.guidanceAudio;
      if (existing != null) {
        unawaited(storage.deleteStoredAudio(existing.localPath));
      }

      _viewModel.setGuidanceAudio(stepId, audio);
      _resetGuidanceRecordingState();
    } catch (_) {
      await _cancelAndDisposeGuidanceRecorder(recorder);
      if (!mounted) return;
      _resetGuidanceRecordingState();
      _showGuidanceAudioError('Failed to save recording.');
    }
  }

  void _cancelGuidanceAudioRecordingForDispose() {
    _guidanceAudioTimer?.cancel();
    final recorder = _guidanceAudioRecorder;
    if (recorder != null) {
      unawaited(_cancelAndDisposeGuidanceRecorder(recorder));
    }
  }

  Future<void> _cancelAndDisposeGuidanceRecorder(AudioRecorder recorder) async {
    try {
      await recorder.cancel();
    } catch (_) {
      // Best effort during teardown.
    }
    await _disposeGuidanceRecorder(recorder);
  }

  Future<void> _disposeGuidanceRecorder(AudioRecorder recorder) async {
    try {
      await recorder.dispose();
    } catch (_) {
      // Best effort during teardown.
    }
    if (identical(_guidanceAudioRecorder, recorder)) {
      _guidanceAudioRecorder = null;
    }
  }

  void _resetGuidanceRecordingState() {
    _guidanceAudioTimer?.cancel();
    _guidanceAudioTimer = null;
    if (!mounted) return;
    _setGuidanceRecordingState(() {
      _guidanceAudioRecorder = null;
      _guidanceRecordingStepId = null;
      _guidanceRecordingPath = null;
      _guidanceRecordingStartedAt = null;
      _guidanceRecordingElapsed = Duration.zero;
      _guidanceRecordingStarting = false;
      _guidanceRecordingStopping = false;
      _guidanceStopAfterStart = false;
      _guidanceCancelAfterStart = false;
    });
  }

  void _setGuidanceRecordingState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    _refreshGuidanceAudioSheet();
  }

  void _refreshGuidanceAudioSheet() {
    final setSheetState = _guidanceAudioSheetSetState;
    if (setSheetState == null) return;
    setSheetState(() {});
  }

  void _showGuidanceAudioError(String message) {
    if (!mounted) return;
    ZenNotifications.showError(context, message: message);
  }

  Future<void> _handleRemoveGuidanceAudio(RoutineComposerStepDraft step) async {
    final audio = step.guidanceAudio;
    if (audio != null) {
      unawaited(
        ref
            .read(guidanceAudioStorageProvider)
            .deleteStoredAudio(audio.localPath),
      );
    }
    _viewModel.removeGuidanceAudio(step.id);
    _refreshGuidanceAudioSheet();
  }

  String? _neighborStepId(List<RoutineComposerStepDraft> steps, String stepId) {
    final index = steps.indexWhere((step) => step.id == stepId);
    if (index == -1) return null;
    if (steps.length == 1) return null;
    if (index < steps.length - 1) {
      return steps[index + 1].id;
    }
    if (index > 0) {
      return steps[index - 1].id;
    }
    return null;
  }

  void _queueFocus(String stepId, {bool adjustSelection = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.setExpandedStep(stepId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToEstimatedStepOffset(stepId);
        final controller = _stepControllers[stepId];
        final focusNode = _stepFocusNodes[stepId];
        focusNode?.requestFocus();
        _ensureFocusedStepVisible(stepId, focusNode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final delayedFocusNode = _stepFocusNodes[stepId];
          _scrollToEstimatedStepOffset(stepId);
          delayedFocusNode?.requestFocus();
          _ensureFocusedStepVisible(stepId, delayedFocusNode);
        });
        if (!adjustSelection || controller == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !(focusNode?.hasFocus ?? false) ||
              controller.text.isEmpty) {
            return;
          }
          _setControllerSelectionSafely(
            controller,
            moveCaretToEnd: controller.text.isNotEmpty,
          );
        });
      });
    });
  }

  void _ensureStepVisible(String stepId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowKeys[stepId]?.currentContext;
      if (rowContext == null) {
        _scrollToEstimatedStepOffset(stepId);
        return;
      }
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  void _ensureFocusedStepVisible(String stepId, FocusNode? focusNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focusContext = focusNode?.context;
      if (focusContext != null) {
        if (!focusContext.mounted) return;
        Scrollable.ensureVisible(
          focusContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.35,
        );
        return;
      }
      _ensureStepVisible(stepId);
    });
  }

  void _scrollToEstimatedStepOffset(String stepId) {
    if (!_scrollController.hasClients) return;
    final state = ref.read(routineComposerViewModelProvider(widget.config));
    final index = state.steps.indexWhere((step) => step.id == stepId);
    if (index == -1) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final targetOffset = math.min(
      maxScrollExtent,
      math.max(0, 112 + index * 92),
    );
    unawaited(
      _scrollController.animateTo(
        targetOffset.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _syncEditingState(RoutineComposerState state) {
    if (!_titleFocusNode.hasFocus) {
      _syncControllerValue(_titleController, state.title);
    }

    final activeIds = state.steps.map((step) => step.id).toSet();
    for (final step in state.steps) {
      _rowKeys.putIfAbsent(step.id, GlobalKey.new);
      final controller = _stepControllers.putIfAbsent(
        step.id,
        () => TextEditingController(text: step.text),
      );
      final focusNode = _stepFocusNodes.putIfAbsent(
        step.id,
        () => _buildFocusNode(step.id),
      );
      if (!focusNode.hasFocus) {
        _syncControllerValue(controller, step.text);
      }
    }

    final staleIds = _stepControllers.keys
        .where((stepId) => !activeIds.contains(stepId))
        .toList(growable: false);
    for (final stepId in staleIds) {
      _stepControllers.remove(stepId)?.dispose();
      _stepFocusNodes.remove(stepId)?.dispose();
      _rowKeys.remove(stepId);
      if (_focusedStepId == stepId) {
        _focusedStepId = null;
      }
    }
  }

  FocusNode _buildFocusNode(String stepId) {
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!mounted) return;
      if (focusNode.hasFocus) {
        if (_focusedStepId != stepId) {
          setState(() => _focusedStepId = stepId);
        }
        _viewModel.setExpandedStep(stepId);
        _ensureStepVisible(stepId);
      } else if (_focusedStepId == stepId) {
        setState(() => _focusedStepId = _findFocusedStepId());
      }
    });
    return focusNode;
  }

  String? _findFocusedStepId() {
    for (final entry in _stepFocusNodes.entries) {
      if (entry.value.hasFocus) {
        return entry.key;
      }
    }
    return null;
  }

  void _syncControllerValue(TextEditingController controller, String nextText) {
    if (controller.text == nextText) return;
    _setControllerText(controller, nextText);
  }

  void _setControllerText(
    TextEditingController controller,
    String nextText, {
    bool moveCaretToEnd = false,
  }) {
    final baseOffset =
        (moveCaretToEnd
                ? nextText.length
                : math.min(
                    math.max(controller.selection.baseOffset, 0),
                    nextText.length,
                  ))
            .toInt();
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: baseOffset),
      composing: TextRange.empty,
    );
  }

  void _setControllerSelectionSafely(
    TextEditingController controller, {
    bool moveCaretToEnd = false,
  }) {
    final offset = moveCaretToEnd && controller.text.isNotEmpty
        ? controller.text.length
        : 0;
    controller.value = controller.value.copyWith(
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

class _GuidanceAudioSheet extends StatelessWidget {
  const _GuidanceAudioSheet({
    required this.step,
    required this.storage,
    required this.canUseGuidanceAudio,
    required this.isRecording,
    required this.isStarting,
    required this.progress,
    required this.elapsed,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
    required this.onRemove,
    required this.onUpgrade,
  });

  final RoutineComposerStepDraft step;
  final GuidanceAudioStorage storage;
  final bool canUseGuidanceAudio;
  final bool isRecording;
  final bool isStarting;
  final double progress;
  final Duration elapsed;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;
  final VoidCallback onRemove;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: cs.onSurface.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    step.guidanceAudio == null
                        ? LucideIcons.volume2
                        : LucideIcons.check,
                    size: 18,
                    color: cs.error,
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
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          color: cs.onSurface,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.text.trim().isEmpty
                            ? 'This step'
                            : step.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.52),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!canUseGuidanceAudio)
              _LockedGuidanceAudio(onUpgrade: onUpgrade)
            else ...[
              Text(
                step.guidanceAudio == null
                    ? 'Record up to 10 seconds of step guidance for this checklist item.'
                    : 'A voice tip is saved. Play it, replace it, or remove it.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 16),
              if (step.guidanceAudio != null) ...[
                Row(
                  children: [
                    GuidanceAudioPlayButton(
                      audio: step.guidanceAudio!,
                      storage: storage,
                      compact: true,
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(LucideIcons.trash2, size: 15),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error.withValues(alpha: 0.86),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              _GuidanceRecordButton(
                label: step.guidanceAudio == null
                    ? 'Hold to record'
                    : 'Hold to re-record',
                isRecording: isRecording,
                isStarting: isStarting,
                progress: progress,
                elapsed: elapsed,
                onRecordStart: onRecordStart,
                onRecordEnd: onRecordEnd,
                onRecordCancel: onRecordCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LockedGuidanceAudio extends StatelessWidget {
  const _LockedGuidanceAudio({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Voice tips are included with Pebble Premium.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onUpgrade,
          icon: const Icon(LucideIcons.lock, size: 16),
          label: const Text('Upgrade for voice tips'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuidanceRecordButton extends StatelessWidget {
  const _GuidanceRecordButton({
    required this.label,
    required this.isRecording,
    required this.isStarting,
    required this.progress,
    required this.elapsed,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
  });

  final String label;
  final bool isRecording;
  final bool isStarting;
  final double progress;
  final Duration elapsed;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foreground = isRecording ? cs.onPrimary : cs.onSurface;
    final fillValue = isRecording ? progress.clamp(0.0, 1.0).toDouble() : 0.0;
    final text = isStarting
        ? 'Starting...'
        : isRecording
        ? 'Release to save (${_formatElapsed(elapsed)})'
        : label;

    return Semantics(
      button: true,
      label: label,
      hint: 'Hold to record, release to save. Maximum 10 seconds.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onRecordStart(),
        onTapUp: (_) => onRecordEnd(),
        onTapCancel: onRecordCancel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isRecording
                  ? cs.primary.withValues(alpha: 0.20)
                  : cs.surfaceContainerHigh,
              border: Border.all(
                color: isRecording
                    ? cs.primary.withValues(alpha: 0.46)
                    : cs.outline.withValues(alpha: 0.62),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fillValue,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.84),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRecording ? LucideIcons.mic : LucideIcons.volume2,
                        size: 18,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsed(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 10);
    final tenths = ((duration.inMilliseconds % 1000) / 100).floor();
    return '$seconds.$tenths s';
  }
}

class _DraftSaveStatus extends StatelessWidget {
  const _DraftSaveStatus({required this.isSaving, required this.showSaved});

  final bool isSaving;
  final bool showSaved;

  @override
  Widget build(BuildContext context) {
    if (!isSaving && !showSaved) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withValues(alpha: 0.46);
    final label = isSaving ? 'Updating...' : 'Ready to finish';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSaved && !isSaving) ...[
            Icon(LucideIcons.check, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneAction extends StatelessWidget {
  const _DoneAction({required this.state, required this.onPressed});

  final RoutineComposerState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = state.canPublish && !state.isPublishing;

    if (state.isPublishing) {
      return const Padding(
        padding: EdgeInsets.only(right: 18),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(LucideIcons.check, size: 16),
        label: const Text('Done'),
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.34),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AddStepButton extends StatelessWidget {
  const _AddStepButton({
    required this.label,
    required this.onPressed,
    required this.subdued,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: subdued
            ? cs.onSecondaryContainer.withValues(alpha: 0.78)
            : cs.onPrimary,
        backgroundColor: subdued ? cs.secondaryContainer : cs.primary,
        disabledBackgroundColor: cs.surfaceContainerHigh,
        disabledForegroundColor: cs.onSurface.withValues(alpha: 0.34),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(LucideIcons.plus, size: 16),
      label: Text(label),
    );
  }
}

enum _DraftExitAction { keep, discard, continueEditing }
