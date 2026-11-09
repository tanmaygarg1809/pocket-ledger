package PACKAGE_NAME

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Home-screen widget: net today and this week (income +, spending -), and a + to quick-add. */
class QuickAddWidget : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_DATE_CHANGED -> refreshAll(context)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) update(context, manager, id)
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuickAddWidget::class.java))
            for (id in ids) update(context, manager, id)
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val currency = prefs.getString("flutter.currency_v1", "£") ?: "£"
            val (today, week) = totals(prefs)
            views.setTextViewText(R.id.widget_total, money(currency, today))
            views.setTextColor(R.id.widget_total, if (today < 0) 0xFFC0392B.toInt() else 0xFF0A8A7C.toInt())
            views.setTextViewText(R.id.widget_label, "today")
            views.setTextViewText(R.id.widget_week, "This week " + money(currency, week))

            val intent = Intent(context, QuickAddActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            views.setOnClickPendingIntent(R.id.widget_add, pending)
            manager.updateAppWidget(id, views)
        }

        private fun money(currency: String, v: Double): String =
            (if (v < 0) "-" else "+") + currency + String.format(Locale.getDefault(), "%,.2f", Math.abs(v))

        /** Net (income minus spending) today and since Monday, from the same data the app saves.
         *  Money moved to savings is not counted. */
        private fun totals(prefs: SharedPreferences): Pair<Double, Double> {
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val now = Calendar.getInstance()
            val today = fmt.format(now.time)
            val monday = Calendar.getInstance()
            // Calendar: Sunday = 1 ... Saturday = 7. Days since Monday:
            val sinceMonday = (monday.get(Calendar.DAY_OF_WEEK) + 5) % 7
            monday.add(Calendar.DAY_OF_MONTH, -sinceMonday)
            val weekStart = fmt.format(monday.time)

            var t = 0.0
            var w = 0.0
            try {
                // Daily spending totals written by the app (the entries themselves are encrypted).
                val o = JSONObject(prefs.getString("flutter.widget_days", "{}") ?: "{}")
                val keys = o.keys()
                while (keys.hasNext()) {
                    val day = keys.next()
                    val amount = o.optDouble(day, 0.0)
                    if (day == today) t += amount
                    if (day >= weekStart && day <= today) w += amount
                }
            } catch (_: Exception) {
            }
            return Pair(t, w)
        }
    }
}
