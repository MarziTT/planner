import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notify_manager.dart';

/// Weather notification service.
///
/// - Schedules a daily 7:00 AM weather summary push via ``zonedSchedule``.
/// - Uses the ``jarvis_weather`` channel (daily priority).
/// - Extreme weather (typhoon / heavy rain / heatwave / coldwave) auto-upgrades
///   to urgent.
/// - Notification format: "深圳 · 多云转小雨 · 12~18°C · 记得带伞"
class WeatherNotifier {
  WeatherNotifier._();

  static const int _notificationId = 8801;
  static const String _prefKeyLastLat = 'weather_last_lat';
  static const String _prefKeyLastLon = 'weather_last_lon';

  /// API base URL (matches backend registration prefix).
  static String _baseUrl = '';

  /// Set the backend base URL (e.g. 'https://api.example.com').
  /// Must be called before [schedule] or [sendNow].
  static void setBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  /// Schedule the daily 7:00 AM weather notification.
  ///
  /// [lat] / [lon] — current location coordinates.
  /// [token] — auth token for the backend.
  /// [prefs] — SharedPreferences for persisting last-used coordinates.
  static Future<void> schedule({
    required double lat,
    required double lon,
    required String token,
    required SharedPreferences prefs,
  }) async {
    // Persist coordinates for tomorrow's schedule
    await prefs.setDouble(_prefKeyLastLat, lat);
    await prefs.setDouble(_prefKeyLastLon, lon);

    // Compute next 7:00 AM in local timezone
    final now = DateTime.now();
    var scheduled = tz.TZDateTime.local(now.year, now.month, now.day, 7, 0, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final plugin = NotifyManager.plugin;
    await plugin.zonedSchedule(
      _notificationId,
      '今日天气',
      '正在获取天气...',
      scheduled,
      _buildPlaceholderDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Fetch weather and push an immediate notification. Called from the
  /// zonedSchedule callback handler or on-demand.
  ///
  /// Returns the notification body string for debugging.
  static Future<String?> sendNow({
    required double lat,
    required double lon,
    required String token,
  }) async {
    if (_baseUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/v1/weather/?lat=$lat&lon=$lon',
      );
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final weatherData = data['data'] as Map<String, dynamic>?;
      if (weatherData == null) return null;

      final city = (weatherData['city'] as String?) ?? '';
      final current = weatherData['current'] as Map<String, dynamic>? ?? {};
      final daily = (weatherData['daily'] as List?) ?? [];

      final temp = _safeDouble(current['temp']);
      final condition = (current['condition'] as Map<String, dynamic>?) ?? {};
      final conditionText = (condition['text'] as String?) ?? '';

      // Build temperature range from daily[0]
      int? tempMax, tempMin;
      if (daily.isNotEmpty) {
        final today = daily[0] as Map<String, dynamic>;
        tempMax = _safeInt(today['temp_max']);
        tempMin = _safeInt(today['temp_min']);
      }

      // Determine if extreme weather
      final isExtreme = _isExtremeWeather(conditionText, daily);

      // Build notification body
      final body = _buildBody(
        city: city,
        conditionText: conditionText,
        tempMax: tempMax,
        tempMin: tempMin,
        temp: temp,
        daily: daily,
      );

      final extras = _buildExtras(conditionText);

      await NotifyManager.show(
        channel: NotifyChannel.weather,
        title: extras.isEmpty ? '今日天气' : '${extras.join(' · ')}',
        body: body,
        priority: isExtreme ? NotifyPriority.urgent : NotifyPriority.daily,
        payload: const NotifyPayload(eventType: 'weather'),
        notificationId: _notificationId,
      );

      return body;
    } catch (_) {
      return null;
    }
  }

  /// Called from notification tap handler to re-schedule for the next day.
  static Future<void> rescheduleNext({
    required String token,
    required SharedPreferences prefs,
  }) async {
    final lat = prefs.getDouble(_prefKeyLastLat);
    final lon = prefs.getDouble(_prefKeyLastLon);
    if (lat == null || lon == null) return;

    await schedule(lat: lat, lon: lon, token: token, prefs: prefs);
  }

  // -----------------------------------------------------------------------
  //  Internal
  // -----------------------------------------------------------------------

  static NotificationDetails _buildPlaceholderDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        NotifyChannel.weather.id,
        NotifyChannel.weather.label,
        channelDescription: '${NotifyChannel.weather.label}天气摘要',
        importance: Importance.defaultImportance,
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true),
    );
  }

  static String _buildBody({
    required String city,
    required String conditionText,
    int? tempMax,
    int? tempMin,
    required double temp,
    required List daily,
  }) {
    final buf = StringBuffer();
    if (city.isNotEmpty) {
      buf.write('$city · ');
    }

    // Try to describe day→night transition from daily
    String? dayText, nightText;
    if (daily.length >= 1) {
      final today = daily[0] as Map<String, dynamic>;
      final cDay = today['condition'] as Map<String, dynamic>?;
      dayText = cDay?['text'] as String?;
      final cNight = _safeConditionText(daily, 0, isNight: true);
      nightText = cNight;
    }

    if (dayText != null && nightText != null && dayText != nightText) {
      buf.write('$dayText转$nightText · ');
    } else {
      buf.write('${dayText ?? conditionText} · ');
    }

    if (tempMax != null && tempMin != null) {
      buf.write('${tempMin}~${tempMax}°C');
    } else {
      buf.write('${temp.round()}°C');
    }

    // Smart advice
    final advice = _getAdvice(conditionText, dayText, nightText);
    if (advice.isNotEmpty) {
      buf.write(' · $advice');
    }

    return buf.toString();
  }

  static List<String> _buildExtras(String conditionText) {
    // Not used as extras for now; the body is self-contained.
    return [];
  }

  static String _getAdvice(String? currentText, String? dayText, String? nightText) {
    final combined = '${currentText ?? ''} ${dayText ?? ''} ${nightText ?? ''}';

    if (_containsAny(combined, ['雨', 'rain', '暴雨', '雷', '阵雨', '细雨', '毛毛'])) {
      return '记得带伞';
    }
    if (_containsAny(combined, ['雪', 'snow'])) {
      return '注意保暖';
    }
    if (_containsAny(combined, ['高温', '炎热', 'heatwave'])) {
      return '注意防暑';
    }
    if (_containsAny(combined, ['台风', 'typhoon', '飓风'])) {
      return '注意安全，减少外出';
    }
    if (_containsAny(combined, ['霾', '沙尘', '雾', 'haze', 'fog'])) {
      return '佩戴口罩';
    }
    if (_containsAny(combined, ['风', 'wind', '大风'])) {
      return '注意防风';
    }

    return '';
  }

  static bool _isExtremeWeather(String currentText, List daily) {
    final todayText = (daily.isNotEmpty)
        ? _safeConditionText(daily, 0)
        : '';
    final combined = '$currentText $todayText';

    const extremeKw = [
      '台风', 'typhoon', '飓风', 'hurricane',
      '暴雨', 'rainstorm', '特大暴雨',
      '高温', 'heatwave', '极端高温',
      '寒潮', 'coldwave', '暴雪', 'blizzard',
      '冰雹', 'hail',
    ];

    for (final kw in extremeKw) {
      if (combined.contains(kw)) return true;
    }
    return false;
  }

  static String? _safeConditionText(List daily, int index, {bool isNight = false}) {
    if (index >= daily.length) return null;
    final day = daily[index] as Map<String, dynamic>;
    final c = day['condition'] as Map<String, dynamic>?;
    if (isNight) {
      // daily condition text is day-time only in our backend;
      // we don't have night text, so return null for night.
      return null;
    }
    return c?['text'] as String?;
  }

  static bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final kw in keywords) {
      if (lower.contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  static double _safeDouble(dynamic v) {
    if (v == null) return -999;
    return (v is num) ? v.toDouble() : -999;
  }

  static int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.round();
    return null;
  }
}
