import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../notifications/data/harmony_notification_service.dart';

bool get isOhos => Platform.operatingSystem == 'ohos';

/// 通知三级优先级
enum NotifyPriority {
  /// 紧急：出行提醒、会议即将开始（10-30 分钟前）
  urgent,

  /// 重要：饮食、运动提醒
  important,

  /// 日常：站立提醒、习惯提醒
  daily,
}

/// 预定义的通知 Channel 类型
enum NotifyChannel {
  transit('jarvis_transit', '出行', NotifyPriority.urgent),
  meal('jarvis_meal', '饮食', NotifyPriority.important),
  exercise('jarvis_exercise', '运动', NotifyPriority.important),
  standing('jarvis_standing', '站立', NotifyPriority.daily),
  weather('jarvis_weather', '天气', NotifyPriority.daily),
  schedule('jarvis_schedule', '日程', NotifyPriority.important);

  const NotifyChannel(this.id, this.label, this.defaultPriority);

  final String id;
  final String label;
  final NotifyPriority defaultPriority;
}

/// 通知快捷操作 ID 常量
class NotifyActionId {
  NotifyActionId._();

  static const String complete = 'action_complete';
  static const String postpone = 'action_postpone';
  static const String skip = 'action_skip';
}

/// 通知 payload 数据结构
class NotifyPayload {
  const NotifyPayload({
    required this.eventType,
    this.eventId,
    this.scheduleId,
    this.channelId,
  });

  final String eventType;
  final int? eventId;
  final int? scheduleId;
  final String? channelId;

  static NotifyPayload? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotifyPayload(
        eventType: map['event_type'] as String? ?? '',
        eventId: map['event_id'] as int?,
        scheduleId: map['schedule_id'] as int?,
        channelId: map['channel_id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode({
        'event_type': eventType,
        'event_id': eventId,
        'schedule_id': scheduleId,
        'channel_id': channelId,
      });
}

/// 快捷操作回调签名
///
/// 当用户点击通知上的快捷操作按钮时触发。
/// [actionId] 为 [NotifyActionId] 中定义的动作常量。
/// [payload] 为通知 payload 的解析结果。
typedef NotifyActionCallback = void Function(
  String actionId,
  NotifyPayload? payload,
);

/// 锁屏通知管理器
///
/// 负责通知 Channel 注册、三级优先级通知发送、快捷操作按钮、
/// 以及乔布斯规则（每日 important+ 通知上限）。
class NotifyManager {
  NotifyManager._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static SharedPreferences? _prefs;

  /// 快捷操作回调（由外部 habits_engine 等模块注入）
  static NotifyActionCallback? onAction;

  /// 乔布斯规则：每日 important 及以上通知上限
  static const int _maxImportantPerDay = 3;

