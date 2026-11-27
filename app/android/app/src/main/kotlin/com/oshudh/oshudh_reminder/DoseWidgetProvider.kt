package com.oshudh.oshudh_reminder

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * Home-screen widget: the next dose and, while it is due, a "খেয়েছি" (Taken) button.
 *
 * The app writes a list of upcoming doses with every time already worked out
 * (lib/widget/dose_widget.dart); this shows the first one whose time is not over yet. "Taken"
 * runs the app's own code in the background (onWidgetAction in alarm_runtime.dart), so the dose
 * is recorded and its alarm stopped exactly as from the alarm notification.
 */
class DoseWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val views = render(context, widgetData, System.currentTimeMillis())
    appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
  }

  private fun render(context: Context, data: SharedPreferences, now: Long): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.dose_widget)
    // Tapping the widget opens the app
    views.setOnClickPendingIntent(
        R.id.widget_root,
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
    )
    val snapshot =
        data.getString(SNAPSHOT_KEY, null)?.let { runCatching { JSONObject(it) }.getOrNull() }
            ?: return views // the app has not run yet: the layout's default text
    val texts = snapshot.getJSONObject("texts")
    val entries = snapshot.getJSONArray("entries")
    val entry = (0 until entries.length()).map { entries.getJSONObject(it) }.firstOrNull {
      it.getLong("until") > now
    }

    if (entry == null) {
      views.setTextViewText(R.id.widget_heading, texts.getString("empty"))
      views.setViewVisibility(R.id.widget_time, View.GONE)
      views.setTextViewText(R.id.widget_medicines, "")
      views.setViewVisibility(R.id.widget_taken, View.GONE)
      views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background)
      return views
    }

    val due = now >= entry.getLong("dueFrom")
    val time = entry.getString("time")
    views.setTextViewText(
        R.id.widget_heading,
        texts.getString(if (due) "due" else "next"),
    )
    views.setTextViewText(
        R.id.widget_time,
        if (now < entry.getLong("dayStart")) "${texts.getString("tomorrow")} $time" else time,
    )
    views.setViewVisibility(R.id.widget_time, View.VISIBLE)
    views.setTextViewText(R.id.widget_medicines, entry.getString("medicines"))
    views.setInt(
        R.id.widget_root,
        "setBackgroundResource",
        if (due) R.drawable.widget_due_background else R.drawable.widget_background,
    )
    if (due) {
      views.setTextViewText(R.id.widget_taken, texts.getString("taken"))
      views.setOnClickPendingIntent(
          R.id.widget_taken,
          HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(entry.getString("takenUri"))),
      )
      views.setViewVisibility(R.id.widget_taken, View.VISIBLE)
    } else {
      views.setViewVisibility(R.id.widget_taken, View.GONE)
    }
    return views
  }

  private companion object {
    const val SNAPSHOT_KEY = "dose_widget_v1"
  }
}
