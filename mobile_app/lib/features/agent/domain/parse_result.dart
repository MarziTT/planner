class ParseResult {
  const ParseResult({
    required this.intent,
    this.eventName,
    this.person,
    this.location,
    this.datetimeStart,
    this.datetimeEnd,
    this.isFuzzy = false,
    this.confidence = 0.0,
  });

  final String intent;
  final String? eventName;
  final String? person;
  final String? location;
  final DateTime? datetimeStart;
  final DateTime? datetimeEnd;
  final bool isFuzzy;
  final double confidence;

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    final range = json['datetime_range'] as Map<String, dynamic>?;
    DateTime? start;
    DateTime? end;
    if (range != null) {
      final startStr = range['start'] as String?;
      final endStr = range['end'] as String?;
      start = startStr != null ? DateTime.tryParse(startStr) : null;
      end = endStr != null ? DateTime.tryParse(endStr) : null;
    }
    return ParseResult(
      intent: json['intent'] as String? ?? 'unknown',
      eventName: json['event_name'] as String?,
      person: json['person'] as String?,
      location: json['location'] as String?,
      datetimeStart: start,
      datetimeEnd: end,
      isFuzzy: json['is_fuzzy'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ParseResult copyWith({
    String? intent,
    String? eventName,
    String? person,
    String? location,
    DateTime? datetimeStart,
    DateTime? datetimeEnd,
    bool? isFuzzy,
    double? confidence,
  }) {
    return ParseResult(
      intent: intent ?? this.intent,
      eventName: eventName ?? this.eventName,
      person: person ?? this.person,
      location: location ?? this.location,
      datetimeStart: datetimeStart ?? this.datetimeStart,
      datetimeEnd: datetimeEnd ?? this.datetimeEnd,
      isFuzzy: isFuzzy ?? this.isFuzzy,
      confidence: confidence ?? this.confidence,
    );
  }
}
