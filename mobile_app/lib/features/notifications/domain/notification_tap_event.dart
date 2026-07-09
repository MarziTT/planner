class NotificationTapEvent {
  const NotificationTapEvent({required this.eventId});

  final int eventId;

  static NotificationTapEvent? fromPayload(String? payload) {
    if (payload == null || !payload.startsWith('event:')) {
      return null;
    }
    final id = int.tryParse(payload.substring('event:'.length));
    if (id == null) {
      return null;
    }
    return NotificationTapEvent(eventId: id);
  }

  static String toPayload(int eventId) => 'event:$eventId';
}
