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

  // Multi-stage lead times: farther away → earlier reminder, closer → shorter
  const stages = [1440, 120, 30, 15, 5]; // 1 day, 2 hours, 30 min, 15 min, 5 min

  final schedules = <ReminderSchedule>[];
  for (var index = 0; index < upcoming.length; index += 1) {
    final event = upcoming[index];

    for (final leadMinutes in stages) {
      final triggerAt = event.startsAt.subtract(
        Duration(minutes: leadMinutes),
      );
      if (!triggerAt.isAfter(now)) {
        continue;
      }

      final nextEvent = index + 1 < upcoming.length ? upcoming[index + 1] : null;
      final nextLine = nextEvent == null
          ? '后面暂时没有其他安排'
          : '下一条 ${_timeLabel(nextEvent.startsAt)} ${nextEvent.title}';

      final leadLabel = leadMinutes >= 1440
          ? '${leadMinutes ~/ 1440} 天'
          : leadMinutes >= 60
              ? '${leadMinutes ~/ 60} 小时'
              : '$leadMinutes 分钟';

      schedules.add(
        ReminderSchedule(
          eventId: event.id * 100 + leadMinutes, // composite ID for multi-stage
          title: '即将开始：${event.title}',
          body: '${_timeLabel(event.startsAt)} · 还有 $leadLabel · $nextLine',
          triggerAt: triggerAt,
          startsAt: event.startsAt,
          leadMinutes: leadMinutes,
          nextSummary: nextLine,
        ),
      );
    }
  }
  return schedules;
}

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
