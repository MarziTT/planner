import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'widget_bridge.dart';

/// Service that fetches widget data from the backend and pushes it to
/// the native Android widget via [WidgetBridge].
class WidgetService {
  final Dio _dio;
  final WidgetBridge _bridge;

  WidgetService({required Dio dio, required WidgetBridge bridge})
      : _dio = dio,
        _bridge = bridge;

  /// Fetch today's widget summary from the API and push to the widget.
  Future<void> refreshWidget() async {
    try {
      final response = await _dio.get('/widget/summary');
      final data = response.data;
      if (data == null || data['ok'] != true) return;

      final json = data['data'] as Map<String, dynamic>;
      final widgetData = _parseWidgetData(json);
      await _bridge.pushWidgetData(widgetData);
    } catch (_) {
      // Silently fail — widget refresh is best-effort
    }
  }

  WidgetData _parseWidgetData(Map<String, dynamic> json) {
    final header = json['header'] as Map<String, dynamic>? ?? {};
    final meals = json['meals'] as Map<String, dynamic>? ?? {};
    final exercise = json['exercise'] as Map<String, dynamic>? ?? {};
    final schedule = json['schedule'] as Map<String, dynamic>? ?? {};
    final health = json['health'] as Map<String, dynamic>? ?? {};

    return WidgetData(
      date: header['date'] as String? ?? '',
      weekday: header['weekday'] as String? ?? '',
      greeting: header['greeting'] as String? ?? '',
      mealsSummary: meals['summary'] as String? ?? '',
      mealsTotalCalories: meals['total_calories'] as int? ?? 0,
      mealsCount: meals['count'] as int? ?? 0,
      mealsNext: meals['next'] as String?,
      mealsLast: meals['last'] as String?,
      exerciseSummary: exercise['summary'] as String? ?? '',
      exerciseMinutes: exercise['minutes'] as int? ?? 0,
      exerciseCalories: exercise['calories'] as int? ?? 0,
      exerciseSteps: exercise['steps'] as int? ?? 0,
      exerciseStatus: exercise['status'] as String? ?? '',
      exerciseStatusEmoji: exercise['status_emoji'] as String? ?? '',
      scheduleNext: schedule['next'] as String?,
      scheduleCount: schedule['count'] as int? ?? 0,
      scheduleSummary: schedule['summary'] as String? ?? '今日无日程',
      standTotal: health['stand_total'] as int? ?? 0,
      standCompleted: health['stand_completed'] as int? ?? 0,
      standSkipped: health['stand_skipped'] as int? ?? 0,
      standLabel: health['stand_label'] as String? ?? '',
      sleep: health['sleep'] as String?,
    );
  }

  /// Push a placeholder to the widget (e.g. after logout).
  Future<void> clearWidget() async {
    await _bridge.pushPlaceholder();
  }
}

/// Riverpod provider.
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService(
    dio: ref.watch(apiClientProvider),
    bridge: ref.watch(widgetBridgeProvider),
  );
});
