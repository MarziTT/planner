// Smart notification models — P3-F3.
//
// Mirrors the JSON returned by:
//   GET /api/v1/notify/insights
//   GET /api/v1/notify/history

class NotifyInsight {
  final String insightType;
  final String priority; // high / medium / low
  final String title;
  final String body;
  final Map<String, dynamic>? data;

  const NotifyInsight({
    required this.insightType,
    required this.priority,
    required this.title,
    required this.body,
    this.data,
  });

  factory NotifyInsight.fromJson(Map<String, dynamic> json) {
    return NotifyInsight(
      insightType: json['insight_type'] as String? ?? '',
      priority: json['priority'] as String? ?? 'low',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// Emoji icon for the insight type.
  String get icon {
    switch (insightType) {
      case 'wake_deviation':
        return '☀️';
      case 'standing_nudge':
        return '🪑';
      case 'exercise_drop':
        return '📉';
      case 'meal_sync':
        return '🍽️';
      case 'sleep_reminder':
        return '🌙';
      default:
        return '🔔';
    }
  }

  /// Color label for priority.
  String get priorityLabel {
    switch (priority) {
      case 'high':
        return '重要';
      case 'medium':
        return '提醒';
      case 'low':
        return '建议';
      default:
        return priority;
    }
  }
}

class InsightsResult {
  final int userId;
  final String? generatedAt;
  final int count;
  final List<NotifyInsight> insights;

  const InsightsResult({
    required this.userId,
    this.generatedAt,
    required this.count,
    required this.insights,
  });

  factory InsightsResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['insights'] as List<dynamic>? ?? [];
    return InsightsResult(
      userId: json['user_id'] as int? ?? 0,
      generatedAt: json['generated_at'] as String?,
      count: json['count'] as int? ?? 0,
      insights: rawList
          .map((e) => NotifyInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NotifyHistoryEntry {
  final int id;
  final int? eventId;
  final String notifyType;
  final String? plannedTime;
  final String? remindedAt;
  final String? completedAt;
  final bool skipped;
  final int delayedCount;
  final String? createdAt;

  const NotifyHistoryEntry({
    required this.id,
    this.eventId,
    required this.notifyType,
    this.plannedTime,
    this.remindedAt,
    this.completedAt,
    required this.skipped,
    required this.delayedCount,
    this.createdAt,
  });

  factory NotifyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return NotifyHistoryEntry(
      id: json['id'] as int? ?? 0,
      eventId: json['event_id'] as int?,
      notifyType: json['notify_type'] as String? ?? '',
      plannedTime: json['planned_time'] as String?,
      remindedAt: json['reminded_at'] as String?,
      completedAt: json['completed_at'] as String?,
      skipped: json['skipped'] as bool? ?? false,
      delayedCount: json['delayed_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  String get typeLabel {
    switch (notifyType) {
      case 'transit':
        return '出行';
      case 'standing':
        return '站立';
      case 'meal':
        return '饮食';
      case 'exercise':
        return '运动';
      case 'sleep':
        return '睡眠';
      default:
        return notifyType;
    }
  }

  String get typeIcon {
    switch (notifyType) {
      case 'transit':
        return '🚗';
      case 'standing':
        return '🧍';
      case 'meal':
        return '🍽️';
      case 'exercise':
        return '🏃';
      case 'sleep':
        return '😴';
      default:
        return '🔔';
    }
  }
}

class NotifyHistoryResult {
  final int userId;
  final int total;
  final int skipped;
  final int completed;
  final List<NotifyHistoryEntry> entries;

  const NotifyHistoryResult({
    required this.userId,
    required this.total,
    required this.skipped,
    required this.completed,
    required this.entries,
  });

  factory NotifyHistoryResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['entries'] as List<dynamic>? ?? [];
    return NotifyHistoryResult(
      userId: json['user_id'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      entries: rawList
          .map((e) => NotifyHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
