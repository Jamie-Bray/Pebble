package com.vix.pebble_routines

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Renders the single-routine launcher widget. All data comes from the Flutter
 * side via HomeWidget shared preferences; this class never touches the app
 * database. With no published routine (fresh install, reinstall, or nothing
 * chosen with "Show on widget") it falls back to an "Open Pebble" state.
 *
 * Copy here follows COPY_GUIDELINES.md and must match the app's labels.
 */
class PebbleRoutineWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pebble_routine_widget)

            val routineId = widgetData.getString("widget_routine_id", null)
            val title = widgetData.getString("widget_routine_title", null)
            val colorHex = widgetData.getString("widget_routine_color", null)
            // Mirrors Home's "Checked" state ("Checked · 8:04 AM") until the
            // Flutter side's cut-off, so a stale check never shows.
            val checkedLabel = widgetData.getString("widget_checked_label", null)
            val checkedUntil = widgetData
                .getString("widget_checked_until", null)
                ?.toLongOrNull() ?: 0L
            val isChecked = !checkedLabel.isNullOrBlank() &&
                System.currentTimeMillis() < checkedUntil

            if (routineId != null && !title.isNullOrBlank()) {
                val badgeColor = parseColor(colorHex)
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(
                    R.id.widget_subtitle,
                    if (isChecked) checkedLabel else "Tap to start",
                )
                views.setInt(R.id.widget_dot, "setColorFilter", badgeColor)
                views.setImageViewResource(
                    R.id.widget_icon,
                    if (isChecked) R.drawable.widget_ic_check else R.drawable.widget_ic_play,
                )
                views.setInt(R.id.widget_icon, "setColorFilter", iconColorOn(badgeColor))
                views.setContentDescription(
                    R.id.widget_root,
                    if (isChecked) "Start $title. $checkedLabel" else "Start $title",
                )
                // The URI is read in Dart (home_widget); Flutter's own deep
                // linking is off in AndroidManifest.xml.
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pebble://play/$routineId"),
                    ),
                )
            } else {
                // Matches the routine menu's "Show on widget" row.
                views.setTextViewText(R.id.widget_title, "Choose a routine")
                views.setTextViewText(
                    R.id.widget_subtitle,
                    "Use Show on widget in Pebble",
                )
                views.setInt(R.id.widget_dot, "setColorFilter", DEFAULT_BADGE_COLOR)
                views.setImageViewResource(R.id.widget_icon, R.drawable.widget_ic_play)
                views.setInt(R.id.widget_icon, "setColorFilter", Color.WHITE)
                views.setContentDescription(R.id.widget_root, "Open Pebble")
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                    ),
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseColor(hex: String?): Int {
        if (hex.isNullOrBlank()) return DEFAULT_BADGE_COLOR
        return try {
            val cleaned = if (hex.startsWith("#")) hex else "#$hex"
            Color.parseColor(cleaned) or OPAQUE
        } catch (_: IllegalArgumentException) {
            DEFAULT_BADGE_COLOR
        }
    }

    /** White on darker routine colours, deep green on light ones. */
    private fun iconColorOn(background: Int): Int {
        val luminance = (0.2126 * channel(Color.red(background))) +
            (0.7152 * channel(Color.green(background))) +
            (0.0722 * channel(Color.blue(background)))
        return if (luminance > 0.45) DARK_ICON_COLOR else Color.WHITE
    }

    private fun channel(value: Int): Double {
        val c = value / 255.0
        return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
    }

    private companion object {
        // Pebble's deep green (the default theme's accent).
        const val DEFAULT_BADGE_COLOR = 0xFF4A5D4E.toInt()
        const val DARK_ICON_COLOR = 0xFF2D3A30.toInt()
        const val OPAQUE = 0xFF000000.toInt()
    }
}
