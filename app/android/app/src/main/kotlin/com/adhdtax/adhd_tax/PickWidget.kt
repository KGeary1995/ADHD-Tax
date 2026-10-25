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
 * keep working. The 1.1 look follows the phone's dark mode through
 * values/ and values-night/widget_colors.xml.
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
            fun get(key: String): String = p.getString(key, null) ?: ""
            val title = p.getString("title", null)
            val views = RemoteViews(context.packageName, layout)
            // Data saved by a build before 1.1 has no "header": fall back to
            // its meta line so the widget still reads sensibly.
            val header = get("header").ifBlank { get("meta") }
            views.setImageViewResource(
                R.id.widget_dot,
                if (get("work") == "1") R.drawable.widget_dot_work else R.drawable.widget_dot_personal,
            )
            if (title.isNullOrBlank()) {
                views.setTextViewText(R.id.widget_header, "Gumption")
                views.setTextViewText(R.id.widget_title, "Nothing picked yet")
                views.setTextViewText(R.id.widget_length, "")
                line(
                    views, R.id.widget_line1_row, R.id.widget_line1, R.id.widget_line1_check,
                    get("empty").ifBlank { "Open Gumption and it picks one thing for you." },
                    check = false,
                )
                line(views, R.id.widget_line2_row, R.id.widget_line2, R.id.widget_line2_check, "")
                views.setViewVisibility(R.id.widget_start, View.GONE)
                views.setViewVisibility(R.id.widget_five, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_header, header)
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_length, get("length"))
                val first = get("line1").ifBlank { get("step").removePrefix("First: ") }
                line(views, R.id.widget_line1_row, R.id.widget_line1, R.id.widget_line1_check, first)
                line(views, R.id.widget_line2_row, R.id.widget_line2, R.id.widget_line2_check, get("line2"))
                views.setViewVisibility(R.id.widget_start, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.widget_start,
                    open(context, 1, get("startRoute").ifBlank { "/" }),
                )
                val five = get("fiveRoute")
                views.setViewVisibility(
                    R.id.widget_five,
                    if (five.isBlank()) View.GONE else View.VISIBLE,
                )
                if (five.isNotBlank()) {
                    views.setOnClickPendingIntent(R.id.widget_five, open(context, 5, five))
                }
            }
            val streak = get("streak")
            views.setTextViewText(R.id.widget_streak, if (streak.isBlank()) "" else "✦ $streak")
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

        /** One checklist line: hidden when empty; [check] shows its box. */
        private fun line(
            views: RemoteViews,
            row: Int,
            text: Int,
            box: Int,
            value: String,
            check: Boolean = true,
        ) {
            views.setViewVisibility(row, if (value.isBlank()) View.GONE else View.VISIBLE)
            views.setTextViewText(text, value)
            views.setViewVisibility(box, if (check) View.VISIBLE else View.GONE)
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

/** 2×2: the length, the task, the step you're on, and Start. */
class PickWidgetSquare : PickWidget() {
    override val layout: Int get() = R.layout.pick_widget_square
}

/** 4×3: the card, then two more that fit right now. */
class PickWidgetLarge : PickWidget() {
    override val layout: Int get() = R.layout.pick_widget_large
}
