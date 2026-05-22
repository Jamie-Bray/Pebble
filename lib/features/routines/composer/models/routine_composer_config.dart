import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';

enum RoutineComposerEntryPoint { newDraft, editRoutine }

class RoutineComposerConfig {
  final Routine? routine;
  final RoutineComposerSeedData? seedData;
  final RoutineComposerEntryPoint entryPoint;
  final bool forceNewDraft;
  final String? initialStepId;
  final int? initialStepIndex;

  const RoutineComposerConfig.newDraft({this.forceNewDraft = false})
    : routine = null,
      seedData = null,
      entryPoint = RoutineComposerEntryPoint.newDraft,
      initialStepId = null,
      initialStepIndex = null;

  const RoutineComposerConfig.create({
    this.seedData,
    this.forceNewDraft = false,
    this.initialStepId,
    this.initialStepIndex,
  }) : routine = null,
       entryPoint = RoutineComposerEntryPoint.newDraft;

  const RoutineComposerConfig.edit({
    required this.routine,
    this.seedData,
    this.initialStepId,
    this.initialStepIndex,
  }) : entryPoint = RoutineComposerEntryPoint.editRoutine,
       forceNewDraft = false;

  bool get isEdit => routine != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutineComposerConfig &&
        other.routine?.id == routine?.id &&
        other.routine?.updatedAt == routine?.updatedAt &&
        other.seedData == seedData &&
        other.entryPoint == entryPoint &&
        other.forceNewDraft == forceNewDraft &&
        other.initialStepId == initialStepId &&
        other.initialStepIndex == initialStepIndex;
  }

  @override
  int get hashCode => Object.hash(
    routine?.id,
    routine?.updatedAt,
    seedData,
    entryPoint,
    forceNewDraft,
    initialStepId,
    initialStepIndex,
  );
}