  /// 初始化 SharedPreferences 引用（由 main 中注入）
  static void setSharedPreferences(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// 获取底层 plugin 实例（供外部 zonedSchedule 等高级用法）
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// 处理快捷操作回调的统一入口。
  ///
  /// 由通知初始化代码中的 onDidReceiveNotificationResponse 调用。
  static void handleAction(String? actionId, String? payload) {
    final cb = onAction;
    if (cb == null || actionId == null) return;
    cb(actionId, NotifyPayload.fromString(payload));
  }

  // ---------------------------------------------------------------------------
  // Channel 注册
  // ---------------------------------------------------------------------------

  /// 为所有通知类型注册独立的 Android notification channel。
  ///
  /// 应在 App 启动时调用一次。
  static Future<void> ensureChannels() async {
    // ── HarmonyOS 路径 ──
    if (isOhos) {
      for (final ch in NotifyChannel.values) {
        await HarmonyNotificationService.instance.ensureChannel(
          id: ch.id,
          name: ch.label,
          description: '${ch.label}提醒通知',
          priority: _priorityName(ch.defaultPriority),
          category: _ohosCategory(ch),
        );
      }
      return;
    }

    // ── Android 路径 ──
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    for (final ch in NotifyChannel.values) {
      await androidPlugin.createNotificationChannel(
        _buildChannel(ch),
      );
    }
  }

  static AndroidNotificationChannel _buildChannel(NotifyChannel ch) {
    switch (ch.defaultPriority) {
      case NotifyPriority.urgent:
        return AndroidNotificationChannel(
          ch.id,
          ch.label,
          description: '${ch.label}紧急提醒',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
      case NotifyPriority.important:
        return AndroidNotificationChannel(
          ch.id,
          ch.label,
          description: '${ch.label}重要提醒',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
      case NotifyPriority.daily:
        return AndroidNotificationChannel(
          ch.id,
          ch.label,
          description: '${ch.label}日常提醒',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // 通知发送统一入口
  // ---------------------------------------------------------------------------

  /// 发送一条通知。
  ///
  /// [channel] 通知类别，决定 channel ID 和默认优先级。
  /// [title] 通知标题。
  /// [body] 通知正文。
  /// [priority] 可覆盖 channel 默认优先级。
  /// [payload] 点击和快捷操作的数据载体。
  /// [scheduledDate] 非 null 时作为定时通知发送。
  /// [notificationId] 通知 ID（默认取 payload.eventId 或 hashCode）。
  /// [styleInformation] / [subText] / [when] / [extraActions]
  /// 供日程等富样式通知复用（可选）。
  ///
  /// 乔布斯规则（每日 important+ 上限 3 条）仅对即时通知生效：
  /// 定时通知在触发时刻无法执行 Dart 逻辑，因此在调度时不计数、不拦截。
  static Future<void> show({
    required NotifyChannel channel,
    required String title,
    required String body,
    NotifyPriority? priority,
    NotifyPayload? payload,
    DateTime? scheduledDate,
    int? notificationId,
    StyleInformation? styleInformation,
    String? subText,
    DateTime? when,
    List<AndroidNotificationAction>? extraActions,
  }) async {
    final effectivePriority = priority ?? channel.defaultPriority;
    final isScheduled = scheduledDate != null;
    final id = notificationId ??
        payload?.eventId ??
        (title + body).hashCode.abs();
    final payloadStr = payload?.toJsonString();

    // ---- HarmonyOS 路径 ----
    if (isOhos) {
      await HarmonyNotificationService.instance.show(
        id: id,
        title: title,
        body: body,
        channelId: channel.id,
        priority: _priorityName(effectivePriority),
        payload: payloadStr,
        scheduledDate: scheduledDate,
        category: _ohosCategory(channel),
      );
      return;
    }

    // ---- 乔布斯规则：每日上限（仅即时通知） ----
    if (!isScheduled && effectivePriority != NotifyPriority.urgent) {
      final quotaOk = await _checkDailyQuota();
      if (!quotaOk) {
        // 超出上限：静默降级，不发系统通知（仅更新小组件缓存由调用方处理）
        return;
      }
    }

    final actions = [
      ..._buildActions(channel, effectivePriority),
      ...?extraActions,
    ];

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.label,
      channelDescription: '${channel.label}提醒通知',
      importance: _toAndroidImportance(effectivePriority),
      priority: _toAndroidPriority(effectivePriority),
      category: _toAndroidCategory(channel),
      enableVibration: effectivePriority != NotifyPriority.daily,
      playSound: effectivePriority != NotifyPriority.daily,
      actions: actions,
      visibility: effectivePriority == NotifyPriority.daily
          ? NotificationVisibility.private
          : NotificationVisibility.public,
      color: _channelColor(channel),
      styleInformation: styleInformation,
      subText: subText,
      showWhen: when != null,
      when: when?.millisecondsSinceEpoch,
      ticker: title,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: effectivePriority == NotifyPriority.urgent,
        presentSound: effectivePriority != NotifyPriority.daily,
      ),
    );

    if (isScheduled) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate.toUtc(), tz.UTC),
        details,
        payload: payloadStr,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } else {
      await _plugin.show(id, title, body, details, payload: payloadStr);

      // 增加计数（urgent 也计入，便于监控，但 urgent 不受上限拦截）
      if (effectivePriority != NotifyPriority.daily) {
        await _incrementDailyCount();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 快捷操作按钮
  // ---------------------------------------------------------------------------

  /// 为不同 channel 构建快捷操作按钮列表
  static List<AndroidNotificationAction> _buildActions(
    NotifyChannel channel,
    NotifyPriority priority,
  ) {
    switch (channel) {
      case NotifyChannel.transit:
        return const [
          AndroidNotificationAction(
            NotifyActionId.complete,
            '完成',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotifyActionId.postpone,
            '推迟 5 分钟',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];

      case NotifyChannel.meal:
        return const [
          AndroidNotificationAction(
            NotifyActionId.complete,
            '已吃',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotifyActionId.postpone,
            '推迟 30 分钟',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];

      case NotifyChannel.standing:
        return const [
          AndroidNotificationAction(
            NotifyActionId.complete,
            '已站',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotifyActionId.skip,
            '跳过',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];

      case NotifyChannel.exercise:
        return const [
          AndroidNotificationAction(
            NotifyActionId.complete,
            '已完成',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotifyActionId.postpone,
            '推迟 1 小时',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];

      case NotifyChannel.weather:
        return const [];

      case NotifyChannel.schedule:
        return const [
          AndroidNotificationAction(
            NotifyActionId.complete,
            '完成',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotifyActionId.postpone,
            '推迟 15 分钟',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // 乔布斯规则 — 每日通知上限
  // ---------------------------------------------------------------------------

  static String get _todayKey {
    final now = DateTime.now();
    return 'notify_count_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  static Future<bool> _checkDailyQuota() async {
    final prefs = _prefs;
    if (prefs == null) return true; // 无 prefs 时放行
    final count = prefs.getInt(_todayKey) ?? 0;
    return count < _maxImportantPerDay;
  }

  static Future<void> _incrementDailyCount() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final count = (prefs.getInt(_todayKey) ?? 0) + 1;
    await prefs.setInt(_todayKey, count);
  }

  /// 查询今日已发送的 important+ 通知数量（调试/监控用）
  static int getTodayCount() {
    return _prefs?.getInt(_todayKey) ?? 0;
  }

  /// 取消所有已调度的通知和已显示的通知。
  static Future<void> cancelAll() async {
    if (isOhos) {
      await HarmonyNotificationService.instance.cancelAll();
    }
    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // 辅助映射
  // ---------------------------------------------------------------------------

  static String _priorityName(NotifyPriority p) {
    switch (p) {
      case NotifyPriority.urgent:
        return 'urgent';
      case NotifyPriority.important:
        return 'important';
      case NotifyPriority.daily:
        return 'daily';
    }
  }

  static String _ohosCategory(NotifyChannel ch) {
    switch (ch) {
      case NotifyChannel.transit:
      case NotifyChannel.schedule:
        return 'alarm';
      case NotifyChannel.meal:
      case NotifyChannel.exercise:
      case NotifyChannel.standing:
        return 'reminder';
      case NotifyChannel.weather:
        return 'recommendation';
    }
  }

  static Importance _toAndroidImportance(NotifyPriority p) {
    switch (p) {
      case NotifyPriority.urgent:
        return Importance.max;
      case NotifyPriority.important:
        return Importance.high;
      case NotifyPriority.daily:
        return Importance.defaultImportance;
    }
  }

  static Priority _toAndroidPriority(NotifyPriority p) {
    switch (p) {
      case NotifyPriority.urgent:
        return Priority.max;
      case NotifyPriority.important:
        return Priority.high;
      case NotifyPriority.daily:
        return Priority.defaultPriority;
    }
  }

  static AndroidNotificationCategory _toAndroidCategory(NotifyChannel ch) {
    switch (ch) {
      case NotifyChannel.transit:
      case NotifyChannel.schedule:
        return AndroidNotificationCategory.alarm;
      case NotifyChannel.meal:
      case NotifyChannel.exercise:
      case NotifyChannel.standing:
        return AndroidNotificationCategory.reminder;
      case NotifyChannel.weather:
        return AndroidNotificationCategory.recommendation;
    }
  }

  static Color _channelColor(NotifyChannel ch) {
    switch (ch) {
      case NotifyChannel.transit:
        return const Color(0xFFE53935); // red
      case NotifyChannel.meal:
        return const Color(0xFFFF9800); // orange
      case NotifyChannel.exercise:
        return const Color(0xFF4CAF50); // green
      case NotifyChannel.standing:
        return const Color(0xFF2196F3); // blue
      case NotifyChannel.weather:
        return const Color(0xFF00BCD4); // cyan
      case NotifyChannel.schedule:
        return const Color(0xFF2F6BFF); // FlowDay brand blue
    }
  }
}
