class PlannerTag {
  const PlannerTag({
    required this.id,
    required this.name,
    required this.color,
    this.isRecurring = false,
    this.recurrenceRule = '',
  });

  final int id;
  final String name;
  final String color;
  final bool isRecurring;
  final String recurrenceRule;

  factory PlannerTag.fromJson(Map<String, dynamic> json) {
    return PlannerTag(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#5B8CFF',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] as String? ?? '',
    );
  }
}
