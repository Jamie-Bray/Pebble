import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/features/history/domain/checked_window.dart';

const String _qualifiedProviderName =
    'com.vix.pebble_routines.PebbleRoutineWidgetProvider';

/// The routine shown on the home-screen widget: the most recently pinned one.
/// Pinning already means "this matters most", so the widget needs no
/// selection UI of its own. Returns null when nothing is pinned.
Routine? selectWidgetRoutine(List<Routine> routines) {
  Routine? best;
  for (final routine in routines) {
    if (!routine.isPinned) continue;
    if (best == null) {
      best = routine;
      continue;
    }
    final bestAt = best.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final candidateAt =
        routine.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (candidateAt.isAfter(bestAt)) {
      best = routine;
    }
  }
  return best;
}

/// ARGB int -> #AARRGGBB string for the native side, or null for the default.
String? widgetColorHex(int? colorHex) {
  if (colorHex == null) return null;
  return '#${colorHex.toRadixString(16).padLeft(8, '0')}';
}

/// Parses the launch URI fired by a widget tap (pebble://play/<routineId>).
int? routineIdFromWidgetUri(Uri? uri) {
  if (uri == null || uri.scheme != 'pebble' || uri.host != 'play') {
    return null;
  }
  if (uri.pathSegments.isEmpty) return null;
  return int.tryParse(uri.pathSegments.first);
}

/// The latest run of [routine] among [runs], if any.
RoutineRun? latestRunFor(Routine? routine, Iterable<RoutineRun> runs) {
  if (routine == null) return null;
  RoutineRun? latest;
  for (final run in runs) {
    if (run.routineId != routine.id.toString()) continue;
    if (latest == null || run.finishedAt.isAfter(latest.finishedAt)) {
      latest = run;
    }
  }
  return latest;
}

/// What the widget mirrors of Home's "Checked" state (Moment 3): the label
/// ("Checked · 8:04 AM") and when it stops being true. Null when the latest
/// run is outside the window.
({String label, DateTime until})? widgetCheckedState(
  RoutineRun? latestRun,
  DateTime now,
) {
  if (latestRun == null) return null;
  final until = checkedUntil(latestRun.finishedAt, now);
  if (until == null) return null;
  // intl puts a narrow no-break space before AM/PM; launcher fonts don't
  // all have it, so use a plain space.
  final time = DateFormat.jm()
      .format(latestRun.finishedAt.toLocal())
      .replaceAll('\u202f', ' ');
  return (label: 'Checked · $time', until: until);
}

/// Pushes the selected routine (or the empty state) into widget storage and
/// asks the launcher to re-render. Best-effort: a widget problem must never
/// disturb app startup, and on platforms without the plugin this is a no-op.
///
/// With [latestRun] inside the "Checked" window the widget reads
/// "Checked · 8:04 AM" instead of "Tap to start"; the native side drops it
/// on its own once `widget_checked_until` has passed.
Future<void> publishHomeWidgetRoutine(
  Routine? routine, {
  RoutineRun? latestRun,
  DateTime? now,
}) async {
  final checked = widgetCheckedState(latestRun, now ?? DateTime.now());
  try {
    await HomeWidget.saveWidgetData<String?>(
      'widget_routine_id',
      routine?.id.toString(),
    );
    await HomeWidget.saveWidgetData<String?>(
      'widget_routine_title',
      routine?.title,
    );
    await HomeWidget.saveWidgetData<String?>(
      'widget_routine_color',
      widgetColorHex(routine?.colorHex),
    );
    await HomeWidget.saveWidgetData<String?>(
      'widget_checked_label',
      checked?.label,
    );
    await HomeWidget.saveWidgetData<String?>(
      'widget_checked_until',
      checked?.until.millisecondsSinceEpoch.toString(),
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: _qualifiedProviderName,
    );
  } catch (_) {
    // Best-effort by design.
  }
}
