import 'package:flutter/services.dart';

import '../domain/body_measurement.dart';

enum HealthAuthorizationStatus {
  unavailable,
  notDetermined,
  denied,
  authorized
}

class HarmonyHealthService {
  static const MethodChannel _defaultChannel =
      MethodChannel('pixelplanner/harmony_health');

  final MethodChannel _channel;

  const HarmonyHealthService({MethodChannel? channel})
      : _channel = channel ?? _defaultChannel;

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<HealthAuthorizationStatus> authorizationStatus() async {
    if (!await isAvailable()) return HealthAuthorizationStatus.unavailable;
    final value = await _channel.invokeMethod<String>('authorizationStatus');
    return switch (value) {
      'authorized' => HealthAuthorizationStatus.authorized,
      'denied' => HealthAuthorizationStatus.denied,
      _ => HealthAuthorizationStatus.notDetermined,
    };
  }

  Future<HealthAuthorizationStatus> activityAuthorizationStatus() async {
    if (!await isAvailable()) return HealthAuthorizationStatus.unavailable;
    final value =
        await _channel.invokeMethod<String>('activityAuthorizationStatus');
    return switch (value) {
      'authorized' => HealthAuthorizationStatus.authorized,
      'denied' => HealthAuthorizationStatus.denied,
      _ => HealthAuthorizationStatus.notDetermined,
    };
  }

  Future<bool> requestAuthorization() async {
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'requestAuthorization',
            const <String, Object>{
              'dataTypes': <String>[
                'weight',
                'bmi',
                'bodyFat',
                'muscleMass',
                'bodyWater',
                'basalMetabolicRate',
                'visceralFat',
              ],
            },
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestActivityAuthorization() async {
    if (!await isAvailable()) return false;
    try {
      final granted = await _channel.invokeMethod<bool>(
            'requestActivityAuthorization',
            const <String, Object>{
              'dataTypes': <String>[
                'dailyActivities',
                'workout',
              ],
            },
          ) ??
          false;
      if (granted) return true;
      final status = await activityAuthorizationStatus();
      return status == HealthAuthorizationStatus.authorized;
    } on PlatformException {
      final status = await activityAuthorizationStatus();
      return status == HealthAuthorizationStatus.authorized;
    }
  }

  Future<List<BodyMeasurement>> readBodyMeasurements({
    required DateTime start,
    required DateTime end,
  }) async {
    if (end.isBefore(start)) {
      throw ArgumentError.value(end, 'end', 'must not be before start');
    }
    if (!await isAvailable()) return const [];

    final rows = await _channel.invokeListMethod<Object?>(
          'readBodyMeasurements',
          <String, Object>{
            'startTime': start.toUtc().toIso8601String(),
            'endTime': end.toUtc().toIso8601String(),
          },
        ) ??
        const [];

    final measurements = rows
        .whereType<Map<Object?, Object?>>()
        .map((row) => BodyMeasurement.fromJson(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
    measurements.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return measurements;
  }

  Future<BodyMeasurement?> readLatestBodyMeasurement({
    required DateTime start,
    required DateTime end,
  }) async {
    final measurements = await readBodyMeasurements(start: start, end: end);
    return measurements.isEmpty ? null : measurements.first;
  }

  Future<HealthActivityReport?> readTodayActivityReport() async {
    if (!await isAvailable()) return null;
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'readTodayActivityReport',
      );
      if (value == null) return null;
      final json = value.map((key, value) => MapEntry(key.toString(), value));
      return HealthActivityReport.fromJson(json);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<HealthActivityReportDebug> readTodayActivityReportDebug() async {
    if (!await isAvailable()) {
      return const HealthActivityReportDebug(
        report: null,
        authorizationStatus: HealthAuthorizationStatus.unavailable,
      );
    }
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'readTodayActivityReportDebug',
      );
      if (value == null) {
        return const HealthActivityReportDebug(
          report: null,
          authorizationStatus: HealthAuthorizationStatus.notDetermined,
        );
      }
      final json = value.map((key, value) => MapEntry(key.toString(), value));
      final reportValue = json['report'];
      final report = reportValue is Map
          ? HealthActivityReport.fromJson(
              reportValue.map((key, value) => MapEntry(key.toString(), value)),
            )
          : null;
      return HealthActivityReportDebug(
        report: report,
        authorizationStatus: _parseAuthorizationStatus(
          json['authorizationStatus'] as String?,
        ),
        debugMessage: json['debugMessage'] as String?,
      );
    } on MissingPluginException {
      return const HealthActivityReportDebug(
        report: null,
        authorizationStatus: HealthAuthorizationStatus.unavailable,
      );
    } on PlatformException catch (error) {
      return HealthActivityReportDebug(
        report: null,
        authorizationStatus: HealthAuthorizationStatus.notDetermined,
        debugMessage: error.message ?? error.toString(),
      );
    }
  }

  static HealthAuthorizationStatus _parseAuthorizationStatus(String? value) {
    return switch (value) {
      'authorized' => HealthAuthorizationStatus.authorized,
      'denied' => HealthAuthorizationStatus.denied,
      'unavailable' => HealthAuthorizationStatus.unavailable,
      _ => HealthAuthorizationStatus.notDetermined,
    };
  }
}

class HealthActivityReportDebug {
  final HealthActivityReport? report;
  final HealthAuthorizationStatus authorizationStatus;
  final String? debugMessage;

  const HealthActivityReportDebug({
    required this.report,
    required this.authorizationStatus,
    this.debugMessage,
  });
}

class HealthActivityReport {
  final int steps;
  final int? stepsGoal;
  final int activeCalories;
  final int? activeCaloriesGoal;
  final int exerciseMinutes;
  final int? exerciseGoalMinutes;
  final int activeHours;
  final int? activeHoursGoal;
  final String source;

  const HealthActivityReport({
    required this.steps,
    this.stepsGoal,
    required this.activeCalories,
    this.activeCaloriesGoal,
    required this.exerciseMinutes,
    this.exerciseGoalMinutes,
    required this.activeHours,
    this.activeHoursGoal,
    this.source = 'huawei_health',
  });

  factory HealthActivityReport.fromJson(Map<String, dynamic> json) {
    return HealthActivityReport(
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      stepsGoal: _optionalInt(json['stepsGoal']),
      activeCalories: (json['activeCalories'] as num?)?.toInt() ?? 0,
      activeCaloriesGoal: _optionalInt(json['activeCaloriesGoal']),
      exerciseMinutes: (json['exerciseMinutes'] as num?)?.toInt() ?? 0,
      exerciseGoalMinutes: _optionalInt(json['exerciseGoalMinutes']),
      activeHours: (json['activeHours'] as num?)?.toInt() ?? 0,
      activeHoursGoal: _optionalInt(json['activeHoursGoal']),
      source: json['source'] as String? ?? 'huawei_health',
    );
  }

  static int? _optionalInt(Object? value) =>
      value == null ? null : (value as num).toInt();
}
