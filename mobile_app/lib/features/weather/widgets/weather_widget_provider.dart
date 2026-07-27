import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_cache_service.dart';
import '../../../core/network/api_client.dart';
import '../../widgets/widget_bridge.dart';
import '../data/weather_repository.dart';
import '../models/smart_advisory.dart';
import '../models/timeline_item.dart';

/// Widget data provider for the weather smart-advisory.
///
/// Pushes weather timeline data to the native Android widget every 30 minutes.
/// Uses the existing [WidgetBridge] infrastructure to communicate with the
/// native layer via MethodChannel.
class WeatherWidgetProvider {
  final WeatherRepository _repository;
  final WidgetBridge _bridge;
  Timer? _refreshTimer;

  WeatherWidgetProvider({
    required WeatherRepository repository,
    required WidgetBridge bridge,
  })  : _repository = repository,
        _bridge = bridge;

  /// Start periodic background refresh (every 30 minutes).
  void startPeriodicRefresh({
    required double lat,
    required double lon,
  }) {
    _refreshTimer?.cancel();
    // Immediate first refresh
    _pushWidgetData(lat: lat, lon: lon);
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _pushWidgetData(lat: lat, lon: lon),
    );
  }

  /// Stop periodic refresh.
  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Push a placeholder to the widget (login / no data).
  void pushPlaceholder() {
    _bridge.pushPlaceholder();
  }

  Future<void> _pushWidgetData({
    required double lat,
    required double lon,
  }) async {
    try {
      final advisory = await _repository.fetchSmartAdvisory(
        lat: lat,
        lon: lon,
      );
      final items = advisory.previewItems;

      final header = _buildSummaryText(advisory.summary);
      final timeline = items.map(_itemToText).toList();

      final data = WidgetData(
        date: _formatDate(DateTime.now()),
        weekday: _weekdayName(DateTime.now().weekday),
        greeting: _greeting(),
        mealsSummary: header,
        mealsTotalCalories: 0,
        mealsCount: timeline.length,
        exerciseSummary: timeline.isNotEmpty ? timeline.first : '',
        exerciseMinutes: 0,
        exerciseCalories: 0,
        exerciseSteps: 0,
        exerciseStatus: 'weather',
        exerciseStatusEmoji: _weatherEmoji(items),
        scheduleSummary: timeline.join(' | '),
        scheduleCount: timeline.length,
        standTotal: 0,
        standCompleted: 0,
        standSkipped: 0,
        standLabel: '',
        sleep: null,
        // Use next slot if available
        scheduleNext: items.isNotEmpty ? '${items.first.timeSlot} ${items.first.event ?? ""}' : null,
      );

      // Push both widget data and weather-only cache
      await _bridge.updateWidgetCache(data.toJson());
      await _bridge.setWidgetData(data.toJson());
    } catch (_) {
      // Best-effort; silently fail
    }
  }

  String _buildSummaryText(String summary) {
    const maxLen = 60;
    if (summary.length <= maxLen) return summary;
    return '${summary.substring(0, maxLen)}…';
  }

  String _itemToText(TimelineItem item) {
    final buf = StringBuffer(item.timeSlot);
    if (item.event != null) {
      buf.write(' ${item.event}');
    }
    if (item.advisory != null) {
      buf.write(' ${item.advisory}');
    }
    return buf.toString();
  }

  String _weatherEmoji(List<TimelineItem> items) {
    if (items.isEmpty) return '☀️';
    final first = items.first;
    final cond = first.weather.condition;
    if (cond.contains('雨')) return '🌧️';
    if (cond.contains('雪')) return '❄️';
    if (cond.contains('云') || cond.contains('阴')) return '☁️';
    if (cond.contains('晴')) return '☀️';
    if (cond.contains('雾') || cond.contains('霾')) return '🌫️';
    return '🌤️';
  }

  String _weekdayName(int weekday) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday - 1];
  }

  String _formatDate(DateTime dt) =>
      '${dt.month}月${dt.day}日';

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 8) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}

// ============================================================
// Provider
// ============================================================

final weatherWidgetProvider = Provider<WeatherWidgetProvider>((ref) {
  final dio = ref.watch(apiClientProvider);
  final cache = ref.watch(localCacheProvider);
  final bridge = ref.watch(widgetBridgeProvider);
  final repository = WeatherRepository(dio, cache: cache);
  return WeatherWidgetProvider(repository: repository, bridge: bridge);
});
