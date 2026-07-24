import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../habits/notify_manager.dart';

/// 饮食到点弹窗提醒服务
///
/// 基于习惯引擎学习到的用餐时间，在 meal_time 时发送通知。
/// 快捷操作：[已吃] [推迟 30 分钟]
/// 1 小时宽容窗口：用户点"已吃"时，如果在 meal_time ± 1h 范围内，
/// 记录时间用实际点击时间，否则用 meal_time。
class MealReminderService {
  final NotifyManager Function() _notifyManager;

  MealReminderService({required NotifyManager Function() notifyManager})
      : _notifyManager = notifyManager;

  /// 安排一餐的提醒通知
  ///
  /// [mealType] 餐食类型（用于通知标题）
  /// [mealTime] 习惯引擎学习到的用餐时间
  /// [scheduleId] 日程 ID（对应 habits engine 中的 schedule）
  /// [mealTimeLabel] 用餐时间的中文标签（如 "早餐 08:00"）
  Future<void> scheduleMealReminder({
    required String mealType,
    required DateTime mealTime,
    int? scheduleId,
    String? mealTimeLabel,
  }) async {
    final now = DateTime.now();
    // 如果用餐时间已过，不安排提醒
    if (mealTime.isBefore(now)) return;

    final title = _mealTitle(mealType);
    final body = mealTimeLabel != null
        ? '该吃$mealType啦 · 习惯时间 $mealTimeLabel'
        : '该吃$mealType啦';

    await NotifyManager.show(
      channel: NotifyChannel.meal,
      title: title,
      body: body,
      payload: NotifyPayload(
        eventType: 'meal_reminder',
        scheduleId: scheduleId,
        channelId: NotifyChannel.meal.id,
      ),
      scheduledDate: mealTime,
    );
  }

  /// 取消某餐的提醒
  Future<void> cancelMealReminder(int notificationId) async {
    await NotifyManager.plugin.cancel(notificationId);
  }

  /// 计算 1 小时宽容窗口后的记录时间
  ///
  /// 规则（马斯克建议）：
  /// - 当前时间与 meal_time 差值 ≤ 60 分钟 → 返回当前时间
  /// - 差值 > 60 分钟 → 返回 meal_time（避免脏数据）
  static DateTime calculateRecordTime(DateTime mealTime) {
    final now = DateTime.now();
    final diff = now.difference(mealTime).abs();
    if (diff.inMinutes <= 60) {
      return now;
    }
    return mealTime;
  }

  /// 处理"已吃"快捷操作
  ///
  /// 返回应记录的用餐时间（经过宽容窗口计算）。
  static DateTime handleEatenAction(DateTime mealTime) {
    return calculateRecordTime(mealTime);
  }

  /// 处理"推迟 30 分钟"快捷操作
  ///
  /// 返回新的提醒时间。
  static DateTime handlePostponeAction() {
    return DateTime.now().add(const Duration(minutes: 30));
  }

  static String _mealTitle(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return '🍳 该吃早餐了';
      case 'lunch':
        return '🍱 该吃午餐了';
      case 'dinner':
        return '🍲 该吃晚餐了';
      case 'snack':
        return '🍎 该加餐了';
      default:
        return '🍽️ 用餐提醒';
    }
  }
}
