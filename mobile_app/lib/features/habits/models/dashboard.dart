import 'package:dio/dio.dart';

/// Dashboard data model — all six domains aggregrated.
class DashboardData {
  final String date;
  final ScheduleSnapshot schedule;
  final WeatherSnapshot weather;
  final RoutineSnapshot routine;
  final MealsSnapshot meals;
  final ExerciseSnapshot exercise;
  final TransitSnapshot transit;
  final String? patternAnnouncement;

  const DashboardData({
    required this.date,
    required this.schedule,
    required this.weather,
    required this.routine,
    required this.meals,
    required this.exercise,
    required this.transit,
    this.patternAnnouncement,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      date: json['date'] as String? ?? '',
      schedule: ScheduleSnapshot.fromJson(
          json['schedule'] as Map<String, dynamic>? ?? {}),
      weather: WeatherSnapshot.fromJson(
          json['weather'] as Map<String, dynamic>? ?? {}),
      routine: RoutineSnapshot.fromJson(
          json['routine'] as Map<String, dynamic>? ?? {}),
      meals: MealsSnapshot.fromJson(
          json['meals'] as Map<String, dynamic>? ?? {}),
      exercise: ExerciseSnapshot.fromJson(
          json['exercise'] as Map<String, dynamic>? ?? {}),
      transit: TransitSnapshot.fromJson(
          json['transit'] as Map<String, dynamic>? ?? {}),
      patternAnnouncement: json['pattern_announcement'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

class ScheduleSnapshot {
  final int pendingCount;
  final int eventCount;
  final int todoCount;
  final List<UpcomingEvent> upcoming;

  const ScheduleSnapshot({
    this.pendingCount = 0,
    this.eventCount = 0,
    this.todoCount = 0,
    this.upcoming = const [],
  });

  factory ScheduleSnapshot.fromJson(Map<String, dynamic> json) {
    final list = json['upcoming'] as List<dynamic>? ?? [];
    return ScheduleSnapshot(
      pendingCount: json['pending_count'] as int? ?? 0,
      eventCount: json['event_count'] as int? ?? 0,
      todoCount: json['todo_count'] as int? ?? 0,
      upcoming: list
          .map((e) => UpcomingEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UpcomingEvent {
  final int id;
  final String title;
  final String time;
  final String status;

  const UpcomingEvent({
    required this.id,
    required this.title,
    required this.time,
    required this.status,
  });

  factory UpcomingEvent.fromJson(Map<String, dynamic> json) {
    return UpcomingEvent(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Weather
// ---------------------------------------------------------------------------

class WeatherSnapshot {
  final bool available;
  final String temp;
  final String feelsLike;
  final String condition;
  final int conditionCode;
  final String humidity;
  final String windSpeed;
  final String high;
  final String low;

  const WeatherSnapshot({
    this.available = false,
    this.temp = '--',
    this.feelsLike = '--',
    this.condition = '--',
    this.conditionCode = 0,
    this.humidity = '--',
    this.windSpeed = '--',
    this.high = '--',
    this.low = '--',
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      available: json['available'] as bool? ?? false,
      temp: _fmt(json['temp']),
      feelsLike: _fmt(json['feels_like']),
      condition: json['condition'] as String? ?? '--',
      conditionCode: json['condition_code'] as int? ?? 0,
      humidity: _fmt(json['humidity']),
      windSpeed: _fmt(json['wind_speed']),
      high: _fmt(json['high']),
      low: _fmt(json['low']),
    );
  }

  String get displayTemp => available ? '$temp°C' : '--';
  String get displayRange => available ? '$high° / $low°' : '--';
}

// ---------------------------------------------------------------------------
// Routine
// ---------------------------------------------------------------------------

class RoutineSnapshot {
  final bool available;
  final String wakeTime;
  final String wakeSource;
  final String sleepTime;
  final bool standingEnabled;
  final int standingCompleted;
  final int standingTotal;
  final bool autoStopped;

  const RoutineSnapshot({
    this.available = false,
    this.wakeTime = '07:30',
    this.wakeSource = 'default',
    this.sleepTime = '23:30',
    this.standingEnabled = false,
    this.standingCompleted = 0,
    this.standingTotal = 0,
    this.autoStopped = false,
  });

  factory RoutineSnapshot.fromJson(Map<String, dynamic> json) {
    return RoutineSnapshot(
      available: json['available'] as bool? ?? false,
      wakeTime: json['wake_time'] as String? ?? '07:30',
      wakeSource: json['wake_source'] as String? ?? 'default',
      sleepTime: json['sleep_time'] as String? ?? '23:30',
      standingEnabled: json['standing_enabled'] as bool? ?? false,
      standingCompleted: json['standing_completed'] as int? ?? 0,
      standingTotal: json['standing_total'] as int? ?? 0,
      autoStopped: json['auto_stopped'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Meals
// ---------------------------------------------------------------------------

class MealsSnapshot {
  final bool available;
  final int totalCalories;
  final int mealCount;
  final double weeklyAvg;
  final Map<String, dynamic> byType;

  const MealsSnapshot({
    this.available = false,
    this.totalCalories = 0,
    this.mealCount = 0,
    this.weeklyAvg = 0,
    this.byType = const {},
  });

  factory MealsSnapshot.fromJson(Map<String, dynamic> json) {
    return MealsSnapshot(
      available: json['available'] as bool? ?? false,
      totalCalories: json['total_calories'] as int? ?? 0,
      mealCount: json['meal_count'] as int? ?? 0,
      weeklyAvg: (json['weekly_avg'] as num?)?.toDouble() ?? 0,
      byType: json['by_type'] as Map<String, dynamic>? ?? {},
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise
// ---------------------------------------------------------------------------

class ExerciseSnapshot {
  final bool available;
  final int totalMinutes;
  final int totalCalories;
  final int totalSteps;
  final int recordCount;

  const ExerciseSnapshot({
    this.available = false,
    this.totalMinutes = 0,
    this.totalCalories = 0,
    this.totalSteps = 0,
    this.recordCount = 0,
  });

  factory ExerciseSnapshot.fromJson(Map<String, dynamic> json) {
    return ExerciseSnapshot(
      available: json['available'] as bool? ?? false,
      totalMinutes: json['total_minutes'] as int? ?? 0,
      totalCalories: json['total_calories'] as int? ?? 0,
      totalSteps: json['total_steps'] as int? ?? 0,
      recordCount: json['record_count'] as int? ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Transit
// ---------------------------------------------------------------------------

class TransitSnapshot {
  final bool available;
  final int tripCount;
  final List<TransitTripCard> trips;

  const TransitSnapshot({
    this.available = false,
    this.tripCount = 0,
    this.trips = const [],
  });

  factory TransitSnapshot.fromJson(Map<String, dynamic> json) {
    final list = json['trips'] as List<dynamic>? ?? [];
    return TransitSnapshot(
      available: json['available'] as bool? ?? false,
      tripCount: json['trip_count'] as int? ?? 0,
      trips: list
          .map((e) => TransitTripCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TransitTripCard {
  final int id;
  final String? plannedTime;
  final int minutesToDeparture;
  final bool completed;
  final bool skipped;

  const TransitTripCard({
    required this.id,
    this.plannedTime,
    this.minutesToDeparture = 0,
    this.completed = false,
    this.skipped = false,
  });

  factory TransitTripCard.fromJson(Map<String, dynamic> json) {
    return TransitTripCard(
      id: json['id'] as int? ?? 0,
      plannedTime: json['planned_time'] as String?,
      minutesToDeparture: json['minutes_to_departure'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
    );
  }

  String get countdownDisplay {
    if (minutesToDeparture <= 0) return '已发车';
    if (minutesToDeparture < 60) return '${minutesToDeparture}分钟后发车';
    final h = minutesToDeparture ~/ 60;
    final m = minutesToDeparture % 60;
    return '${h}小时${m}分钟后发车';
  }
}

// ---------------------------------------------------------------------------
// Dashboard service
// ---------------------------------------------------------------------------

class DashboardService {
  final Dio _dio;

  DashboardService({required Dio dio}) : _dio = dio;

  Future<DashboardData?> fetchOverview({
    double? lat,
    double? lon,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (lat != null) params['lat'] = lat.toString();
      if (lon != null) params['lon'] = lon.toString();

      final response = await _dio.get(
        '/dashboard/overview',
        queryParameters: params.isNotEmpty ? params : null,
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        return DashboardData.fromJson(data['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmt(dynamic v) {
  if (v == null) return '--';
  final s = v.toString();
  if (s.isEmpty) return '--';
  if (s == '-999') return '--';
  return s;
}
