import 'weather_data.dart';

/// A single time-slot item in the smart-advisory timeline.
class TimelineItem {
  final String timeSlot;
  final String? event;
  final DetailedWeatherData weather;
  final String? advisory;

  const TimelineItem({
    required this.timeSlot,
    this.event,
    required this.weather,
    this.advisory,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      timeSlot: json['time_slot'] as String? ?? '',
      event: json['event'] as String?,
      weather: DetailedWeatherData.fromJson(
          json['weather'] as Map<String, dynamic>),
      advisory: json['advisory'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'time_slot': timeSlot,
        if (event != null) 'event': event,
        'weather': weather.toJson(),
        if (advisory != null) 'advisory': advisory,
      };

  /// Whether the event in this slot is high-priority (sports/outdoors).
  bool get isHighPriority {
    if (event == null) return false;
    final lower = event!.toLowerCase();
    return lower.contains('运动') ||
        lower.contains('户外') ||
        lower.contains('跑步') ||
        lower.contains('骑行') ||
        lower.contains('锻炼') ||
        lower.contains('sport') ||
        lower.contains('outdoor') ||
        lower.contains('run') ||
        lower.contains('bike');
  }

  /// Whether weather conditions in this slot are extreme.
  bool get isExtremeWeather =>
      (weather.feelsLike ?? 0) > 38.0 || weather.precipitation > 50.0;
}
