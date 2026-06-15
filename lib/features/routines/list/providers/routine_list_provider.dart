// lib/features/routines/list/providers/routine_list_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/subscription/domain/routine_limit_policy.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';

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
    // Pure transform only - never write to the DB from inside this stream.
    // Legacy emoji are migrated to icon keys once at startup via
    // RoutineRepository.normalizeLegacyRoutineIcons, and every icon render
    // resolves through RoutineIconCatalog anyway. A write here re-triggered
    // this same stream, churning the routines table and (through
    // routineSessionEntryProvider) resetting live player sessions mid-routine.
    // See risk_areas memory #9.
    final sorted = [...routines]..sort((a, b) {
      // Pinned first, then by creation date (newest first).
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  });
});

final routineAccessListProvider =
    Provider<AsyncValue<List<RoutineAccessState>>>((ref) {
      final policy = ref.watch(routineLimitPolicyProvider);
      return ref.watch(routineListProvider).whenData((routines) {
        return buildRoutineAccessStates(routines: routines, policy: policy);
      });
    });
