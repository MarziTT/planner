package com.pixelplanner.app;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    private WebView webView;
    private ScheduleNotifier notifier;
    private Handler handler;
    private Runnable pollRunnable;
    private boolean jsReady = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        notifier = new ScheduleNotifier(this);
        notifier.showFromCache();

        webView = findViewById(R.id.webview);
        WebSettings webSettings = webView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setDatabaseEnabled(true);
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowContentAccess(true);
        webSettings.setUseWideViewPort(true);
        webSettings.setLoadWithOverviewMode(true);
        webSettings.setSupportZoom(true);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);

        webView.addJavascriptInterface(new JsBridge(), "AndroidBridge");
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                if (url.contains("pixel_calendar_new.html") || url.contains("pixel_calendar.html")) {
                    jsReady = true;
                    refreshScheduleNotification();
                    startPolling();
                }
            }
        });

        // 热更新：启动时自动检查版本并下载，内部存储优先
        HotUpdateManager hotUpdate = new HotUpdateManager(this);
        hotUpdate.checkAndUpdate(loadUrl -> webView.loadUrl(loadUrl));
    }

    private void refreshScheduleNotification() {
        if (!jsReady || webView == null) return;
        webView.evaluateJavascript("getTodayEventsForAndroid()", value -> {
            if (value != null && !value.equals("null") && value.startsWith("[") && value.length() > 2) {
                notifier.refresh(unjson(value));
            } else {
                notifier.refresh("[]");
            }
        });
    }

    private void startPolling() {
        handler = new Handler(Looper.getMainLooper());
        pollRunnable = new Runnable() {
            @Override
            public void run() {
                refreshScheduleNotification();
                handler.postDelayed(this, 5 * 60 * 1000); // 5 min
            }
        };
        handler.postDelayed(pollRunnable, 5 * 60 * 1000);
    }

    private void stopPolling() {
        if (handler != null && pollRunnable != null) {
            handler.removeCallbacks(pollRunnable);
        }
    }

    @Override
    protected void onDestroy() {
        stopPolling();
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    private static String unjson(String jsonStr) {
        if (jsonStr.startsWith("\"") && jsonStr.endsWith("\"")) {
            String s = jsonStr.substring(1, jsonStr.length() - 1);
            return s.replace("\\\"", "\"").replace("\\\\", "\\");
        }
        return jsonStr;
    }

    public class JsBridge {
        @JavascriptInterface
        public void refreshNotification() {
            runOnUiThread(() -> refreshScheduleNotification());
        }
    }
}
