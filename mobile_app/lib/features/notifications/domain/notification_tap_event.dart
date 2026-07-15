class NotificationTapEvent {
  const NotificationTapEvent({required this.eventId})
      : openQuickCapture = false;

  const NotificationTapEvent._({this.eventId, required this.openQuickCapture});

  const NotificationTapEvent.event({required int eventId})
      : this._(eventId: eventId, openQuickCapture: false);

  const NotificationTapEvent.quickCapture()
      : this._(eventId: null, openQuickCapture: true);

  final int? eventId;
  final bool openQuickCapture;

  static NotificationTapEvent? fromPayload(String? payload) {
    if (payload == quickCapturePayload) {
      return const NotificationTapEvent.quickCapture();
    }
    if (payload == null || !payload.startsWith('event:')) {
      return null;
    }
    final id = int.tryParse(payload.substring('event:'.length));
    if (id == null) {
      return null;
    }
    return NotificationTapEvent.event(eventId: id);
  }

  static String toPayload(int eventId) => 'event:$eventId';

  static const quickCapturePayload = 'quick_capture';
}


