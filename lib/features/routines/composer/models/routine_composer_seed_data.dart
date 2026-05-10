import 'package:pebble_routines/features/routines/composer/models/routine_composer_step_draft.dart';

class RoutineComposerSeedData {
  final String title;
  final String? iconKey;
  final int? colorHex;
  final List<RoutineComposerStepDraft> steps;

  const RoutineComposerSeedData({
    required this.title,
    required this.iconKey,
    required this.colorHex,
    required this.steps,
  });
}
