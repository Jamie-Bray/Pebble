import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/features/routines/composer/data/routine_composer_draft_repository.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_config.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_draft_snapshot.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_state.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';
import 'package:uuid/uuid.dart';

final routineComposerViewModelProvider = StateNotifierProvider.autoDispose
    .family<
      RoutineComposerViewModel,
      RoutineComposerState,
      RoutineComposerConfig
    >((ref, config) {
      return RoutineComposerViewModel(
        ref.read(routineComposerDraftRepositoryProvider),
        config,
        onCreateDraftsChanged: () {
          ref.invalidate(latestCreateRoutineDraftProvider);
        },
      );
    });

class RoutineComposerViewModel extends StateNotifier<RoutineComposerState> {
  RoutineComposerViewModel(
    this._repository,
    this._config, {
    void Function()? onCreateDraftsChanged,
  }) : _onCreateDraftsChanged = onCreateDraftsChanged,
       super(
         RoutineComposerState.loading(
           mode: _config.isEdit
               ? RoutineComposerMode.edit
               : RoutineComposerMode.create,
           quickSuggestions: _quickSuggestions,
         ),
       ) {
    unawaited(_loadDraft());
  }

  static const _draftSaveDelay = Duration(milliseconds: 500);
  static const _savedConfirmationDuration = Duration(milliseconds: 1500);
  static const _quickSuggestions = [
    'Keys & wallet',
    'Lock doors',
    'Lights off',
    'Phone charged',
    'Water bottle',
    'Take medication',
    'Set alarm',
    'Check windows',
  ];

  final RoutineComposerDraftRepository _repository;
  final RoutineComposerConfig _config;
  final void Function()? _onCreateDraftsChanged;
  final Uuid _uuid = const Uuid();

  Timer? _saveDebounce;
  Timer? _savedConfirmationTimer;
  Future<void>? _ongoingPersist;
  int _revision = 0;
  int _persistedRevision = 0;
  DateTime? _draftCreatedAt;
  String? _draftIconKey;
  int? _draftColorHex;

  Future<void> _loadDraft() async {
    try {
      final snapshot = _config.isEdit
          ? await _repository.loadOrCreateDraft(
              mode: RoutineComposerMode.edit,
              sourceRoutineId: _config.routine?.id,
              seedData:
                  _config.seedData ?? _seedDataFromRoutine(_config.routine),
            )
          : _config.forceNewDraft
          ? await _repository.createFreshDraft()
          : await _repository.loadOrCreateDraft(
              mode: RoutineComposerMode.create,
            );
      if (!mounted) return;
      _draftCreatedAt = snapshot.createdAt;
      _draftIconKey = snapshot.iconKey;
      _draftColorHex = snapshot.colorHex;
      state = RoutineComposerState.fromSnapshot(
        snapshot,
        quickSuggestions: _quickSuggestions,
        initialStepId: _config.initialStepId,
        initialStepIndex: _config.initialStepIndex,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your routine draft.',
      );
    }
  }

  void updateTitle(String value) {
    if (state.isLoading) return;
    _applyDraftMutation(title: value);
  }

  void updateStepText(String stepId, String value) {
    if (state.isLoading) return;
    final updatedSteps = state.steps
        .map((step) => step.id == stepId ? step.copyWith(text: value) : step)
        .toList(growable: false);
    _applyDraftMutation(steps: updatedSteps);
  }

  void setExpandedStep(String? stepId) {
    if (state.expandedStepId == stepId) return;
    state = state.copyWith(expandedStepId: stepId, clearErrorMessage: true);
  }

  String insertStepAfter(String? stepId, {String text = ''}) {
    final nextSteps = [...state.steps];
    final newStep = RoutineComposerStepDraft(
      id: _uuid.v4(),
      text: text,
      requiresPhoto: false,
      allowSkip: false,
      sortOrder: nextSteps.length,
    );
    final insertIndex = stepId == null
        ? nextSteps.length
        : nextSteps.indexWhere((step) => step.id == stepId) + 1;
    nextSteps.insert(insertIndex.clamp(0, nextSteps.length).toInt(), newStep);
    _applyDraftMutation(
      steps: _normalizeSteps(nextSteps),
      expandedStepId: newStep.id,
    );
    return newStep.id;
  }

