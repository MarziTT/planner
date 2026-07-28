import 'package:flutter/services.dart';

/// Minimal Dart bridge for the native HarmonyOS notification implementation.
/// The native side can implement these methods without coupling the rest of
/// the app to a platform-specific notification plugin.
class HarmonyNotificationService {
  HarmonyNotificationService._();

  static final HarmonyNotificationService instance =
      HarmonyNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('pixelplanner/harmony_notifications');

  Future<void> ensureChannel({
    required String id,
    required String name,
    required String description,
    required String priority,
    required String category,
  }) async {
    await _channel.invokeMethod<void>('ensureChannel', {
      'id': id,
      'name': name,
      'description': description,
      'priority': priority,
      'category': category,
    });
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String priority,
    required String? payload,
    required DateTime? scheduledDate,
    required String category,
  }) async {
    await _channel.invokeMethod<void>('show', {
      'id': id,
      'title': title,
      'body': body,
      'channelId': channelId,
      'priority': priority,
      'payload': payload,
      'scheduledAt': scheduledDate?.millisecondsSinceEpoch,
      'category': category,
    });
  }

  Future<void> cancelAll() async {
    await _channel.invokeMethod<void>('cancelAll');
  }
}
