import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../planner/domain/planner_models.dart';
import '../../settings/domain/settings_model.dart';
import '../domain/notification_tap_event.dart';
import '../domain/reminder_schedule.dart';

abstract class ReminderGateway {
  Stream<NotificationTapEvent> get taps;

  Future<void> initialize();

  Future<bool> ensurePermissions();

  Future<NotificationTapEvent?> getLaunchTap();

  Future<void> replaceSchedules(List<ReminderSchedule> schedules);
}

class InMemoryReminderGateway implements ReminderGateway {
  const InMemoryReminderGateway();

  @override
  Stream<NotificationTapEvent> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => null;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {}
}

class LocalReminderGateway implements ReminderGateway {
  LocalReminderGateway([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();
  bool _initialized = false;

  static const _channelId = 'planner_upcoming_events';
  static const _channelName = 'Upcoming events';
  static const _channelDescription = 'Reminders for scheduled planner events';

  @override
  Stream<NotificationTapEvent> get taps => _tapController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final event = NotificationTapEvent.fromPayload(response.payload);
        if (event != null && !_tapController.isClosed) {
          _tapController.add(event);
        }
      },
    );
    _initialized = true;
  }

  @override
  Future<bool> ensurePermissions() async {
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidImplementation?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<NotificationTapEvent?> getLaunchTap() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    return NotificationTapEvent.fromPayload(response?.payload);
  }

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {
    await initialize();
    final granted = await ensurePermissions();
    if (!granted) {
      return;
    }

    await _plugin.cancelAll();
    for (final schedule in schedules) {
      await _plugin.zonedSchedule(
        schedule.eventId,
        schedule.title,
        schedule.body,
        tz.TZDateTime.from(schedule.triggerAt.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: NotificationTapEvent.toPayload(schedule.eventId),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

final reminderGatewayProvider = Provider<ReminderGateway>((ref) {
  return LocalReminderGateway();
});

final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  return ReminderCoordinator(ref.watch(reminderGatewayProvider));
});

class ReminderCoordinator {
  ReminderCoordinator(this._gateway);

  final ReminderGateway _gateway;

  Future<List<ReminderSchedule>> sync({
    required List<PlannerEvent> events,
    required PlannerSettings settings,
    DateTime Function()? now,
  }) async {
    final schedules = buildReminderSchedules(
      events: events,
      settings: settings,
      now: (now ?? DateTime.now)(),
    );
    await _gateway.replaceSchedules(schedules);
    return schedules;
  }
}
