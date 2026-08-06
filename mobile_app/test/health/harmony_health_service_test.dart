import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/health/data/harmony_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/harmony_health');
  final messenger = TestDefaultBinaryMessengerBinding.instance;
  final service = HarmonyHealthService(channel: channel);

  tearDown(() {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('requests body composition permissions', () async {
    MethodCall? captured;
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      captured = call;
      return call.method == 'isAvailable' ? true : true;
    });

    expect(await service.requestAuthorization(), isTrue);
    expect(captured?.method, 'requestAuthorization');
    expect((captured?.arguments as Map)['dataTypes'], contains('weight'));
  });

  test('accepts delayed activity permission after status recheck', () async {
    final calls = <String>[];
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'isAvailable' => true,
        'requestActivityAuthorization' => false,
        'activityAuthorizationStatus' => 'authorized',
        _ => null,
      };
    });

    expect(await service.requestActivityAuthorization(), isTrue);
    expect(
        calls,
        containsAllInOrder([
          'isAvailable',
          'requestActivityAuthorization',
          'isAvailable',
          'activityAuthorizationStatus',
        ]));
  });

  test('reads activity report debug payload', () async {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'readTodayActivityReportDebug') {
        return <String, Object?>{
          'authorizationStatus': 'authorized',
          'debugMessage': null,
          'report': <String, Object>{
            'steps': 1234,
            'activeCalories': 88,
            'exerciseMinutes': 12,
            'activeHours': 3,
            'source': 'huawei_health',
          },
        };
      }
      return null;
    });

    final debug = await service.readTodayActivityReportDebug();

    expect(debug.authorizationStatus, HealthAuthorizationStatus.authorized);
    expect(debug.debugMessage, isNull);
    expect(debug.report?.steps, 1234);
    expect(debug.report?.exerciseMinutes, 12);
  });

  test('parses and sorts body measurements newest first', () async {
    messenger.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isAvailable') return true;
      return <Map<String, Object>>[
        {'measuredAt': '2026-07-01T08:00:00+08:00', 'weightKg': 72},
        {
          'measuredAt': '2026-07-02T08:00:00+08:00',
          'weightKg': 71.5,
          'bodyFatPercent': 18.2,
        },
      ];
    });

    final values = await service.readBodyMeasurements(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 3),
    );

    expect(values, hasLength(2));
    expect(values.first.weightKg, 71.5);
    expect(values.first.bodyFatPercent, 18.2);
  });

  test('rejects an inverted time range', () async {
    expect(
      () => service.readBodyMeasurements(
        start: DateTime(2026, 7, 2),
        end: DateTime(2026, 7, 1),
      ),
      throwsArgumentError,
    );
  });
}
