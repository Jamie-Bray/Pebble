import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';

/// The hour a "day" starts for the Checked card. A check at 23:50 still
/// reads as done that evening; at 04:00 Home goes back to Start.
const int kCheckedDayStartHour = 4;

/// A reminder this soon after a run belongs to that run (it was done a little
/// early), so it doesn't end the Checked card a few minutes later.
const Duration kCheckedReminderGrace = Duration(hours: 2);

/// When Pebble starts a new "day" after [finishedAt]: the next 04:00.
DateTime checkedDayEnd(DateTime finishedAt) {
  final f = finishedAt.toLocal();
  final sameDay = DateTime(f.year, f.month, f.day, kCheckedDayStartHour);
  return sameDay.isAfter(f)
      ? sameDay
      : DateTime(f.year, f.month, f.day + 1, kCheckedDayStartHour);
}

/// Until when a run that finished at [finishedAt] still reads as "Checked"
/// at [now], or null once that has passed.
///
/// The rule, in plain words: Home shows "Checked" until the routine is next
/// due. That is the routine's next reminder (one at least
/// [kCheckedReminderGrace] after the run), or, with no reminder before then,
/// the start of the next day ([kCheckedDayStartHour]).
DateTime? checkedUntil(
  DateTime finishedAt,
  DateTime now, {
  DateTime? nextReminder,
}) {
  final local = now.toLocal();
  var until = checkedDayEnd(finishedAt);
  final reminder = nextReminder?.toLocal();
  if (reminder != null &&
      reminder.isAfter(finishedAt.toLocal()) &&
      reminder.isBefore(until)) {
    until = reminder;
  }
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
