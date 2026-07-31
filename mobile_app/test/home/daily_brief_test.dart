import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/home/domain/daily_brief.dart';

void main() {
  test('parses personalized daily brief fields', () {
    final brief = DailyBrief.fromJson({
      'date': '2026-07-31',
      'summary': '今天记得带伞。',
      'compact_summary': '记得带伞',
      'comfort_tips': ['注意补水'],
      'travel_tips': ['带伞'],
      'food_tips': ['下一餐清淡一些'],
    });

    expect(brief.date, '2026-07-31');
    expect(brief.travelTips, ['带伞']);
    expect(brief.foodTips.single, contains('清淡'));
  });
}
