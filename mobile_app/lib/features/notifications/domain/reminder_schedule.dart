import '../../planner/domain/planner_models.dart';
import '../../settings/domain/settings_model.dart';

class ReminderSchedule {
  const ReminderSchedule({
    required this.eventId,
    required this.title,
    required this.body,
    required this.triggerAt,
    required this.startsAt,
    required this.leadMinutes,
    required this.nextSummary,
  });

  final int eventId;
  final String title;
  final String body;
  final DateTime triggerAt;
  final DateTime startsAt;
  final int leadMinutes;
  final String nextSummary;
}

List<ReminderSchedule> buildReminderSchedules({
  required List<PlannerEvent> events,
  required PlannerSettings settings,
  required DateTime now,
}) {
  if (!settings.notificationsEnabled) {
    return const [];
  }

  final upcoming = events.where((event) => event.startsAt.isAfter(now)).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  final schedules = <ReminderSchedule>[];
  for (var index = 0; index < upcoming.length; index += 1) {
    final event = upcoming[index];
    final triggerAt = event.startsAt.subtract(
      Duration(minutes: settings.notificationsLeadMinutes),
    );
    if (!triggerAt.isAfter(now)) {
      continue;
    }

    final nextEvent = index + 1 < upcoming.length ? upcoming[index + 1] : null;
    final nextLine = nextEvent == null
        ? '后面暂时没有其他安排'
        : '下一条 ${_timeLabel(nextEvent.startsAt)} ${nextEvent.title}';

    schedules.add(
      ReminderSchedule(
        eventId: event.id,
        title: '即将开始：${event.title}',
        body:
            '${_timeLabel(event.startsAt)} · 还有 ${settings.notificationsLeadMinutes} 分钟 · $nextLine',
        triggerAt: triggerAt,
        startsAt: event.startsAt,
        leadMinutes: settings.notificationsLeadMinutes,
        nextSummary: nextLine,
      ),
    );
  }
  return schedules;
}

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
