package com.vix.pebble_routines

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Renders the single-routine launcher widget. All data comes from the Flutter
 * side via HomeWidget shared preferences; this class never touches the app
 * database. With no published routine (fresh install, reinstall, or nothing
 * pinned) it falls back to an "Open Pebble" state.
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

            if (routineId != null && !title.isNullOrBlank()) {
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_subtitle, "Tap to start")
                views.setViewVisibility(R.id.widget_dot, View.VISIBLE)
                views.setInt(R.id.widget_dot, "setColorFilter", parseColor(colorHex))
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pebble://play/$routineId"),
                    ),
                )
            } else {
                views.setTextViewText(R.id.widget_title, "Pebble")
                views.setTextViewText(
                    R.id.widget_subtitle,
                    "Open a routine's menu and tap Pin to Widget",
                )
                views.setViewVisibility(R.id.widget_dot, View.GONE)
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
        if (hex.isNullOrBlank()) return DEFAULT_DOT_COLOR
        return try {
            val cleaned = if (hex.startsWith("#")) hex else "#$hex"
            Color.parseColor(cleaned)
        } catch (_: IllegalArgumentException) {
            DEFAULT_DOT_COLOR
        }
    }

    private companion object {
        // Matches the app's warm primary tone closely enough for a fallback.
        const val DEFAULT_DOT_COLOR = 0xFF8A6F5C.toInt()
    }
}