  void deleteStep(String stepId) {
    final updatedSteps = state.steps
        .where((step) => step.id != stepId)
        .toList(growable: false);
    final nextExpanded = state.expandedStepId == stepId
        ? null
        : state.expandedStepId;
    _applyDraftMutation(
      steps: _normalizeSteps(updatedSteps),
      expandedStepId: nextExpanded,
      clearExpandedStep: nextExpanded == null,
    );
  }

  void toggleRequiresPhoto(String stepId) {
    final updatedSteps = state.steps
        .map(
          (step) => step.id == stepId
              ? step.copyWith(requiresPhoto: !step.requiresPhoto)
              : step,
        )
        .toList(growable: false);
    _applyDraftMutation(steps: updatedSteps, expandedStepId: stepId);
  }

  void toggleAllowSkip(String stepId) {
    final updatedSteps = state.steps
        .map(
          (step) => step.id == stepId
              ? step.copyWith(allowSkip: !step.allowSkip)
              : step,
        )
        .toList(growable: false);
    _applyDraftMutation(steps: updatedSteps, expandedStepId: stepId);
  }

  void setGuidanceAudio(String stepId, StepGuidanceAudio audio) {
    final updatedSteps = state.steps
        .map(
          (step) =>
              step.id == stepId ? step.copyWith(guidanceAudio: audio) : step,
        )
        .toList(growable: false);
    _applyDraftMutation(steps: updatedSteps, expandedStepId: stepId);
  }

  void removeGuidanceAudio(String stepId) {
    final updatedSteps = state.steps
        .map(
          (step) => step.id == stepId
              ? step.copyWith(clearGuidanceAudio: true)
              : step,
        )
        .toList(growable: false);
    _applyDraftMutation(steps: updatedSteps, expandedStepId: stepId);
  }

