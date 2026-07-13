import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/notifications/data/reminder_gateway.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/notification_tap_event.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/reminder_schedule.dart';
import 'package:pixel_planner_mobile/features/settings/domain/settings_model.dart';

class _FakeReminderGateway implements ReminderGateway {
  List<ReminderSchedule> captured = const [];

  @override
  Stream<NotificationTapEvent> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => null;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {
    captured = schedules;
  }
}

void main() {
  test('scheduler creates reminders for upcoming events using lead minutes', () {
    final now = DateTime(2026, 7, 9, 9, 0);
    final settings = PlannerSettings.fromJson({
      'notificationsEnabled': true,
      'notificationsLeadMinutes': 20,
    });
    final schedules = buildReminderSchedules(
      events: [
        PlannerEvent(
          id: 1,
          title: '下午开会',
          startsAt: DateTime(2026, 7, 9, 15, 0),
          endsAt: DateTime(2026, 7, 9, 16, 0),
          status: 'planned',
        ),
        PlannerEvent(
          id: 2,
          title: '已经过去的事',
          startsAt: DateTime(2026, 7, 9, 8, 0),
          endsAt: DateTime(2026, 7, 9, 8, 30),
          status: 'planned',
        ),
      ],
      settings: settings,
      now: now,
    );

    expect(schedules, hasLength(1));
    expect(schedules.single.eventId, 1);
    expect(schedules.single.triggerAt, DateTime(2026, 7, 9, 14, 40));
  });

  test('coordinator forwards built schedules to the gateway', () async {
    final gateway = _FakeReminderGateway();
    final coordinator = ReminderCoordinator(gateway);
    final settings = PlannerSettings.fromJson({
      'notificationsEnabled': true,
      'notificationsLeadMinutes': 10,
    });

    final schedules = await coordinator.sync(
      events: [
        PlannerEvent(
          id: 9,
          title: '晚饭',
          startsAt: DateTime(2026, 7, 9, 19, 0),
          endsAt: DateTime(2026, 7, 9, 20, 0),
          status: 'planned',
        ),
      ],
      settings: settings,
      now: () => DateTime(2026, 7, 9, 18, 0),
    );

    expect(gateway.captured, hasLength(1));
    expect(gateway.captured.single.eventId, 9);
    expect(schedules.single.triggerAt, DateTime(2026, 7, 9, 18, 50));
  });
}
