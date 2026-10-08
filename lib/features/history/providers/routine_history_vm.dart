import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_run_repository.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';

/// Keep an open receipt or history detail current as backup and AI finish.
final routineRunProvider = StreamProvider.autoDispose
    .family<RoutineRun?, String>((ref, id) {
      final db = ref.watch(localDbProvider);
      return (db.select(
        db.routineRuns,
      )..where((row) => row.id.equals(id))).watchSingleOrNull();
    });

/// Every run kept on this phone (21 days on every plan), including the ones
/// Free hides. Only for counts and the end-of-Premium summary; screens show
/// [routineHistoryVmProvider].
final storedRoutineRunsProvider = StreamProvider<List<RoutineRun>>((ref) {
  final repo = ref.watch(routineRunRepositoryProvider);
  return repo.watchRuns();
});

/// The history this account can see: the last 48 hours on Free, 21 days with
/// Personal Premium.
final routineHistoryVmProvider = Provider<AsyncValue<List<RoutineRun>>>((ref) {
  final window = ref.watch(accountHistoryRetentionProvider);
  return ref
      .watch(storedRoutineRunsProvider)
      .whenData((runs) => visibleHistoryRuns(runs, window));
});

/// How many kept runs Free is hiding (older than 48 hours). Zero on Premium.
final hiddenHistoryRunCountProvider = Provider<int>((ref) {
  final stored = ref.watch(storedRoutineRunsProvider).valueOrNull ?? const [];
  final visible = ref.watch(routineHistoryVmProvider).valueOrNull ?? const [];
  return stored.length - visible.length;
});

List<RoutineRun> visibleHistoryRuns(
  List<RoutineRun> runs,
  Duration window, {
  DateTime? now,
}) {
  final cutoff = (now ?? DateTime.now()).subtract(window);
  return runs
      .where((run) => run.finishedAt.isAfter(cutoff))
      .toList(growable: false);
}

Future<void> deleteAllRuns(WidgetRef ref) async {
  final repo = ref.read(routineRunRepositoryProvider);
  await repo.deleteAllRuns();
  ref.invalidate(storedRoutineRunsProvider);
}

Future<void> deleteSingleRun(WidgetRef ref, String runId) async {
  final repo = ref.read(routineRunRepositoryProvider);
  await repo.deleteRun(runId);
  ref.invalidate(storedRoutineRunsProvider);
}
