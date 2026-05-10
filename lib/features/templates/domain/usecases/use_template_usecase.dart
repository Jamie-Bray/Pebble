import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';

class UseTemplateUseCase {
  UseTemplateUseCase(this._routineRepository);

  final RoutineRepository _routineRepository;

  Future<Routine> call(Template template) async {
    final now = DateTime.now();
    final routineSteps = template.steps
        .map((step) {
          final requiresPhoto = Template.stepRequiresPhoto(step);
          final label = Template.cleanStepLabel(step);

          return RoutineStep.check(label: label, requiresPhoto: requiresPhoto);
        })
        .toList(growable: false);
    final routine = Routine(
      id: now.millisecondsSinceEpoch,
      title: template.title,
      stepsJson: jsonEncode(routineSteps.map((step) => step.toJson()).toList()),
      createdAt: now,
      emoji: RoutineIconCatalog.defaultKey,
      colorHex: null,
      isPinned: false,
      pinnedAt: null,
      reminderDay: null,
      reminderTime: null,
      version: 1,
      updatedAt: now,
      cloudId: null,
      ownerUserId: null,
      syncStatus: 'localOnly',
      lastSyncedAt: null,
    );
    await _routineRepository.saveRoutine(routine);
    return routine;
  }
}

final useTemplateUseCaseProvider = Provider<UseTemplateUseCase>((ref) {
  return UseTemplateUseCase(ref.read(routineRepositoryProvider));
});
