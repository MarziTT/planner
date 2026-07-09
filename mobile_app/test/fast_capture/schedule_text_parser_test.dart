import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/schedule_text_parser.dart';
import 'package:pixel_planner_mobile/features/fast_capture/domain/capture_enums.dart';

void main() {
  final parser = ScheduleTextParser(now: DateTime(2026, 7, 9, 9));

  test('parses today afternoon workout capture', () {
    final draft = parser.parse('\u4eca\u5929\u4e0b\u5348\u4e03\u70b9\u53bb\u5065\u8eab');

    expect(draft.title, '\u53bb\u5065\u8eab');
    expect(draft.eventType, CaptureEventType.workout);
    expect(draft.startsAt, DateTime(2026, 7, 9, 19));
    expect(draft.endsAt, DateTime(2026, 7, 9, 20, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.none);
    expect(draft.ambiguousHour, isNull);
  });

  test('parses tomorrow five oclock flight as ambiguous am pm hour', () {
    final draft = parser.parse('\u660e\u5929\u4e94\u70b9\u7684\u98de\u673a');

    expect(draft.title, '\u98de\u673a');
    expect(draft.eventType, CaptureEventType.transit);
    expect(draft.startsAt, DateTime(2026, 7, 10, 5));
    expect(draft.endsAt, DateTime(2026, 7, 10, 5, 30));
    expect(draft.ambiguityKind, TimeAmbiguityKind.amPmHour);
    expect(draft.ambiguousHour, 5);
  });
}
