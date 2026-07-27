import 'timeline_item.dart';

/// Top-level model for the smart-advisory API response.
class SmartAdvisory {
  final List<TimelineItem> timeline;
  final String summary;
  final DateTime? generatedAt;

  const SmartAdvisory({
    required this.timeline,
    required this.summary,
    this.generatedAt,
  });

  factory SmartAdvisory.fromJson(Map<String, dynamic> json) {
    final rawTimeline = json['timeline'] as List<dynamic>? ?? [];
    final generatedAtStr = json['generated_at'] as String?;

    return SmartAdvisory(
      timeline: rawTimeline
          .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String? ?? '',
      generatedAt: generatedAtStr != null
          ? DateTime.tryParse(generatedAtStr)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'summary': summary,
        if (generatedAt != null) 'generated_at': generatedAt?.toIso8601String(),
      };

  /// Top 3-4 timeline items for widget/card preview.
  List<TimelineItem> get previewItems {
    if (timeline.length <= 4) return timeline.toList();
    // Prefer high-priority items first, then fill with remaining
    final high = timeline.where((t) => t.isHighPriority).toList();
    final rest = timeline.where((t) => !t.isHighPriority).toList();
    final result = <TimelineItem>[...high, ...rest];
    return result.take(4).toList();
  }
}
