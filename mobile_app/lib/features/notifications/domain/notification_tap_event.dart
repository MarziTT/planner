class NotificationTapEvent {
  const NotificationTapEvent._({
    this.eventId,
    required this.openQuickCapture,
    this.routeTab,
  });

  const NotificationTapEvent.event({required int eventId})
      : this._(eventId: eventId, openQuickCapture: false, routeTab: 'dashboard');

  const NotificationTapEvent.quickCapture()
      : this._(eventId: null, openQuickCapture: true, routeTab: 'dashboard');

  const NotificationTapEvent.route(String tab)
      : this._(eventId: null, openQuickCapture: false, routeTab: tab);

  final int? eventId;
  final bool openQuickCapture;
  final String? routeTab;

  static NotificationTapEvent? fromPayload(String? payload) {
    if (payload == quickCapturePayload) {
      return const NotificationTapEvent.quickCapture();
    }
    if (payload != null && payload.startsWith('route:')) {
      final tab = payload.substring('route:'.length).trim();
      return tab.isEmpty ? null : NotificationTapEvent.route(tab);
    }
    if (payload == null || !payload.startsWith('event:')) return null;
    final id = int.tryParse(payload.substring('event:'.length));
    return id == null ? null : NotificationTapEvent.event(eventId: id);
  }

  static String toPayload(int eventId) => 'event:$eventId';
  static String routePayload(String tab) => 'route:$tab';

  static const quickCapturePayload = 'quick_capture';
}
