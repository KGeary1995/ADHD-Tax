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
 * Home-screen widgets: the task Gumption would pick right now, with Start and
 * a quick-add button. Four sizes share one renderer; each layout simply
 * leaves out the views it has no room for. The app pushes the current pick
 * whenever it changes (see MainActivity "updateWidget"); the widgets never
 * compute anything themselves.
 *
 * This class is the original 4×2 card, so widgets placed with earlier builds
 * keep working.
 */
open class PickWidget : AppWidgetProvider() {
    open val layout: Int get() = R.layout.pick_widget

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        val views = render(context, layout)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    companion object {
        const val ACTION_OPEN = "com.adhdtax.adhd_tax.OPEN"
        const val EXTRA_ROUTE = "route"
        private const val PREFS = "unstuck_widget"

        /** Every size, with its layout, so a new pick redraws them all. */
        private val sizes: List<Pair<Class<out PickWidget>, Int>> = listOf(
            PickWidget::class.java to R.layout.pick_widget,
            PickWidgetSmall::class.java to R.layout.pick_widget_small,
            PickWidgetSquare::class.java to R.layout.pick_widget_square,
            PickWidgetLarge::class.java to R.layout.pick_widget_large,
        )

        /** Stores the latest pick and redraws every placed widget. */
        fun save(context: Context, data: Map<String, Any?>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                clear()
                for ((k, v) in data) if (v != null) putString(k, v.toString())
                apply()
            }
            val manager = AppWidgetManager.getInstance(context)
            for ((cls, layout) in sizes) {
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isEmpty()) continue
                val views = render(context, layout)
                for (id in ids) manager.updateAppWidget(id, views)
            }
        }

        // Views a layout doesn't have are skipped by RemoteViews.
        private fun render(context: Context, layout: Int): RemoteViews {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = p.getString("title", null)
            val views = RemoteViews(context.packageName, layout)
            if (title.isNullOrBlank()) {
                views.setTextViewText(R.id.widget_meta, "Gumption")
                views.setTextViewText(R.id.widget_title, "Nothing picked yet")
                views.setTextViewText(
                    R.id.widget_step,
                    p.getString("empty", null) ?: "Open Gumption and it picks one thing for you.",
                )
                views.setViewVisibility(R.id.widget_step, View.VISIBLE)
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

            // "Next up" on the large size: two more that fit right now.
            val alts = listOf(
                Triple(R.id.widget_alt1, R.id.widget_alt1_title, R.id.widget_alt1_meta),
                Triple(R.id.widget_alt2, R.id.widget_alt2_title, R.id.widget_alt2_meta),
            )
            var shown = 0
            for ((i, ids) in alts.withIndex()) {
                val (row, altTitle, altMeta) = ids
                val n = i + 1
                val t = if (title.isNullOrBlank()) null else p.getString("alt${n}Title", null)
                if (t.isNullOrBlank()) {
                    views.setViewVisibility(row, View.GONE)
                    continue
                }
                shown++
                views.setViewVisibility(row, View.VISIBLE)
                views.setTextViewText(altTitle, t)
                views.setTextViewText(altMeta, p.getString("alt${n}Meta", "") ?: "")
                views.setOnClickPendingIntent(
                    row,
                    open(context, 2 + n, p.getString("alt${n}Route", "/") ?: "/"),
                )
            }
            views.setViewVisibility(
                R.id.widget_next_label,
                if (shown > 0) View.VISIBLE else View.GONE,
            )
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

/** 2×1: the task and a Start button. */
class PickWidgetSmall : PickWidget() {
    override val layout: Int get() = R.layout.pick_widget_small
}

/** 2×2: the task with Start and +. */
class PickWidgetSquare : PickWidget() {
    override val layout: Int get() = R.layout.pick_widget_square
}

/** 4×3: the card plus two more that fit right now. */
class PickWidgetLarge : PickWidget() {
    override val layout: Int get() = R.layout.pick_widget_large
}
