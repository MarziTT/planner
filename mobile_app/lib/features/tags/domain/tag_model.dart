class PlannerTag {
  const PlannerTag({
    required this.id,
    required this.name,
    required this.color,
  });

  final int id;
  final String name;
  final String color;

  factory PlannerTag.fromJson(Map<String, dynamic> json) {
    return PlannerTag(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#5B8CFF',
    );
  }
}
