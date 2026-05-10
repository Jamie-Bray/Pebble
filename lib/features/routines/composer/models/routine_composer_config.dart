import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/routines/composer/models/routine_composer_seed_data.dart';

enum RoutineComposerEntryPoint { newDraft, editRoutine, customizeTemplate }

class RoutineComposerConfig {
  final Routine? routine;
  final RoutineComposerSeedData? seedData;
  final RoutineComposerEntryPoint entryPoint;
  final bool forceNewDraft;

  const RoutineComposerConfig.newDraft({this.forceNewDraft = false})
    : routine = null,
      seedData = null,
      entryPoint = RoutineComposerEntryPoint.newDraft;

  const RoutineComposerConfig.customizeTemplate({required this.seedData})
    : routine = null,
      entryPoint = RoutineComposerEntryPoint.customizeTemplate,
      forceNewDraft = true;

  const RoutineComposerConfig.create({
    this.seedData,
    this.forceNewDraft = false,
  }) : routine = null,
       entryPoint = seedData == null
           ? RoutineComposerEntryPoint.newDraft
           : RoutineComposerEntryPoint.customizeTemplate;

  const RoutineComposerConfig.edit({required this.routine, this.seedData})
    : entryPoint = RoutineComposerEntryPoint.editRoutine,
      forceNewDraft = false;

  bool get isEdit => routine != null;
  bool get isTemplateCustomization =>
      entryPoint == RoutineComposerEntryPoint.customizeTemplate;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutineComposerConfig &&
        other.routine?.id == routine?.id &&
        other.routine?.updatedAt == routine?.updatedAt &&
        other.seedData == seedData &&
        other.entryPoint == entryPoint &&
        other.forceNewDraft == forceNewDraft;
  }

  @override
  int get hashCode => Object.hash(
    routine?.id,
    routine?.updatedAt,
    seedData,
    entryPoint,
    forceNewDraft,
  );
}
