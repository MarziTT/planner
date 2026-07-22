class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.tagIds = const [],
  });

  final int id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final List<int> tagIds;

  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    final dynamic rawTag = json['tagId'] ?? json['tagIds'];
    final List<int> tagIds;
    if (rawTag is int) {
      tagIds = [rawTag];
    } else if (rawTag is List<dynamic>) {
      tagIds = rawTag.map((e) => (e as num).toInt()).toList();
    } else {
      tagIds = const [];
    }

    return PlannerEvent(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: json['status'] as String? ?? 'planned',
      tagIds: tagIds,
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
