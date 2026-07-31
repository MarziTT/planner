class DailyBrief {
  const DailyBrief({
    required this.date,
    required this.summary,
    required this.compactSummary,
    required this.comfortTips,
    required this.travelTips,
    required this.foodTips,
  });

  final String date;
  final String summary;
  final String compactSummary;
  final List<String> comfortTips;
  final List<String> travelTips;
  final List<String> foodTips;

  factory DailyBrief.fromJson(Map<String, dynamic> json) => DailyBrief(
        date: json['date'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        compactSummary: json['compact_summary'] as String? ?? '',
        comfortTips: _strings(json['comfort_tips']),
        travelTips: _strings(json['travel_tips']),
        foodTips: _strings(json['food_tips']),
      );

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList(growable: false) : const [];
}
