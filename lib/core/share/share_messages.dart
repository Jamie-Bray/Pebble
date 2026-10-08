import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/database/routine_step.dart';
import 'package:pebble_routines/core/share/shared_routine_link.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';

/// The Pebble website, linked from shared routines and "Tell a friend".
const String pebbleShareWebsite = 'pebbleroutines.com';

/// One step of a finished run, as a shared summary lists it.
class SharedRunStep {
  const SharedRunStep({
    required this.label,
    this.completedAt,
    this.skipped = false,
  });

  final String label;
  final DateTime? completedAt;
  final bool skipped;
}

/// The plain text Pebble hands to the phone's share sheet.
///
/// Pebble never sends these itself. The person picks Messages, WhatsApp or
/// email and presses send, so there is no cost, no consent step and nothing
/// to abuse. Photos are never included.
class ShareMessages {
  const ShareMessages._();

  /// What a finished run looked like:
  ///
  /// ```
  /// Bedtime house check
  /// Completed at 22:14 on Tuesday 7 October
  ///
  /// ✓ Back door locked, 22:02
  /// – Windows shut, skipped
  ///
  /// Recorded in Pebble · pebbleroutines.com
  /// ```
  ///
  /// [formatTime] matches how the phone shows times (12 or 24 hour).
  static String runSummary({
    required String routineTitle,
    required DateTime finishedAt,
    required List<SharedRunStep> steps,
    required String Function(DateTime) formatTime,
  }) {
    final title = _titleOr(routineTitle, 'Routine');
    final local = finishedAt.toLocal();
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln(
        'Completed at ${formatTime(local)} on '
        '${DateFormat.MMMMEEEEd().format(local)}',
      );
    if (steps.isNotEmpty) {
      buffer.writeln();
      for (final step in steps) {
        final label = _titleOr(step.label, 'Step');
        if (step.skipped) {
          buffer.writeln('– $label, skipped');
        } else if (step.completedAt != null) {
          buffer.writeln(
            '✓ $label, ${formatTime(step.completedAt!.toLocal())}',
          );
        } else {
          buffer.writeln('✓ $label');
        }
      }
    }
    buffer
      ..writeln()
      ..write('Recorded in Pebble · $pebbleShareWebsite');
    return buffer.toString();
  }

  /// The steps of a finished run, read from its saved record. Notes (info
  /// steps) are left out: they are read, not done.
  static List<SharedRunStep> stepsFromRun(RoutineRun run) {
    final data = decodeRunCompletionData(run.stepCompletionData);
    final records = data?['steps'] is List ? data!['steps'] as List : const [];
    final effective = data?['effectiveSteps'] is List
        ? (data!['effectiveSteps'] as List)
        : null;
    final count = effective?.length ?? records.length;
    final steps = <SharedRunStep>[];
    for (var i = 0; i < count; i++) {
      final record = i < records.length && records[i] is Map
          ? records[i] as Map
          : null;
      String? label;
      if (effective != null) {
        final raw = effective[i];
        if (raw is! Map) continue;
        final RoutineStep step;
        try {
          step = RoutineStep.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {
          continue;
        }
        if (step is InfoStep) continue;
        label = stepLabel(step);
      } else {
        label = record?['label']?.toString();
      }
      final skipped = isStepSkipped(record);
      // Runs saved before per-step records existed read as done, as they do
      // in History.
      final done = records.isEmpty || isStepDone(record);
      if (!skipped && !done) continue;
      steps.add(
        SharedRunStep(
          label: label ?? 'Step ${i + 1}',
          skipped: skipped,
          completedAt: skipped
              ? null
              : DateTime.tryParse(record?['completedAt']?.toString() ?? ''),
        ),
      );
    }
    return steps;
  }

  /// A routine as a checklist someone else can follow, such as a house
  /// sitter or a partner:
  ///
  /// ```
  /// House sitter handover
  ///
  /// 1. Water the plants
  /// 2. Lock the back door
  /// Note: the spare key is under the blue pot
  ///
  /// Add it to Pebble:
  /// https://pebbleroutines.com/r#…
  /// ```
  ///
  /// The link opens the routine in Pebble, or a page with the steps and the
  /// app store links for someone without the app.
  static String routineChecklist({
    required String routineTitle,
    required List<RoutineStep> steps,
    bool includeAddLink = true,
  }) {
    final buffer = StringBuffer()..writeln(_titleOr(routineTitle, 'Routine'));
    if (steps.isNotEmpty) buffer.writeln();
    var number = 0;
    for (final step in steps) {
      if (step is InfoStep) {
        final note = step.message.trim();
        if (note.isNotEmpty) buffer.writeln('Note: $note');
        continue;
      }
      number++;
      buffer.writeln('$number. ${stepLabel(step)}');
    }
    buffer.writeln();
    final shared = SharedRoutine(title: routineTitle, steps: steps);
    if (includeAddLink && steps.whereType<CheckStep>().isNotEmpty) {
      // The link on its own line, so messaging apps show it whole and
      // build their preview card from it.
      buffer
        ..writeln('Add it to Pebble:')
        ..write(shared.toLink());
    } else {
      buffer.write('Made in Pebble, a checklist app: $pebbleShareWebsite');
    }
    return buffer.toString();
  }

  /// [routineChecklist] for a saved routine, reading its stored steps.
  static String routineChecklistFor(Routine routine) {
    return routineChecklist(
      routineTitle: routine.title,
      steps: _decodeStoredSteps(routine.stepsJson),
    );
  }

  /// Saved steps, including the older shape without a `runtimeType`.
  static List<RoutineStep> _decodeStoredSteps(String stepsJson) {
    if (stepsJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(stepsJson);
      if (decoded is! List) return const [];
      final steps = <RoutineStep>[];
      for (final item in decoded.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        try {
          steps.add(
            map['runtimeType'] != null
                ? RoutineStep.fromJson(map)
                : RoutineStep.check(label: map['label']?.toString() ?? ''),
          );
        } catch (_) {
          // Skip a step that can't be read rather than sharing nothing.
        }
      }
      return steps;
    } catch (_) {
      return const [];
    }
  }

  /// A step as a line of text. Timers read "Wait 5 minutes".
  static String stepLabel(RoutineStep step) {
    return switch (step) {
      CheckStep(:final label) => _titleOr(label, 'Step'),
      InfoStep(:final message) => _titleOr(message, 'Note'),
      TimerStep(:final duration) => 'Wait ${_duration(duration)}',
      _ => 'Step',
    };
  }

  /// The email subject for a shared run: "Bedtime house check, completed".
  static String runSubject(String routineTitle) =>
      '${_titleOr(routineTitle, 'Routine')}, completed';

  /// The email subject for a shared routine or template.
  static String routineSubject(String routineTitle) =>
      _titleOr(routineTitle, 'Routine');

  /// The email subject for "Tell a friend about Pebble".
  static const String appInviteSubject = 'Pebble';

  /// "Tell a friend about Pebble".
  static const String appInvite =
      'I use Pebble for the checks I do every day, like locking up and '
      'switching things off. It saves the time of every check, so I can look '
      'back instead of going back. $pebbleShareWebsite';

  static String _duration(int seconds) {
    if (seconds >= 60 && seconds % 60 == 0) {
      final minutes = seconds ~/ 60;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    if (seconds > 60) {
      return '${seconds ~/ 60} min ${seconds % 60} sec';
    }
    return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
  }

  static String _titleOr(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
