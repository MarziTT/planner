class ScheduleRequest {
  const ScheduleRequest({
    required this.eventName,
    required this.start,
    required this.end,
    this.reminderMinutes = 30,
  });

  final String eventName;
  final DateTime start;
  final DateTime end;
  final int reminderMinutes;

  Map<String, dynamic> toJson() => {
        'event_name': eventName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'reminder_minutes': reminderMinutes,
      };
}
