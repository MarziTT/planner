class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    return PlannerEvent(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String? ?? 'planned',
    );
  }
}

class PlannerTodo {
  const PlannerTodo({
    required this.id,
    required this.title,
    required this.completed,
  });

  final int id;
  final String title;
  final bool completed;

  factory PlannerTodo.fromJson(Map<String, dynamic> json) {
    return PlannerTodo(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
    );
  }
}
