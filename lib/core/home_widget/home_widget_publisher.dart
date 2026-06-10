import 'package:home_widget/home_widget.dart';

import 'package:pebble_routines/core/database/local_db.dart';

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
    final bestAt =
        best.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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

/// Pushes the selected routine (or the empty state) into widget storage and
/// asks the launcher to re-render. Best-effort: a widget problem must never
/// disturb app startup, and on platforms without the plugin this is a no-op.
Future<void> publishHomeWidgetRoutine(Routine? routine) async {
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
    await HomeWidget.updateWidget(
      qualifiedAndroidName: _qualifiedProviderName,
    );
  } catch (_) {
    // Best-effort by design.
  }
}
