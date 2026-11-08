package PACKAGE_NAME

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Home-screen widget: shows today's spending, tap anywhere to quick-add. */
class QuickAddWidget : AppWidgetProvider() {

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
            val (label, value) = headline(context)
            views.setTextViewText(R.id.widget_label, label)
            views.setTextViewText(R.id.widget_total, value)

            val intent = Intent(context, QuickAddActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }

        private fun headline(context: Context): Pair<String, String> {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            // The app saves "Left today" (from your budgets) with today's date.
            // If it is stale (a new day) or there are no budgets, show spending.
            if (prefs.getString("flutter.widget_date", null) == today) {
                val label = prefs.getString("flutter.widget_label", null)
                val value = prefs.getString("flutter.widget_value", null)
                if (label != null && value != null) return Pair(label, value)
            }
            return Pair("Spent today", todayTotal(prefs, today))
        }

        // Reads the same SharedPreferences file the Flutter app writes to.
        private fun todayTotal(prefs: SharedPreferences, today: String): String {
            val currency = prefs.getString("flutter.currency_v1", "£") ?: "£"
            var total = 0.0
            try {
                val arr = JSONArray(prefs.getString("flutter.txns_v1", "[]") ?: "[]")
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    if (!o.optBoolean("d", false) &&
                        o.optString("type") == "expense" &&
                        o.optString("date").startsWith(today)
                    ) {
                        total += o.optDouble("amount", 0.0)
                    }
                }
            } catch (_: Exception) {
            }
            return currency + String.format(Locale.getDefault(), "%,.2f", total)
        }
    }
}
