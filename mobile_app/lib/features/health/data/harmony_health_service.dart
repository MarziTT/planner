import 'package:flutter/services.dart';

import '../domain/body_measurement.dart';

enum HealthAuthorizationStatus { unavailable, notDetermined, denied, authorized }

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

  Future<bool> requestAuthorization() async {
    if (!await isAvailable()) return false;
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
}