  Future<void> flushDraft() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    while (mounted && _persistedRevision < _revision) {
      await _persistDraft();
    }
  }

  Future<Routine?> publish() async {
    if (!state.canPublish || state.draftId == null) return null;
    await flushDraft();
    if (!mounted) return null;

    state = state.copyWith(isPublishing: true, clearErrorMessage: true);
    try {
      final routine = await _repository.publishDraft(state.draftId!);
      if (state.mode == RoutineComposerMode.create) {
        _onCreateDraftsChanged?.call();
      }
      _persistedRevision = _revision;
      if (mounted) {
        _clearSavedConfirmationTimer();
        state = state.copyWith(
          isPublishing: false,
          hasUnsavedChanges: false,
          showSavedConfirmation: false,
          clearExpandedStep: true,
        );
      }
      return routine;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isPublishing: false,
          errorMessage: 'Could not save your routine.',
        );
      }
      return null;
    }
  }

  Future<void> discardDraft() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final draftId = state.draftId;
    if (draftId == null) return;
    await _repository.discardDraft(draftId);
    if (state.mode == RoutineComposerMode.create) {
      _onCreateDraftsChanged?.call();
    }
    _persistedRevision = _revision;
    if (!mounted) return;
    _clearSavedConfirmationTimer();
    state = state.copyWith(
      isSavingDraft: false,
      hasUnsavedChanges: false,
      showSavedConfirmation: false,
    );
  }

  void _applyDraftMutation({
    String? title,
    List<RoutineComposerStepDraft>? steps,
    String? expandedStepId,
    bool clearExpandedStep = false,
  }) {
    _revision += 1;
    _clearSavedConfirmationTimer();
    state = state.copyWith(
      title: title,
      steps: steps,
      expandedStepId: expandedStepId,
      clearExpandedStep: clearExpandedStep,
      isSavingDraft: true,
      hasUnsavedChanges: true,
      showSavedConfirmation: false,
      clearErrorMessage: true,
    );
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_draftSaveDelay, () {
      _saveDebounce = null;
      unawaited(_persistDraft());
    });
  }

  Future<void> _persistDraft() {
    if (_ongoingPersist != null) {
      return _ongoingPersist!;
    }
    final future = _performPersist();
    _ongoingPersist = future.whenComplete(() {
      _ongoingPersist = null;
    });
    return _ongoingPersist!;
  }

  Future<void> _performPersist() async {
    if (!mounted || state.draftId == null || _persistedRevision >= _revision) {
      return;
    }

    final revisionToSave = _revision;
    if (mounted) {
      _clearSavedConfirmationTimer();
      state = state.copyWith(isSavingDraft: true, clearErrorMessage: true);
    }

    try {
      await _repository.saveDraft(_snapshotFromState());
      _persistedRevision = revisionToSave;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          isSavingDraft: false,
          hasUnsavedChanges: true,
          showSavedConfirmation: false,
          errorMessage: 'Could not save your draft.',
        );
      }
      return;
    }

    if (!mounted) return;
    final stillDirty = _persistedRevision < _revision;
    state = state.copyWith(
      isSavingDraft: false,
      hasUnsavedChanges: stillDirty,
      showSavedConfirmation: !stillDirty,
    );
    if (!stillDirty) {
      _scheduleSavedConfirmationDismissal();
    }
    if (stillDirty && _saveDebounce == null) {
      _scheduleDraftSave();
    }
  }

  void _scheduleSavedConfirmationDismissal() {
    _clearSavedConfirmationTimer();
    _savedConfirmationTimer = Timer(_savedConfirmationDuration, () {
      _savedConfirmationTimer = null;
      if (!mounted) return;
      state = state.copyWith(showSavedConfirmation: false);
    });
  }

  void _clearSavedConfirmationTimer() {
    _savedConfirmationTimer?.cancel();
    _savedConfirmationTimer = null;
  }

  RoutineComposerDraftSnapshot _snapshotFromState() {
    return RoutineComposerDraftSnapshot(
      draftId: state.draftId!,
      mode: state.mode,
      sourceRoutineId: _config.routine?.id,
      title: state.title,
      iconKey:
          _draftIconKey ?? _config.seedData?.iconKey ?? _config.routine?.emoji,
      colorHex:
          _draftColorHex ??
          _config.seedData?.colorHex ??
          _config.routine?.colorHex,
      steps: _normalizeSteps(state.steps),
      createdAt: _draftCreatedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  RoutineComposerSeedData? _seedDataFromRoutine(Routine? routine) {
    if (routine == null) return null;

    final parsedSteps = <RoutineComposerStepDraft>[];
    try {
      final decoded = jsonDecode(routine.stepsJson);
      if (decoded is List) {
        for (var index = 0; index < decoded.length; index += 1) {
          final step = RoutineStep.fromJson(
            Map<String, dynamic>.from(decoded[index] as Map),
          );
          step.maybeWhen(
            check:
                (
                  label,
                  requiresPhoto,
                  photoCount,
                  photoPrompt,
                  allowSkip,
                  allowGallery,
                  guidanceAudio,
                ) {
                  parsedSteps.add(
                    RoutineComposerStepDraft(
                      id: _uuid.v4(),
                      text: label,
                      requiresPhoto: requiresPhoto,
                      allowSkip: allowSkip,
                      guidanceAudio: guidanceAudio,
                      sortOrder: index,
                    ),
                  );
                },
            orElse: () {},
          );
        }
      }
    } catch (_) {
      // Keep edit mode resilient when legacy JSON cannot be parsed.
    }

    return RoutineComposerSeedData(
      title: routine.title,
      iconKey: routine.emoji,
      colorHex: routine.colorHex,
      steps: parsedSteps.isEmpty ? [_blankStep(0)] : parsedSteps,
    );
  }

  List<RoutineComposerStepDraft> _normalizeSteps(
    List<RoutineComposerStepDraft> steps,
  ) {
    return [
      for (var index = 0; index < steps.length; index += 1)
        steps[index].copyWith(sortOrder: index),
    ];
  }

  RoutineComposerStepDraft _blankStep(int sortOrder) {
    return RoutineComposerStepDraft(
      id: _uuid.v4(),
      text: '',
      requiresPhoto: false,
      allowSkip: false,
      sortOrder: sortOrder,
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _clearSavedConfirmationTimer();
    if (state.draftId != null && _persistedRevision < _revision) {
      _persistedRevision = _revision;
      unawaited(_repository.saveDraft(_snapshotFromState()));
    }
    super.dispose();
  }
}
