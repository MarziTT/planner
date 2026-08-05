class ParseResult {
  const ParseResult({
    required this.intent,
    // --- create_event fields (legacy) ---
    this.eventName,
    this.person,
    this.location,
    this.datetimeStart,
    this.datetimeEnd,
    this.isFuzzy = false,
    // --- log_meal fields ---
    this.mealType,
    this.foodName,
    this.caloriesEstimate,
    // --- log_exercise fields ---
    this.exerciseType,
    this.durationMinutes,
    this.intensity,
    // --- log_routine fields ---
    this.routineType,
    this.routineValue,
    // --- query fields ---
    this.queryType,
    this.queryText,
    this.answer,
    // --- create_reminder fields ---
    this.reminderText,
    // --- common ---
    this.confidence = 0.0,
  });

  final String intent;
  final String? eventName;
  final String? person;
  final String? location;
  final DateTime? datetimeStart;
  final DateTime? datetimeEnd;
  final bool isFuzzy;
  final String? mealType;
  final String? foodName;
  final int? caloriesEstimate;
  final String? exerciseType;
  final int? durationMinutes;
  final String? intensity;
  final String? routineType;
  final String? routineValue;
  final String? queryType;
  final String? queryText;
  final String? answer;
  final String? reminderText;
  final double confidence;

  ParseResult copyWith({
    String? eventName,
    DateTime? datetimeStart,
    DateTime? datetimeEnd,
  }) {
    return ParseResult(
      intent: intent,
      eventName: eventName ?? this.eventName,
      person: person,
      location: location,
      datetimeStart: datetimeStart ?? this.datetimeStart,
      datetimeEnd: datetimeEnd ?? this.datetimeEnd,
      isFuzzy: isFuzzy,
      mealType: mealType,
      foodName: foodName,
      caloriesEstimate: caloriesEstimate,
      exerciseType: exerciseType,
      durationMinutes: durationMinutes,
      intensity: intensity,
      routineType: routineType,
      routineValue: routineValue,
      queryType: queryType,
      queryText: queryText,
      answer: answer,
      reminderText: reminderText,
      confidence: confidence,
    );
  }

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
      mealType: json['meal_type'] as String?,
      foodName: json['food_name'] as String?,
      caloriesEstimate: (json['calories_estimate'] as num?)?.toInt(),
      exerciseType: json['exercise_type'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      intensity: json['intensity'] as String?,
      routineType: json['routine_type'] as String?,
      routineValue: json['routine_value'] as String?,
      queryType: json['query_type'] as String?,
      queryText: json['query_text'] as String?,
      answer: json['answer'] as String?,
      reminderText: json['reminder_text'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'event_name': eventName,
      'person': person,
      'location': location,
      if (datetimeStart != null) 'start': datetimeStart!.toIso8601String(),
      if (datetimeEnd != null) 'end': datetimeEnd!.toIso8601String(),
      'is_fuzzy': isFuzzy,
      'meal_type': mealType,
      'food_name': foodName,
      'calories_estimate': caloriesEstimate,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      'routine_type': routineType,
      'routine_value': routineValue,
      if (datetimeStart != null && datetimeEnd != null)
        'datetime_range': {
          'start': datetimeStart!.toIso8601String(),
          'end': datetimeEnd!.toIso8601String(),
        },
      'confidence': confidence,
    };
  }
}
