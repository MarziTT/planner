/// Domain models for P3-F1: AI schedule optimization.
///
/// These models represent scheduling suggestions and conflict information
/// returned by the backend scheduler engine.

/// A recommended time slot with a convenience score.
class TimeSuggestion {
  final DateTime startsAt;
  final DateTime endsAt;
  final String period; // "morning" | "afternoon" | "evening"
  final int score; // 0-100

  const TimeSuggestion({
    required this.startsAt,
    required this.endsAt,
    required this.period,
    required this.score,
  });

  factory TimeSuggestion.fromJson(Map<String, dynamic> json) {
    return TimeSuggestion(
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      period: json['period'] as String? ?? 'morning',
      score: json['score'] as int? ?? 0,
    );
  }

  /// Format the time range for display: e.g. "09:00 - 10:00"
  String get timeRangeLabel {
    final startStr =
        '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  /// Human-readable period label in Chinese.
  String get periodLabel {
    switch (period) {
      case 'morning':
        return '上午';
      case 'afternoon':
        return '下午';
      case 'evening':
        return '晚上';
      default:
        return period;
    }
  }
}

/// Full suggestion response from the backend.
class ScheduleSuggestion {
  final String date;
  final int durationMinutes;
  final Map<String, dynamic> patternsUsed;
  final List<Map<String, dynamic>> existingEvents;
  final List<TimeSuggestion> suggestions;

  const ScheduleSuggestion({
    required this.date,
    required this.durationMinutes,
    required this.patternsUsed,
    required this.existingEvents,
    required this.suggestions,
  });

  factory ScheduleSuggestion.fromJson(Map<String, dynamic> json) {
    return ScheduleSuggestion(
      date: json['date'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      patternsUsed:
          json['patterns_used'] as Map<String, dynamic>? ?? {},
      existingEvents: (json['existing_events'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) =>
                  TimeSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Best suggestion (highest score), or null if none available.
  TimeSuggestion? get bestSuggestion =>
      suggestions.isNotEmpty ? suggestions.first : null;

  /// Top N suggestions sorted by score descending.
  List<TimeSuggestion> topSuggestions([int n = 3]) =>
      suggestions.take(n).toList();
}

/// Conflict check response.
class ConflictCheck {
  final bool hasConflicts;
  final List<ConflictItem> conflicts;

  const ConflictCheck({
    required this.hasConflicts,
    required this.conflicts,
  });

  factory ConflictCheck.fromJson(Map<String, dynamic> json) {
    return ConflictCheck(
      hasConflicts: json['has_conflicts'] as bool? ?? false,
      conflicts: (json['conflicts'] as List<dynamic>?)
              ?.map((c) =>
                  ConflictItem.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A single conflicting event.
class ConflictItem {
  final int id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final int overlapMinutes;

  const ConflictItem({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.overlapMinutes,
  });

  factory ConflictItem.fromJson(Map<String, dynamic> json) {
    return ConflictItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      overlapMinutes: json['overlap_minutes'] as int? ?? 0,
    );
  }

  String get timeRangeLabel {
    final fmt = (DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${fmt(startsAt)} - ${fmt(endsAt)}';
  }
}
