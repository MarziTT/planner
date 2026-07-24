package com.pixelplanner.app

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val WIDGET_CHANNEL = "com.pixelplanner.widget"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setWidgetData" -> {
                    val dataJson = call.argument<String>("data")
                    if (dataJson != null) {
                        JarvisWidgetProvider.updateWidgets(this, dataJson)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "data is required", null)
                    }
                }
                "updateWidgetCache" -> {
                    val dataJson = call.argument<String>("data")
                    if (dataJson != null) {
                        val cache = JarvisWidgetProvider.getCachePrefs(this)
                        cache.edit().putString("widget_data", dataJson).apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "data is required", null)
                    }
                }
                "setBaseUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        WidgetRefreshWorker.setBaseUrl(this, url)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "url is required", null)
                    }
                }
                "startWidgetRefresh" -> {
                    WidgetRefreshWorker.schedule(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Schedule widget refresh on app start
        WidgetRefreshWorker.schedule(this)
    }
}
