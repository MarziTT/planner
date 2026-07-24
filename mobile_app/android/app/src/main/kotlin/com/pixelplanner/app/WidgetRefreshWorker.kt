package com.pixelplanner.app

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class WidgetRefreshWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val WORK_NAME = "widget_refresh_periodic"
        private const val PREFS_AUTH = "auth_prefs"
        private const val KEY_TOKEN = "access_token"
        private const val KEY_BASE_URL = "base_url"
        private const val DEFAULT_BASE_URL = "https://jarvis-api.example.com"

        private val client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }

        fun setBaseUrl(context: Context, url: String) {
            context.getSharedPreferences(PREFS_AUTH, Context.MODE_PRIVATE)
                .edit().putString(KEY_BASE_URL, url).apply()
        }
    }

    override suspend fun doWork(): Result {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_AUTH, Context.MODE_PRIVATE)
            val token = prefs.getString(KEY_TOKEN, null) ?: return Result.retry()
            val baseUrl = prefs.getString(KEY_BASE_URL, DEFAULT_BASE_URL) ?: DEFAULT_BASE_URL

            val request = Request.Builder()
                .url("$baseUrl/api/v1/widget/summary")
                .header("Authorization", "Bearer $token")
                .get()
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                if (response.code == 401) return Result.failure()
                return Result.retry()
            }

            val body = response.body?.string() ?: return Result.retry()
            val root = JSONObject(body)

            // Widget summary API returns {"ok": true, "data": {...}}
            val widgetData = if (root.has("data")) {
                root.getJSONObject("data")
            } else {
                root
            }

            JarvisWidgetProvider.getCachePrefs(applicationContext)
                .edit()
                .putString("widget_data", widgetData.toString())
                .apply()

            val refreshIntent = android.content.Intent(JarvisWidgetProvider.ACTION_REFRESH)
            refreshIntent.setClass(applicationContext, JarvisWidgetProvider::class.java)
            applicationContext.sendBroadcast(refreshIntent)

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
