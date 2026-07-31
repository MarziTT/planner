import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/notification_tap_event.dart';

void main() {
  test('parses feature route notification payload', () {
    final event = NotificationTapEvent.fromPayload('route:exercise');
    expect(event?.routeTab, 'exercise');
    expect(event?.eventId, isNull);
    expect(event?.openQuickCapture, isFalse);
  });

  test('rejects empty route payload', () {
    expect(NotificationTapEvent.fromPayload('route:'), isNull);
  });
}
