import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/notification_tap_event.dart';

void main() {
  test('parses event notification payload into tap event', () {
    final event = NotificationTapEvent.fromPayload('event:42');

    expect(event, isNotNull);
    expect(event!.eventId, 42);
  });

  test('returns null for malformed payload', () {
    expect(NotificationTapEvent.fromPayload('oops'), isNull);
  });
}
