import 'dart:async';
import 'dart:ui';

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

  static const _channelId = 'planner_lock_screen_events_v2';
  static const _channelName = '锁屏日程提醒';
  static const _channelDescription = '在通知栏和锁屏显示即将到来的日程';
  static const _quickCaptureActionId = 'open_quick_capture';
  static const _openEventActionId = 'open_event';

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
        final event = response.actionId == _quickCaptureActionId
            ? const NotificationTapEvent.quickCapture()
            : NotificationTapEvent.fromPayload(response.payload);
        if (event != null && !_tapController.isClosed) {
          _tapController.add(event);
        }
      },
    );
    _initialized = true;
  }

  @override
  Future<bool> ensurePermissions() async {
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidImplementation?.requestNotificationsPermission() ??
        true;
  }

  @override
  Future<NotificationTapEvent?> getLaunchTap() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (response?.actionId == _quickCaptureActionId) {
      return const NotificationTapEvent.quickCapture();
    }
    return NotificationTapEvent.fromPayload(response?.payload);
  }

  AndroidNotificationDetails _buildAndroidNotificationDetails(ReminderSchedule schedule) {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      color: Color(0xFF2F6BFF),
      showWhen: true,
      when: schedule.startsAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      showProgress: true,
      maxProgress: schedule.leadMinutes,
      progress: 0,
      styleInformation: BigTextStyleInformation(
        _expandedReminderText(schedule),
        contentTitle: schedule.title,
        summaryText: 'FlowDay 日程',
      ),
      ticker: schedule.title,
      subText: _timeLabel(schedule.startsAt),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          _openEventActionId,
          '查看',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _quickCaptureActionId,
          '新增行程',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );
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
        NotificationDetails(
          android: _buildAndroidNotificationDetails(schedule),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
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

String _expandedReminderText(ReminderSchedule schedule) {
  return [
    '时间：${_timeLabel(schedule.startsAt)}',
    '提醒：还有 ${schedule.leadMinutes} 分钟开始',
    schedule.nextSummary,
    '点“查看”回到这条日程，点“新增行程”直接速记。',
  ].join('\n');
}

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
