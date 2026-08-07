class PersonalMemory {
  const PersonalMemory({
    required this.id,
    required this.category,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.active,
  });

  final int id;
  final String category;
  final String summary;
  final double confidence;
  final int evidenceCount;
  final bool active;

  factory PersonalMemory.fromJson(Map<String, dynamic> json) {
    return PersonalMemory(
      id: json['id'] as int,
      category: json['category'] as String? ?? 'preference',
      summary: json['summary'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      evidenceCount: json['evidenceCount'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
    );
  }

  PersonalMemory copyWith({bool? active}) => PersonalMemory(
        id: id,
        category: category,
        summary: summary,
        confidence: confidence,
        evidenceCount: evidenceCount,
        active: active ?? this.active,
      );
}
