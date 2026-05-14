import 'package:pebble_routines/features/routines/composer/models/routine_composer_draft_snapshot.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';

class RoutineComposerState {
  final bool isLoading;
  final String? draftId;
  final RoutineComposerMode mode;
  final String title;
  final List<RoutineComposerStepDraft> steps;
  final String? expandedStepId;
  final bool isSavingDraft;
  final bool isPublishing;
  final bool hasUnsavedChanges;
  final bool showSavedConfirmation;
  final bool canPublish;
  final List<String> quickSuggestions;
  final String? errorMessage;

  const RoutineComposerState({
    required this.isLoading,
    required this.draftId,
    required this.mode,
    required this.title,
    required this.steps,
    required this.expandedStepId,
    required this.isSavingDraft,
    required this.isPublishing,
    required this.hasUnsavedChanges,
    required this.showSavedConfirmation,
    required this.canPublish,
    required this.quickSuggestions,
    required this.errorMessage,
  });

  factory RoutineComposerState.loading({
    required RoutineComposerMode mode,
    required List<String> quickSuggestions,
  }) {
    return RoutineComposerState(
      isLoading: true,
      draftId: null,
      mode: mode,
      title: '',
      steps: const [],
      expandedStepId: null,
      isSavingDraft: false,
      isPublishing: false,
      hasUnsavedChanges: false,
      showSavedConfirmation: false,
      canPublish: false,
      quickSuggestions: List<String>.unmodifiable(quickSuggestions),
      errorMessage: null,
    );
  }

  factory RoutineComposerState.fromSnapshot(
    RoutineComposerDraftSnapshot snapshot, {
    required List<String> quickSuggestions,
    String? initialStepId,
    int? initialStepIndex,
  }) {
    final expandedStepId = _initialExpandedStepId(
      snapshot,
      initialStepId: initialStepId,
      initialStepIndex: initialStepIndex,
    );
    return RoutineComposerState(
      isLoading: false,
      draftId: snapshot.draftId,
      mode: snapshot.mode,
      title: snapshot.title,
      steps: List<RoutineComposerStepDraft>.unmodifiable(snapshot.steps),
      expandedStepId: expandedStepId,
      isSavingDraft: false,
      isPublishing: false,
      hasUnsavedChanges: false,
      showSavedConfirmation: false,
      canPublish: _canPublish(snapshot.steps),
      quickSuggestions: List<String>.unmodifiable(quickSuggestions),
      errorMessage: null,
    );
  }

  static String? _initialExpandedStepId(
    RoutineComposerDraftSnapshot snapshot, {
    String? initialStepId,
    int? initialStepIndex,
  }) {
    if (snapshot.steps.isEmpty) return null;
    if (initialStepId != null &&
        snapshot.steps.any((step) => step.id == initialStepId)) {
      return initialStepId;
    }
    if (initialStepIndex != null &&
        initialStepIndex >= 0 &&
        initialStepIndex < snapshot.steps.length) {
      return snapshot.steps[initialStepIndex].id;
    }
    return snapshot.steps.first.id;
  }

  RoutineComposerState copyWith({
    bool? isLoading,
    String? draftId,
    RoutineComposerMode? mode,
    String? title,
    List<RoutineComposerStepDraft>? steps,
    String? expandedStepId,
    bool clearExpandedStep = false,
    bool? isSavingDraft,
    bool? isPublishing,
    bool? hasUnsavedChanges,
    bool? showSavedConfirmation,
    List<String>? quickSuggestions,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    final nextSteps = List<RoutineComposerStepDraft>.unmodifiable(
      steps ?? this.steps,
    );
    return RoutineComposerState(
      isLoading: isLoading ?? this.isLoading,
      draftId: draftId ?? this.draftId,
      mode: mode ?? this.mode,
      title: title ?? this.title,
      steps: nextSteps,
      expandedStepId: clearExpandedStep
          ? null
          : expandedStepId ?? this.expandedStepId,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isPublishing: isPublishing ?? this.isPublishing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      showSavedConfirmation:
          showSavedConfirmation ?? this.showSavedConfirmation,
      canPublish: _canPublish(nextSteps),
      quickSuggestions: List<String>.unmodifiable(
        quickSuggestions ?? this.quickSuggestions,
      ),
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  static bool _canPublish(List<RoutineComposerStepDraft> steps) {
    return steps.any((step) => step.text.trim().isNotEmpty);
  }
}
