import 'dart:convert';

import 'package:pebble_routines/core/database/local_db.dart';

/// How the steps of one finished run turned out.
///
/// History, the run detail screen and Home all read this, so a run never
/// reads "4 / 4 done" in one place and "3 of 4" in another. A skipped step is
/// never counted as done.
class RunStepTally {
  const RunStepTally({
    required this.done,
    required this.skipped,
    required this.total,
  });

  final int done;
  final int skipped;
  final int total;

  bool get isComplete => total > 0 && done >= total;

  /// "3 of 4 steps" or, with skips, "3 of 4 steps · 1 skipped".
  String get summary {
    final base = '$done of $total ${total == 1 ? 'step' : 'steps'}';
    return skipped > 0 ? '$base · $skipped skipped' : base;
  }

  static RunStepTally fromRun(RoutineRun run) =>
      fromCompletionData(decodeRunCompletionData(run.stepCompletionData));

  static RunStepTally fromCompletionData(Map<String, dynamic>? data) {
    final steps = data?['steps'];
    final effectiveSteps = data?['effectiveSteps'];
    final total = effectiveSteps is List && effectiveSteps.isNotEmpty
        ? effectiveSteps.length
        : steps is List
        ? steps.length
        : 0;

    // Older runs saved no per-step record; they were only stored on finish.
    if (steps is! List || steps.isEmpty) {
      return RunStepTally(done: total, skipped: 0, total: total);
    }

    var done = 0;
    var skipped = 0;
    for (final raw in steps) {
      if (raw is! Map) continue;
      if (isStepSkipped(raw)) {
        skipped++;
      } else if (isStepDone(raw)) {
        done++;
      }
    }
    return RunStepTally(
      done: done.clamp(0, total),
      skipped: skipped.clamp(0, total),
      total: total,
    );
  }
}

/// True when the step record says it was skipped.
bool isStepSkipped(Map<dynamic, dynamic>? step) => step?['skipped'] == true;

/// True when the step was completed (not skipped).
bool isStepDone(Map<dynamic, dynamic>? step) {
  if (step == null || isStepSkipped(step)) return false;
  return step['completed'] == true ||
      DateTime.tryParse(step['completedAt']?.toString() ?? '') != null;
}

Map<String, dynamic>? decodeRunCompletionData(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Malformed payloads read as "no step record".
  }
  return null;
}
