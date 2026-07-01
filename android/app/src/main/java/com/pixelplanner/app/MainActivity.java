package com.pixelplanner.app;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import android.Manifest;
import android.content.pm.PackageManager;
import java.util.ArrayList;

public class MainActivity extends AppCompatActivity {
    private static final int REQUEST_RECORD_AUDIO = 1001;

    private WebView webView;
    private ScheduleNotifier notifier;
    private Handler handler;
    private Runnable pollRunnable;
    private boolean jsReady = false;
    private SpeechRecognizer speechRecognizer;
    private boolean isListening = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        notifier = new ScheduleNotifier(this);
        notifier.showFromCache();

        // 初始化语音识别
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
        speechRecognizer.setRecognitionListener(new VoiceRecognitionListener());

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

        // 立即加载 APK 内置 assets，避免白屏等待
        webView.loadUrl("file:///android_asset/pixel_calendar_new.html");

        // 热更新：后台检查新版本，下载完成后自动切换到最新文件
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
        if (speechRecognizer != null) {
            speechRecognizer.destroy();
            speechRecognizer = null;
        }
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

        @JavascriptInterface
        public void startVoiceRecognition() {
            runOnUiThread(() -> {
                // 检查录音权限
                if (ActivityCompat.checkSelfPermission(MainActivity.this, Manifest.permission.RECORD_AUDIO)
                        != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(MainActivity.this,
                            new String[]{Manifest.permission.RECORD_AUDIO}, REQUEST_RECORD_AUDIO);
                    return;
                }
                if (isListening) return;

                Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN");
                intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
                intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);

                isListening = true;
                speechRecognizer.startListening(intent);
                webView.evaluateJavascript("onVoiceStart()", null);
            });
        }

        @JavascriptInterface
        public void stopVoiceRecognition() {
            runOnUiThread(() -> {
                if (isListening) {
                    isListening = false;
                    speechRecognizer.stopListening();
                }
            });
        }
    }

    /**
     * 语音识别结果监听器
     */
    private class VoiceRecognitionListener implements RecognitionListener {
        @Override
        public void onReadyForSpeech(Bundle params) {
            webView.evaluateJavascript("onVoiceReady()", null);
        }

        @Override
        public void onBeginningOfSpeech() {
            webView.evaluateJavascript("onVoiceSpeaking()", null);
        }

        @Override
        public void onRmsChanged(float rmsdB) {
            // 音量变化，可用于动画
        }

        @Override
        public void onBufferReceived(byte[] buffer) {}

        @Override
        public void onEndOfSpeech() {
            isListening = false;
            webView.evaluateJavascript("onVoiceEnd()", null);
        }

        @Override
        public void onError(int error) {
            isListening = false;
            String msg;
            switch (error) {
                case SpeechRecognizer.ERROR_AUDIO: msg = "麦克风错误"; break;
                case SpeechRecognizer.ERROR_CLIENT: msg = "客户端错误"; break;
                case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS: msg = "权限不足"; break;
                case SpeechRecognizer.ERROR_NETWORK: msg = "网络错误"; break;
                case SpeechRecognizer.ERROR_NETWORK_TIMEOUT: msg = "网络超时"; break;
                case SpeechRecognizer.ERROR_NO_MATCH: msg = "未识别到语音"; break;
                case SpeechRecognizer.ERROR_RECOGNIZER_BUSY: msg = "识别服务忙"; break;
                case SpeechRecognizer.ERROR_SERVER: msg = "服务器错误"; break;
                case SpeechRecognizer.ERROR_SPEECH_TIMEOUT: msg = "未检测到语音"; break;
                default: msg = "未知错误"; break;
            }
            webView.evaluateJavascript("onVoiceError('" + escapeJs(msg) + "')", null);
        }

        @Override
        public void onResults(Bundle results) {
            isListening = false;
            ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (matches != null && !matches.isEmpty()) {
                String text = matches.get(0);
                webView.evaluateJavascript("onVoiceResult('" + escapeJs(text) + "')", null);
            }
        }

        @Override
        public void onPartialResults(Bundle partialResults) {
            ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (matches != null && !matches.isEmpty()) {
                String text = matches.get(0);
                webView.evaluateJavascript("onVoicePartial('" + escapeJs(text) + "')", null);
            }
        }

        @Override
        public void onEvent(int eventType, Bundle params) {}
    }

    private static String escapeJs(String s) {
        return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "");
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_RECORD_AUDIO) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                webView.evaluateJavascript("onVoicePermissionGranted()", null);
            } else {
                webView.evaluateJavascript("onVoiceError('麦克风权限被拒绝')", null);
            }
        }
    }
}
