package com.pixelplanner.app;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * HotUpdateManager — 热更新机制
 *
 * App 启动时从本地 HTTP 服务器检测新版本，自动下载最新 HTML/JS/CSS 到
 * 内部存储 (getFilesDir)，下次启动直接从内部存储加载，无需重装 APK。
 */
public class HotUpdateManager {

    private static final String TAG = "HotUpdateManager";

    /** 服务器地址，可通过 setServerUrl() 修改 */
    public static String SERVER_URL = "https://planner-production-d1ee.up.railway.app";

    private static final String PREFS_NAME = "hot_update_prefs";
    private static final String KEY_VERSION = "local_version";

    private final Context context;
    private final Handler mainHandler;

    /** 回调接口 */
    public interface UpdateCallback {
        /** 版本检查完成（含下载），返回应加载的 URL */
        void onReady(String loadUrl);
    }

    public HotUpdateManager(Context context) {
        this.context = context.getApplicationContext();
        this.mainHandler = new Handler(Looper.getMainLooper());
    }

    /**
     * 启动版本检查与更新流程（在后台线程执行）。
     *
     * 流程：
     *   1. 读取 SharedPreferences 中缓存的本地版本号
     *   2. 请求 /api/version 获取服务端最新版本
     *   3. 如果本地版本低于服务端（或首次安装无版本），逐文件下载
     *   4. 下载完成后更新 SharedPreferences 版本号
     *   5. 通过 callback 返回应加载的 file:// URL
     *
     * 异常或网络失败时：不阻塞，直接 fallback 到 android_asset。
     */
    public void checkAndUpdate(final UpdateCallback callback) {
        new Thread(() -> {
            try {
                SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                String localVersion = prefs.getString(KEY_VERSION, "");

                Log.i(TAG, "Checking update — local version: '" + localVersion + "'");

                JSONObject versionInfo = fetchVersionInfo();
                String serverVersion = versionInfo.getString("version");
                JSONArray files = versionInfo.getJSONArray("files");

                Log.i(TAG, "Server version: " + serverVersion + ", files count: " + files.length());

                // 首次安装（无版本号）或本地版本低于服务端 → 触发下载
                if (localVersion.isEmpty() || compareVersions(localVersion, serverVersion) < 0) {
                    Log.i(TAG, "Update triggered: " + localVersion + " → " + serverVersion);

                    int updatedCount = 0;
                    for (int i = 0; i < files.length(); i++) {
                        JSONObject file = files.getJSONObject(i);
                        String path = file.getString("path");
                        try {
                            String localMd5 = getLocalFileMd5(path);
                            String serverMd5 = file.getString("md5");
                            if (localMd5 != null && localMd5.equals(serverMd5)) {
                                continue; // 文件未变，跳过
                            }
                        } catch (Exception ignored) {
                            // MD5 比较失败（如文件不存在），继续下载
                        }
                        downloadFile(path);
                        updatedCount++;
                    }

                    prefs.edit().putString(KEY_VERSION, serverVersion).apply();
                    Log.i(TAG, "Update complete — " + updatedCount + " files downloaded");
                } else {
                    Log.i(TAG, "Already up to date");
                }

                String loadUrl = getLoadUrl();
                // 带上版本号参数，前端可据此显示更新提示
                if (loadUrl.contains("?")) {
                    loadUrl += "&huver=" + serverVersion;
                } else {
                    loadUrl += "?huver=" + serverVersion;
                }
                final String finalUrl = loadUrl;
                mainHandler.post(() -> callback.onReady(finalUrl));

            } catch (Exception e) {
                Log.e(TAG, "Update check failed, falling back to asset", e);
                mainHandler.post(() -> callback.onReady("file:///android_asset/pixel_calendar_new.html"));
            }
        }).start();
    }

    /**
     * 计算本地文件的 MD5 哈希，用于增量更新判断。
     */
    private String getLocalFileMd5(String relativePath) {
        File f = new File(context.getFilesDir(), relativePath);
        if (!f.isFile()) return null;
        try (InputStream in = new FileInputStream(f)) {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
            byte[] buf = new byte[8192];
            int len;
            while ((len = in.read(buf)) != -1) {
                md.update(buf, 0, len);
            }
            byte[] digest = md.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 请求 /api/version 获取版本信息。
     */
    private JSONObject fetchVersionInfo() throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(SERVER_URL + "/api/version").openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(10000);
        return readJsonResponse(conn);
    }

    /**
     * 下载单个文件到内部存储，保持相对路径结构。
     */
    private void downloadFile(String filePath) throws Exception {
        URL url = new URL(SERVER_URL + "/api/update/" + filePath);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(30000);

        File outFile = new File(context.getFilesDir(), filePath);
        File parent = outFile.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }

        try (InputStream in = conn.getInputStream();
             FileOutputStream out = new FileOutputStream(outFile)) {
            byte[] buffer = new byte[8192];
            int len;
            while ((len = in.read(buffer)) != -1) {
                out.write(buffer, 0, len);
            }
        } finally {
            conn.disconnect();
        }

        Log.d(TAG, "Downloaded: " + filePath + " → " + outFile.getAbsolutePath());
    }

    /**
     * 读取 JSON 响应。
     */
    private JSONObject readJsonResponse(HttpURLConnection conn) throws Exception {
        int code = conn.getResponseCode();
        InputStream stream = (code >= 200 && code < 300) ? conn.getInputStream() : conn.getErrorStream();
        BufferedReader reader = new BufferedReader(new InputStreamReader(stream, "UTF-8"));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            sb.append(line);
        }
        reader.close();
        conn.disconnect();

        if (code >= 400) {
            throw new IOException("HTTP " + code + ": " + sb.toString());
        }
        return new JSONObject(sb.toString());
    }

    /**
     * 确定 WebView 应加载的 URL：内部存储优先，回退到 android_asset。
     */
    private String getLoadUrl() {
        File mainHtml = new File(context.getFilesDir(), "pixel_calendar_new.html");
        if (mainHtml.exists()) {
            return "file://" + mainHtml.getAbsolutePath();
        }
        return "file:///android_asset/pixel_calendar_new.html";
    }

    /**
     * 比较语义化版本号 (semver-like)，如 "3.3" vs "3.2.1"。
     *
     * @return 负数表示 v1 < v2，0 相等，正数表示 v1 > v2
     */
    static int compareVersions(String v1, String v2) {
        String[] parts1 = v1.split("\\.");
        String[] parts2 = v2.split("\\.");
        int len = Math.max(parts1.length, parts2.length);
        for (int i = 0; i < len; i++) {
            int p1 = i < parts1.length ? Integer.parseInt(parts1[i]) : 0;
            int p2 = i < parts2.length ? Integer.parseInt(parts2[i]) : 0;
            if (p1 != p2) return p1 - p2;
        }
        return 0;
    }
}
