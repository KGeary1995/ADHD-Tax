package com.adhdtax.adhd_tax

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen widget: the task Unstuck would pick right now, with Start and
 * a quick-add button. The app pushes the current pick whenever it changes
 * (see MainActivity "updateWidget"); the widget itself never computes.
 */
class PickWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        for (id in ids) manager.updateAppWidget(id, render(context))
    }

    companion object {
        const val ACTION_OPEN = "com.adhdtax.adhd_tax.OPEN"
        const val EXTRA_ROUTE = "route"
        private const val PREFS = "unstuck_widget"

        /** Stores the latest pick and redraws every placed widget. */
        fun save(context: Context, data: Map<String, Any?>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                clear()
                for ((k, v) in data) if (v != null) putString(k, v.toString())
                apply()
            }
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PickWidget::class.java))
            if (ids.isNotEmpty()) {
                val views = render(context)
                for (id in ids) manager.updateAppWidget(id, views)
            }
        }

        private fun render(context: Context): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = p.getString("title", null)
            val views = RemoteViews(context.packageName, R.layout.pick_widget)
            if (title.isNullOrBlank()) {
                views.setTextViewText(R.id.widget_meta, "Unstuck")
                views.setTextViewText(R.id.widget_title, "Nothing picked yet")
                views.setTextViewText(
                    R.id.widget_step,
                    p.getString("empty", null) ?: "Open Unstuck and it picks one thing for you.",
                )
                views.setViewVisibility(R.id.widget_start, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_meta, p.getString("meta", "") ?: "")
                views.setTextViewText(R.id.widget_title, title)
                val step = p.getString("step", "") ?: ""
                views.setTextViewText(R.id.widget_step, step)
                views.setViewVisibility(
                    R.id.widget_step,
                    if (step.isBlank()) View.GONE else View.VISIBLE,
                )
                views.setViewVisibility(R.id.widget_start, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.widget_start,
                    open(context, 1, p.getString("startRoute", "/") ?: "/"),
                )
            }
            views.setOnClickPendingIntent(R.id.widget_root, open(context, 0, "/"))
            views.setOnClickPendingIntent(R.id.widget_add, open(context, 2, "/add"))
            return views
        }

        private fun open(context: Context, code: Int, route: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_OPEN
                putExtra(EXTRA_ROUTE, route)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
