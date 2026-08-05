import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../habits/notify_manager.dart';
import '../models/smart_advisory.dart';
import '../models/timeline_item.dart';

// ============================================================
// WeatherNotificationService
// ============================================================

/// Smart weather notification service.
///
/// Three notification types:
/// 1. 7:00 AM daily summary
/// 2. 30 min before event — action advice
/// 3. Weather mutation detection — push on significant change
class WeatherNotificationService {
  static const _summaryNotificationId = 8802;
  static const _eventNotificationIdBase = 8900;
  static const _mutationNotificationId = 8803;

  static const _prefKeyLastAdvisory = 'weather:last_advisory_json';
  static const _prefKeyLat = 'weather_notify:last_lat';
  static const _prefKeyLon = 'weather_notify:last_lon';

  Timer? _summaryTimer;
  Timer? _eventCheckTimer;
  SharedPreferences? _prefs;

  WeatherNotificationService();

  /// Initialize with SharedPreferences for persisting state.
  void setPreferences(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// Schedule the 7:00 AM daily summary notification.
  void scheduleDailySummary() {
    _summaryTimer?.cancel();

    final now = DateTime.now();
    var next = tz.TZDateTime.local(now.year, now.month, now.day, 7, 0, 0);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    final duration = next.toUtc().difference(DateTime.now().toUtc());
    if (duration.isNegative) return;

    _summaryTimer = Timer(duration, () {
      _fireDailySummary();
      // Reschedule for tomorrow
      scheduleDailySummary();
    });

    debugPrint(
        '[WeatherNotify] Daily summary scheduled at ${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')} 07:00');
  }

  /// Schedule per-event notifications (30 min before each timeline item).
  void scheduleEventNotifications(SmartAdvisory advisory) {
    _eventCheckTimer?.cancel();

    final now = DateTime.now();
    for (var i = 0; i < advisory.timeline.length; i++) {
      final item = advisory.timeline[i];
      final triggerTime = _parseTimeSlot(item.timeSlot);
      if (triggerTime == null) continue;

      final notifyAt = triggerTime.subtract(const Duration(minutes: 30));
      if (notifyAt.isBefore(now)) continue;

      final delay = notifyAt.difference(now);
      Timer(delay, () {
        _fireEventNotification(item, i);
      });
    }
  }

  /// Detect weather mutations by comparing with last cached advisory.
  ///
  /// Triggers notification when:
  /// - Temperature change >= 8°C
  /// - Precipitation probability jumps from 0 to > 50%
  void detectWeatherMutation(SmartAdvisory advisory) {
    final prefs = _prefs;
    if (prefs == null) return;

    final lastJson = prefs.getString(_prefKeyLastAdvisory);
    if (lastJson == null) {
      // First run — persist baseline
      prefs.setString(_prefKeyLastAdvisory, jsonEncode(advisory.toJson()));
      return;
    }

    try {
      final lastAdvisory =
          SmartAdvisory.fromJson(jsonDecode(lastJson) as Map<String, dynamic>);
      final lastTimeline = lastAdvisory.timeline;
      final currentTimeline = advisory.timeline;

      bool tempSpike = false;
      bool rainAppeared = false;

      for (int i = 0;
          i < currentTimeline.length && i < lastTimeline.length;
          i++) {
        final curr = currentTimeline[i];
        final prev = lastTimeline[i];

        final tempDiff = (curr.weather.temp - prev.weather.temp).abs();
        if (tempDiff >= 8.0) {
          tempSpike = true;
        }

        if (prev.weather.precipitation == 0 &&
            curr.weather.precipitation > 50.0) {
          rainAppeared = true;
        }
      }

      if (tempSpike || rainAppeared) {
        final body = _buildMutationBody(
          tempSpike: tempSpike,
          rainAppeared: rainAppeared,
          advisory: advisory,
        );

        NotifyManager.show(
          channel: NotifyChannel.weather,
          title: '天气变化提醒',
          body: body,
          priority: NotifyPriority.important,
          payload: const NotifyPayload(eventType: 'weather_mutation'),
          notificationId: _mutationNotificationId,
        );
      }

      // Update baseline
      prefs.setString(_prefKeyLastAdvisory, jsonEncode(advisory.toJson()));
    } catch (e) {
      debugPrint('[WeatherNotify] Mutation detection failed: $e');
    }
  }

  /// Persist last used coordinates.
  void saveCoordinates(double lat, double lon) {
    _prefs?.setDouble(_prefKeyLat, lat);
    _prefs?.setDouble(_prefKeyLon, lon);
  }

  /// Get last saved coordinates.
  ({double lat, double lon})? getLastCoordinates() {
    final prefs = _prefs;
    if (prefs == null) return null;
    final lat = prefs.getDouble(_prefKeyLat);
    final lon = prefs.getDouble(_prefKeyLon);
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  /// Cancel all scheduled timers.
  void dispose() {
    _summaryTimer?.cancel();
    _eventCheckTimer?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _fireDailySummary() {
    // Trigger via NotifyManager.show — the actual data is fetched
    // by the weather provider; here we push a light summary notification
    // that launches the app to view full advisory.
    NotifyManager.show(
      channel: NotifyChannel.weather,
      title: '今日天气',
      body: '早上好！我已为你准备好今天的全天规划建议，点击查看。',
      priority: NotifyPriority.daily,
      payload: const NotifyPayload(eventType: 'weather_daily_summary'),
      notificationId: _summaryNotificationId,
    );
  }

  void _fireEventNotification(TimelineItem item, int index) {
    final eventName = item.event ?? '日程';
    final advice = item.advisory ?? '请查看天气了解详情';
    final temp = item.weather.temp.round();
    final condition = item.weather.condition;

    NotifyManager.show(
      channel: NotifyChannel.weather,
      title: '「$eventName」即将开始',
      body: '$advice（当前$temp°C，$condition）',
      priority:
          item.isHighPriority ? NotifyPriority.important : NotifyPriority.daily,
      payload: NotifyPayload(
        eventType: 'weather_event_reminder',
        eventId: _eventNotificationIdBase + index,
      ),
      notificationId: _eventNotificationIdBase + index,
    );
  }

  String _buildMutationBody({
    required bool tempSpike,
    required bool rainAppeared,
    required SmartAdvisory advisory,
  }) {
    final buf = StringBuffer();
    if (tempSpike) {
      buf.write('气温发生显著变化');
    }
    if (rainAppeared) {
      if (buf.isNotEmpty) buf.write('，');
      buf.write('预计将有降雨');
    }
    buf.write('。');
    if (advisory.summary.isNotEmpty) {
      buf.write(' ${advisory.summary}');
    }
    return buf.toString();
  }

  /// Parse time slot string like "08:00-12:00" → the start DateTime today.
  DateTime? _parseTimeSlot(String timeSlot) {
    final parts = timeSlot.split('-');
    if (parts.isEmpty) return null;
    final timePart = parts[0].trim();
    final timeParts = timePart.split(':');
    if (timeParts.length < 2) return null;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

// ============================================================
// Provider
// ============================================================

final weatherNotificationServiceProvider =
    Provider<WeatherNotificationService>((ref) {
  return WeatherNotificationService();
});
