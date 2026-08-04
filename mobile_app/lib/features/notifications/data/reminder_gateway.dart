import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../habits/notify_manager.dart';
import '../../planner/domain/planner_models.dart';
import '../../settings/domain/settings_model.dart';
import '../domain/notification_tap_event.dart';
import '../domain/reminder_schedule.dart';
import 'harmony_notification_service.dart';

bool get _isOhos => Platform.operatingSystem == 'ohos';

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

class HarmonyReminderGateway implements ReminderGateway {
  HarmonyReminderGateway({HarmonyNotificationService? service})
      : _service = service ?? HarmonyNotificationService.instance;

  final HarmonyNotificationService _service;

  @override
  Stream<NotificationTapEvent> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {
    await _service.ensureChannel(
      id: NotifyChannel.schedule.id,
      name: '日程提醒',
      description: '即将开始的日程提醒',
      priority: 'important',
      category: 'schedule',
    );
  }

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => null;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {
    await initialize();
    await _service.cancelAll();
    for (final schedule in schedules) {
      await _service.show(
        id: schedule.eventId,
        title: schedule.title,
        body: schedule.body,
        channelId: NotifyChannel.schedule.id,
        priority: schedule.leadMinutes <= 30 ? 'urgent' : 'important',
        payload: schedule.eventId.toString(),
        scheduledDate: schedule.triggerAt,
        category: 'schedule',
      );
    }
  }
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

  static bool _isNotifyManagerAction(String actionId) {
    return actionId == NotifyActionId.complete ||
        actionId == NotifyActionId.postpone ||
        actionId == NotifyActionId.skip;
  }

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
        // Phase 2: 快捷操作统一转发到 NotifyManager
        final actionId = response.actionId;
        if (actionId != null && _isNotifyManagerAction(actionId)) {
          NotifyManager.handleAction(actionId, response.payload);
          return;
        }

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

  /// 日程通知优先级：临近开始（<=30 分钟）视为紧急，否则为重要。
  NotifyPriority _schedulePriority(ReminderSchedule schedule) {
    return schedule.leadMinutes <= 30
        ? NotifyPriority.urgent
        : NotifyPriority.important;
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
      await NotifyManager.show(
        channel: NotifyChannel.schedule,
        title: schedule.title,
        body: schedule.body,
        priority: _schedulePriority(schedule),
        payload: NotifyPayload(
          eventType: 'schedule',
          eventId: schedule.eventId,
          scheduleId: schedule.eventId,
          channelId: NotifyChannel.schedule.id,
        ),
        scheduledDate: schedule.triggerAt,
        notificationId: schedule.eventId,
        styleInformation: BigTextStyleInformation(
          _expandedReminderText(schedule),
          contentTitle: schedule.title,
          summaryText: 'DD 管家',
        ),
        subText: _timeLabel(schedule.startsAt),
        when: schedule.startsAt,
        extraActions: const <AndroidNotificationAction>[
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
  }
}

final reminderGatewayProvider = Provider<ReminderGateway>((ref) {
  if (_isOhos) {
    return HarmonyReminderGateway();
  }
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
