import '../../planner/domain/planner_models.dart';
import '../../settings/domain/settings_model.dart';

class ReminderSchedule {
  const ReminderSchedule({
    required this.eventId,
    required this.title,
    required this.body,
    required this.triggerAt,
  });

  final int eventId;
  final String title;
  final String body;
  final DateTime triggerAt;
}

List<ReminderSchedule> buildReminderSchedules({
  required List<PlannerEvent> events,
  required PlannerSettings settings,
  required DateTime now,
}) {
  if (!settings.notificationsEnabled) {
    return const [];
  }

  return events
      .where((event) => event.startsAt.isAfter(now))
      .map((event) {
        final triggerAt = event.startsAt.subtract(
          Duration(minutes: settings.notificationsLeadMinutes),
        );
        return ReminderSchedule(
          eventId: event.id,
          title: '即将开始: ${event.title}',
          body: '还有 ${settings.notificationsLeadMinutes} 分钟就开始了',
          triggerAt: triggerAt,
        );
      })
      .where((schedule) => schedule.triggerAt.isAfter(now))
      .toList()
    ..sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
}
