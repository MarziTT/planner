import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/schedule_text_parser.dart';
import 'package:pixel_planner_mobile/features/fast_capture/domain/capture_enums.dart';

void main() {
  final parser = ScheduleTextParser(now: DateTime(2026, 7, 9, 9));

  test('parses today afternoon workout capture', () {
    final draft = parser.parse('今天下午七点去健身');

    expect(draft.title, '健身');
    expect(draft.eventType, CaptureEventType.workout);
    expect(draft.startsAt, DateTime(2026, 7, 9, 19));
    expect(draft.endsAt, DateTime(2026, 7, 9, 20, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.none);
    expect(draft.ambiguousHour, isNull);
  });

  test('parses tomorrow five oclock flight as ambiguous am pm hour', () {
    final draft = parser.parse('明天五点的飞机');

    expect(draft.title, '飞机');
    expect(draft.eventType, CaptureEventType.transit);
    expect(draft.startsAt, DateTime(2026, 7, 10, 5));
    expect(draft.endsAt, DateTime(2026, 7, 10, 5, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.amPmHour);
    expect(draft.ambiguousHour, 5);
  });

  test('falls back to a sensible workout time when no time is provided', () {
    final draft = parser.parse('明天健身');

    expect(draft.title, '健身');
    expect(draft.startsAt, DateTime(2026, 7, 10, 19));
    expect(draft.endsAt, DateTime(2026, 7, 10, 20, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.missingTime);
    expect(draft.suggestedPeriod, TimePeriod.evening);
  });

  test(
      'period only capture asks for time confirmation instead of guessing hour',
      () {
    final draft = parser.parse('明天下午健身');

    expect(draft.title, '健身');
    expect(draft.eventType, CaptureEventType.workout);
    expect(draft.startsAt, DateTime(2026, 7, 10, 15));
    expect(draft.ambiguityKind, TimeAmbiguityKind.missingTime);
    expect(draft.suggestedPeriod, TimePeriod.afternoon);
  });
  test('supports day after tomorrow and half past times', () {
    final draft = parser.parse('后天晚上七点半开会');

    expect(draft.title, '开会');
    expect(draft.eventType, CaptureEventType.meeting);
    expect(draft.startsAt, DateTime(2026, 7, 11, 19, 30));
    expect(draft.endsAt, DateTime(2026, 7, 11, 20, 30));
  });
  test(
      'marks missing time as pending confirmation instead of silently guessing',
      () {
    final draft = parser.parse('明天健身');

    expect(draft.title, '健身');
    expect(draft.eventType, CaptureEventType.workout);
    expect(draft.startsAt, DateTime(2026, 7, 10, 19));
    expect(draft.ambiguityKind, TimeAmbiguityKind.missingTime);
    expect(draft.suggestedPeriod, TimePeriod.evening);
  });

  test('parses relative time capture', () {
    final draft = parser.parse('半小时后开会');

    expect(draft.title, '开会');
    expect(draft.eventType, CaptureEventType.meeting);
    expect(draft.startsAt, DateTime(2026, 7, 9, 9, 30));
    expect(draft.endsAt, DateTime(2026, 7, 9, 10, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.none);
  });

  test('parses next weekday capture', () {
    final draft = parser.parse('下周一上午十点开会');

    expect(draft.title, '开会');
    expect(draft.eventType, CaptureEventType.meeting);
    expect(draft.startsAt, DateTime(2026, 7, 13, 10));
    expect(draft.endsAt, DateTime(2026, 7, 13, 11));
    expect(draft.ambiguityKind, TimeAmbiguityKind.none);
  });
}
