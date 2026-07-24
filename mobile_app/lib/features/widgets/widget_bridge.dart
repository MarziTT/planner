import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Structured data model for the PixelPlanner home screen widget.
class WidgetData {
  final String date;
  final String weekday;
  final String greeting;

  // Meals
  final String mealsSummary;
  final int mealsTotalCalories;
  final int mealsCount;
  final String? mealsNext;
  final String? mealsLast;

  // Exercise
  final String exerciseSummary;
  final int exerciseMinutes;
  final int exerciseCalories;
  final int exerciseSteps;
  final String exerciseStatus;
  final String exerciseStatusEmoji;

  // Schedule
  final String? scheduleNext;
  final int scheduleCount;
  final String scheduleSummary;

  // Health
  final int standTotal;
  final int standCompleted;
  final int standSkipped;
  final String standLabel;
  final String? sleep;

  const WidgetData({
    required this.date,
    required this.weekday,
    required this.greeting,
    required this.mealsSummary,
    this.mealsTotalCalories = 0,
    this.mealsCount = 0,
    this.mealsNext,
    this.mealsLast,
    required this.exerciseSummary,
    this.exerciseMinutes = 0,
    this.exerciseCalories = 0,
    this.exerciseSteps = 0,
    this.exerciseStatus = '',
    this.exerciseStatusEmoji = '',
    this.scheduleNext,
    this.scheduleCount = 0,
    this.scheduleSummary = '今日无日程',
    this.standTotal = 0,
    this.standCompleted = 0,
    this.standSkipped = 0,
    this.standLabel = '',
    this.sleep,
  });

  Map<String, dynamic> toJson() => {
        'header': {
          'date': date,
          'weekday': weekday,
          'greeting': greeting,
        },
        'meals': {
          'summary': mealsSummary,
          'total_calories': mealsTotalCalories,
          'count': mealsCount,
          if (mealsNext != null && mealsNext!.isNotEmpty) 'next': mealsNext,
          if (mealsLast != null && mealsLast!.isNotEmpty) 'last': mealsLast,
        },
        'exercise': {
          'summary': exerciseSummary,
          'minutes': exerciseMinutes,
          'calories': exerciseCalories,
          'steps': exerciseSteps,
          'status': exerciseStatus,
          'status_emoji': exerciseStatusEmoji,
        },
        'schedule': {
          if (scheduleNext != null && scheduleNext!.isNotEmpty) 'next': scheduleNext,
          'count': scheduleCount,
          'summary': scheduleSummary,
        },
        'health': {
          'stand_total': standTotal,
          'stand_completed': standCompleted,
          'stand_skipped': standSkipped,
          'stand_label': standLabel,
          if (sleep != null && sleep!.isNotEmpty) 'sleep': sleep,
        },
      };

  /// Build a minimal placeholder for when no data is available.
  factory WidgetData.placeholder() {
    final now = DateTime.now();
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final hour = now.hour;
    final greeting = hour < 8
        ? '早上好'
        : hour < 12
            ? '上午好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';

    return WidgetData(
      date: '${now.month}月${now.day}日',
      weekday: weekdayNames[now.weekday - 1],
      greeting: greeting,
      mealsSummary: '今日未记录餐食',
      exerciseSummary: '今日未运动',
      scheduleSummary: '今日无日程',
    );
  }
}

/// Bridge between Flutter and native Android widget via MethodChannel.
class WidgetBridge {
  static const _channel = MethodChannel('com.pixelplanner.widget');

  static final WidgetBridge instance = WidgetBridge._();

  WidgetBridge._();

  /// Push structured widget data to the native layer.
  Future<bool> setWidgetData(Map<String, dynamic> data) async {
    try {
      final result = await _channel.invokeMethod(
        'setWidgetData',
        {'data': jsonEncode(data)},
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Cache widget data without immediately updating the UI.
  Future<bool> updateWidgetCache(Map<String, dynamic> data) async {
    try {
      final result = await _channel.invokeMethod(
        'updateWidgetCache',
        {'data': jsonEncode(data)},
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Set the backend base URL for WorkManager background refresh.
  Future<bool> setBaseUrl(String url) async {
    try {
      final result = await _channel.invokeMethod('setBaseUrl', {'url': url});
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Start the periodic WorkManager widget refresh.
  Future<bool> startWidgetRefresh() async {
    try {
      final result = await _channel.invokeMethod('startWidgetRefresh');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Push a complete WidgetData to the native widget.
  Future<void> pushWidgetData(WidgetData data) async {
    await setWidgetData(data.toJson());
  }

  /// Push a minimal placeholder (e.g. on logout or no data).
  Future<void> pushPlaceholder() async {
    await setWidgetData(WidgetData.placeholder().toJson());
  }
}

/// Riverpod provider for WidgetBridge singleton.
final widgetBridgeProvider = Provider<WidgetBridge>((ref) {
  return WidgetBridge.instance;
});
