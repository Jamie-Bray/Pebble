import 'package:pebble_routines/features/routines/composer/models/routine_composer_mode.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';

class RoutineComposerDraftSnapshot {
  final String draftId;
  final RoutineComposerMode mode;
  final int? sourceRoutineId;
  final String title;
  final String? iconKey;
  final int? colorHex;
  final List<RoutineComposerStepDraft> steps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoutineComposerDraftSnapshot({
    required this.draftId,
    required this.mode,
    required this.sourceRoutineId,
    required this.title,
    required this.iconKey,
    required this.colorHex,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
  });

  RoutineComposerDraftSnapshot copyWith({
    String? draftId,
    RoutineComposerMode? mode,
    int? sourceRoutineId,
    String? title,
    String? iconKey,
    int? colorHex,
    List<RoutineComposerStepDraft>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoutineComposerDraftSnapshot(
      draftId: draftId ?? this.draftId,
      mode: mode ?? this.mode,
      sourceRoutineId: sourceRoutineId ?? this.sourceRoutineId,
      title: title ?? this.title,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
