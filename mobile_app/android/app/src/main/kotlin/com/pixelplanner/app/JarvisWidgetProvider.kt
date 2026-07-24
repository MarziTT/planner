package com.pixelplanner.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * PixelPlanner home screen widget — "管家速览卡片".
 *
 * Displays a compact daily summary:
 *   Header: date + weekday + greeting
 *   Row 1:  meals summary | exercise summary
 *   Row 2:  next schedule event
 *   Row 3:  standing status
 *
 * Data is pushed from Flutter via MethodChannel or refreshed by WorkManager.
 */
class JarvisWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "widget_cache"
        private const val KEY_CACHE_JSON = "widget_data"

        const val ACTION_REFRESH = "com.pixelplanner.app.ACTION_WIDGET_REFRESH"

        fun getCachePrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        /** Update all widget instances from cached JSON or the provided data string. */
        fun updateWidgets(context: Context, dataJson: String? = null) {
            val cache = getCachePrefs(context)
            val json = dataJson ?: cache.getString(KEY_CACHE_JSON, null) ?: return

            cache.edit().putString(KEY_CACHE_JSON, json).apply()

            val manager = AppWidgetManager.getInstance(context)
            val provider = ComponentName(context, JarvisWidgetProvider::class.java)
            val appWidgetIds = manager.getAppWidgetIds(provider)

            if (appWidgetIds.isEmpty()) return

            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            try {
                val root = JSONObject(json)
                applyHeader(views, root.optJSONObject("header"))
                applyMeals(views, root.optJSONObject("meals"))
                applyExercise(views, root.optJSONObject("exercise"))
                applySchedule(views, root.optJSONObject("schedule"))
                applyHealth(views, root.optJSONObject("health"))

                // Click intent: open main app
                val clickIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, clickIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            } catch (e: Exception) {
                views.setTextViewText(R.id.header_date, "DD 管家")
                views.setTextViewText(R.id.header_greeting, "")
                views.setTextViewText(R.id.meals_summary, e.localizedMessage ?: "数据加载失败")
                views.setTextViewText(R.id.exercise_summary, "")
            }

            for (id in appWidgetIds) {
                manager.updateAppWidget(id, views)
            }
        }

        // ---- Section renderers ----

        private fun applyHeader(views: RemoteViews, header: JSONObject?) {
            if (header == null) {
                views.setTextViewText(R.id.header_date, "DD")
                views.setTextViewText(R.id.header_greeting, "")
                return
            }
            val date = header.optString("date", "")
            val weekday = header.optString("weekday", "")
            val greeting = header.optString("greeting", "")

            views.setTextViewText(R.id.header_date, "$date $weekday")
            views.setTextViewText(R.id.header_greeting, greeting)
        }

        private fun applyMeals(views: RemoteViews, meals: JSONObject?) {
            if (meals == null) {
                views.setTextViewText(R.id.meals_summary, "--")
                return
            }

            val summary = meals.optString("summary", "--")
            val totalCal = meals.optInt("total_calories", 0)
            val next = meals.optString("next", null)

            val display = if (totalCal > 0) "$summary · ${totalCal}kcal" else summary
            views.setTextViewText(R.id.meals_summary, display)

            if (next != null && next.isNotEmpty()) {
                views.setTextViewText(R.id.meals_next, next)
                views.setViewVisibility(R.id.meals_next, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.meals_next, android.view.View.GONE)
            }
        }

        private fun applyExercise(views: RemoteViews, exercise: JSONObject?) {
            if (exercise == null) {
                views.setTextViewText(R.id.exercise_summary, "--")
                return
            }

            val summary = exercise.optString("summary", "--")
            val status = exercise.optString("status", "")
            val statusEmoji = exercise.optString("status_emoji", "")

            views.setTextViewText(R.id.exercise_summary, summary)

            if (status.isNotEmpty()) {
                val statusText = if (statusEmoji.isNotEmpty()) "$statusEmoji $status" else status
                views.setTextViewText(R.id.exercise_status, statusText)
                views.setViewVisibility(R.id.exercise_status, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.exercise_status, android.view.View.GONE)
            }
        }

        private fun applySchedule(views: RemoteViews, schedule: JSONObject?) {
            if (schedule == null) {
                views.setTextViewText(R.id.schedule_next, "今日无日程")
                return
            }

            val summary = schedule.optString("summary", "今日无日程")
            val next = schedule.optString("next", null)
            val count = schedule.optInt("count", 0)

            if (next != null && next.isNotEmpty()) {
                views.setTextViewText(R.id.schedule_next, next)
                views.setTextViewText(R.id.schedule_count, "$count 项")
                views.setViewVisibility(R.id.schedule_count, android.view.View.VISIBLE)
            } else {
                views.setTextViewText(R.id.schedule_next, summary)
                views.setViewVisibility(R.id.schedule_count, android.view.View.GONE)
            }
        }

        private fun applyHealth(views: RemoteViews, health: JSONObject?) {
            if (health == null) {
                views.setTextViewText(R.id.health_standing, "--")
                return
            }

            val standLabel = health.optString("stand_label", "--")
            val sleep = health.optString("sleep", null)

            views.setTextViewText(R.id.health_standing, standLabel)

            if (sleep != null && sleep.isNotEmpty()) {
                views.setTextViewText(R.id.health_sleep, sleep)
                views.setViewVisibility(R.id.health_sleep, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.health_sleep, android.view.View.GONE)
            }
        }
    }

    // ---- Lifecycle ----

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle?
    ) {
        updateWidgets(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REFRESH) {
            updateWidgets(context)
        } else {
            super.onReceive(context, intent)
        }
    }
}
