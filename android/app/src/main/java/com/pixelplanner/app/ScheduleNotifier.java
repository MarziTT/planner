package com.pixelplanner.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import androidx.core.app.NotificationCompat;

public class ScheduleNotifier {
    private static final String CHANNEL_ID = "schedule_channel";
    private static final String CHANNEL_NAME = "行程通知";
    private static final int NOTIFICATION_ID = 1001;
    private static final String PREFS_NAME = "schedule_prefs";
    private static final String KEY_EVENTS_JSON = "today_events_json";

    private Context context;
    private NotificationManager nm;

    public ScheduleNotifier(Context context) {
        this.context = context;
        this.nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        createChannel();
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT
            );
            channel.setDescription("今日行程与日程提醒");
            channel.setShowBadge(true);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            nm.createNotificationChannel(channel);
        }
    }

    public void persistEvents(String eventsJson) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(KEY_EVENTS_JSON, eventsJson).apply();
    }

    public String loadPersistedEvents() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_EVENTS_JSON, "[]");
    }

    public void refresh(String eventsJson) {
        persistEvents(eventsJson);

        // Parse events
        String title = "今日行程";
        String content = buildContent(eventsJson);
        int count = countEvents(eventsJson);

        Intent intent = new Intent(context, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pi = PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.InboxStyle style = new NotificationCompat.InboxStyle();
        style.setBigContentTitle("今日行程 · " + count + "项");
        String[] lines = content.split("\n");
        for (String line : lines) {
            if (line.trim().length() > 0) style.addLine(line.trim());
        }

        Notification notification = new NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(count > 0 ? count + "项行程" : "今天暂无行程")
            .setStyle(style)
            .setContentIntent(pi)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build();

        nm.notify(NOTIFICATION_ID, notification);
    }

    public void showFromCache() {
        String cached = loadPersistedEvents();
        refresh(cached);
    }

    public void clear() {
        nm.cancel(NOTIFICATION_ID);
    }

    private String buildContent(String eventsJson) {
        try {
            org.json.JSONArray arr = new org.json.JSONArray(eventsJson);
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < arr.length(); i++) {
                org.json.JSONObject ev = arr.getJSONObject(i);
                String time = ev.optString("time", "");
                String text = ev.optString("content", "");
                if (sb.length() > 0) sb.append("\n");
                sb.append(time.isEmpty() ? "全天" : time).append("  ").append(text);
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private int countEvents(String eventsJson) {
        try {
            return new org.json.JSONArray(eventsJson).length();
        } catch (Exception e) {
            return 0;
        }
    }
}
