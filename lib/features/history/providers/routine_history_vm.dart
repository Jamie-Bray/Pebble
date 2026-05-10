import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_run_repository.dart';

final routineHistoryVmProvider = StreamProvider<List<RoutineRun>>((ref) {
  final repo = ref.watch(routineRunRepositoryProvider);
  return repo.watchRuns();
});

Future<void> deleteAllRuns(WidgetRef ref) async {
  final repo = ref.read(routineRunRepositoryProvider);
  await repo.deleteAllRuns();
  ref.invalidate(routineHistoryVmProvider);
}

Future<void> deleteSingleRun(WidgetRef ref, String runId) async {
  final repo = ref.read(routineRunRepositoryProvider);
  await repo.deleteRun(runId);
  ref.invalidate(routineHistoryVmProvider);
}
