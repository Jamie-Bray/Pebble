import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';

/// How long Home (and the home-screen widget) keep showing "Checked" after
/// a run (DESIGN_DIRECTION.md Moment 3). A constant for now; it can become a
/// setting if people ask.
const Duration kCheckedWindow = Duration(hours: 6);

/// Until when a run that finished at [finishedAt] still reads as "Checked"
/// at [now]: the run ended today, less than [kCheckedWindow] ago. Returns
/// null once that has passed (or for a run from an earlier day).
///
/// The cut-off is the earlier of six hours after the run and the next local
/// midnight, so a 23:30 check never shows as "Checked" the next morning.
DateTime? checkedUntil(DateTime finishedAt, DateTime now) {
  final finished = finishedAt.toLocal();
  final local = now.toLocal();
  final sameDay =
      finished.year == local.year &&
      finished.month == local.month &&
      finished.day == local.day;
  if (!sameDay) return null;
  final windowEnd = finished.add(kCheckedWindow);
  final midnight = DateTime(finished.year, finished.month, finished.day + 1);
  final until = windowEnd.isBefore(midnight) ? windowEnd : midnight;
  return local.isBefore(until) ? until : null;
}

/// The photos one run saved, as stored paths, in step order.
List<String> runPhotoPaths(RoutineRun run) {
  final data = decodeRunCompletionData(run.stepCompletionData);
  final steps = data?['steps'];
  if (steps is! List) return const [];
  final paths = <String>[];
  for (final step in steps) {
    if (step is! Map) continue;
    final photos = step['photos'];
    if (photos is! List) continue;
    for (final path in photos) {
      if (path is String && path.isNotEmpty) paths.add(path);
    }
  }
  return paths;
}
