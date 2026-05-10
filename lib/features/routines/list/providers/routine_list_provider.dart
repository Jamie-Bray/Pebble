// lib/features/routines/list/providers/routine_list_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

class HomeRoutineHighlight {
  const HomeRoutineHighlight({required this.routineId, required this.message});

  final int routineId;
  final String message;
}

final homeRoutineHighlightProvider = StateProvider<HomeRoutineHighlight?>(
  (ref) => null,
);

Routine? selectHomeSpotlightRoutine({
  required List<Routine> routines,
  required List<RoutineRun> runs,
}) {
  if (routines.isEmpty) return null;

  final routinesById = {for (final routine in routines) routine.id: routine};
  final sortedRuns = [...runs]
    ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  for (final run in sortedRuns) {
    final routineId = int.tryParse(run.routineId);
    final routine = routineId == null ? null : routinesById[routineId];
    if (routine != null) {
      return routine;
    }
  }

  for (final routine in routines) {
    if (routine.isPinned) {
      return routine;
    }
  }

  return routines.first;
}

final routineListProvider = StreamProvider<List<Routine>>((ref) {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.watchRoutines().map((routines) {
    for (final routine in routines) {
      final normalizedIconKey = RoutineIconCatalog.resolve(routine.emoji).key;
      if (routine.emoji == normalizedIconKey) continue;

      // Background one-time normalization of legacy emoji records to icon keys.
      unawaited(
        repo.saveRoutine(
          Routine(
            id: routine.id,
            title: routine.title,
            stepsJson: routine.stepsJson,
            createdAt: routine.createdAt,
            emoji: normalizedIconKey,
            colorHex: routine.colorHex,
            isPinned: routine.isPinned,
            pinnedAt: routine.pinnedAt,
            version: routine.version,
            updatedAt: DateTime.now(),
            cloudId: routine.cloudId,
            ownerUserId: routine.ownerUserId,
            syncStatus: routine.syncStatus,
            lastSyncedAt: routine.lastSyncedAt,
          ),
        ),
      );
    }

    // Sort routines: pinned first, then by creation date (newest first)
    routines.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return routines;
  });
});
