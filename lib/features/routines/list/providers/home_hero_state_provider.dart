import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:pebble_routines/features/history/domain/checked_window.dart';
import 'package:pebble_routines/features/history/domain/run_step_tally.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';

/// The three faces of the Home hero (DESIGN_DIRECTION.md Moment 3).
enum HomeHeroKind {
  /// "Your next ripple" with Start.
  ready,

  /// A run of this routine is saved part-way: Resume.
  inProgress,

  /// The latest run finished today, less than six hours ago: the answer to
  /// "did I do it?" is the first thing on screen.
  checked,
}

@immutable
class HomeHeroState {
  const HomeHeroState({
    required this.kind,
    this.latestRun,
    this.session,
    this.checkedUntil,
  });

  final HomeHeroKind kind;

  /// The latest finished run of the routine, if any.
  final RoutineRun? latestRun;

  /// The saved, unfinished run (for [HomeHeroKind.inProgress]).
  final RoutineSessionResumeSummary? session;

  /// When the "Checked" state ends (for [HomeHeroKind.checked]).
  final DateTime? checkedUntil;

  /// What the latest run recorded; a skipped step is never counted as done.
  RunStepTally? get tally =>
      latestRun == null ? null : RunStepTally.fromRun(latestRun!);

  /// This run's photos, as stored paths.
  List<String> get photoPaths =>
      latestRun == null ? const [] : runPhotoPaths(latestRun!);
}

/// The clock Home reads, so the "Checked" cut-off can be tested.
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The hero state for one routine. Re-evaluates itself at the "Checked"
/// cut-off, so Home goes back to Start on its own while it is open.
final homeHeroStateProvider = Provider.autoDispose
    .family<HomeHeroState, int>((ref, routineId) {
      final run = ref.watch(latestRoutineRunProvider(routineId)).valueOrNull;
      final sessions =
          ref.watch(activeRoutineSessionsProvider).valueOrNull ??
          const <RoutineSessionResumeSummary>[];
      final now = ref.watch(homeClockProvider)();

      RoutineSessionResumeSummary? session;
      for (final candidate in sessions) {
        if (candidate.routineId == routineId) {
          session = candidate;
          break;
        }
      }
      if (session != null) {
        return HomeHeroState(
          kind: HomeHeroKind.inProgress,
          latestRun: run,
          session: session,
        );
      }

      if (run != null) {
        final until = checkedUntil(run.finishedAt, now);
        if (until != null) {
          final timer = Timer(until.difference(now), ref.invalidateSelf);
          ref.onDispose(timer.cancel);
          return HomeHeroState(
            kind: HomeHeroKind.checked,
            latestRun: run,
            checkedUntil: until,
          );
        }
      }
      return HomeHeroState(kind: HomeHeroKind.ready, latestRun: run);
    });

/// The next time a routine's enabled reminders fire, for the Home meta line
/// ("5 steps · 1 photo · Reminder 8:15 AM"). Null when it has none.
final routineNextReminderProvider = StreamProvider.autoDispose
    .family<DateTime?, int>((ref, routineId) {
      final db = ref.watch(localDbProvider);
      final query = db.select(db.routineReminders)
        ..where(
          (r) => r.routineId.equals(routineId) & r.isEnabled.equals(true),
        );
      return query.watch().map(
        (rows) => nextReminderAt(
          [for (final row in rows) (row.dayOfWeek, row.time)],
          DateTime.now(),
        ),
      );
    });

/// The soonest upcoming (weekday 1-7, "8:15 AM") reminder after [now].
DateTime? nextReminderAt(List<(int, String)> reminders, DateTime now) {
  DateTime? best;
  for (final (day, time) in reminders) {
    final parsed = parseReminderTime(time);
    if (parsed == null || day < 1 || day > 7) continue;
    var daysAhead = (day - now.weekday) % 7;
    var at = DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      parsed.$1,
      parsed.$2,
    );
    if (!at.isAfter(now)) {
      daysAhead += 7;
      at = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        parsed.$1,
        parsed.$2,
      );
    }
    if (best == null || at.isBefore(best)) best = at;
  }
  return best;
}

/// "8:15 AM" / "20:15" → (20, 15).
(int, int)? parseReminderTime(String raw) {
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$',
  ).firstMatch(raw);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final meridiem = match.group(3)?.toUpperCase();
  if (meridiem == 'PM' && hour < 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return (hour, minute);
}
