/// Reminder chain service — generates and schedules a cascade of reminders
/// for a transit trip.
///
/// Spec: §6.6 — 提醒链
///
/// Timeline (from departure time):
///   1. 出发前 2 小时 — "准备行李" (priority: important)
///   2. 出发前 1 小时 — "准备出发" (priority: urgent)
///   3. 出发前 30 分钟 — "紧急提醒" (priority: urgent)
///   4. 上车后 — "预计到站时间" (not implemented via notification;
///      destination reminder is shown in the transit page)

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../habits/notify_manager.dart';
import '../models/transit.dart';

class ReminderChainService {
  /// Schedule all reminder notifications for a trip.
  ///
  /// Returns the list of [ReminderNode] for UI display.
  static List<ReminderNode> schedule(TransitTrip trip) {
    final now = DateTime.now();

    // Combine departureDate + departureTime
    DateTime departure;
    if (trip.departureTime != null && trip.departureTime!.isNotEmpty) {
      final parts = trip.departureTime!.split(':');
      departure = DateTime(
        trip.departureDate.year,
        trip.departureDate.month,
        trip.departureDate.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    } else {
      departure = trip.departureDate;
    }

    final stages = <_ReminderStage>[
      _ReminderStage(
        label: '准备行李',
        minutesBefore: 120,
        priority: NotifyPriority.important,
        body: '${trip.trainNumber} 次列车将于 ${_fmtTime(departure)} 出发，可以开始整理行李了。',
      ),
      _ReminderStage(
        label: '准备出发',
        minutesBefore: 60,
        priority: NotifyPriority.urgent,
        body: '距离 ${trip.trainNumber} 发车还有 1 小时，建议现在出发前往 ${trip.departureStation}。',
      ),
      _ReminderStage(
        label: '紧急提醒',
        minutesBefore: 30,
        priority: NotifyPriority.urgent,
        body: '${trip.trainNumber} 还有 30 分钟发车！请立即前往 ${trip.departureStation} 检票口。',
      ),
    ];

    final nodes = <ReminderNode>[];

    for (final stage in stages) {
      final reminderTime = departure.subtract(Duration(minutes: stage.minutesBefore));
      final passed = now.isAfter(reminderTime);

      nodes.add(ReminderNode(
        label: '出发前 ${_fmtMinutes(stage.minutesBefore)} — ${stage.label}',
        minutesBefore: stage.minutesBefore,
        passed: passed,
      ));

      // Only schedule future reminders
      if (!passed && reminderTime.isAfter(now)) {
        final title = '${trip.trainNumber} ${stage.label}';
        final payload = NotifyPayload(
          eventType: 'transit',
          channelId: NotifyChannel.transit.id,
        );

        NotifyManager.show(
          channel: NotifyChannel.transit,
          title: title,
          body: stage.body,
          priority: stage.priority,
          payload: payload,
          scheduledDate: reminderTime,
          notificationId: _notificationId(trip, stage.minutesBefore),
        );
      }
    }

    return nodes;
  }

  /// Cancel all scheduled reminders for a trip.
  static Future<void> cancel(TransitTrip trip) async {
    const stages = [120, 60, 30];
    for (final minutes in stages) {
      await NotifyManager.plugin.cancel(_notificationId(trip, minutes));
    }
  }

  static int _notificationId(TransitTrip trip, int minutesBefore) {
    return (trip.tripId.hashCode ^ minutesBefore).abs();
  }

  static String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtMinutes(int m) {
    if (m >= 60 && m % 60 == 0) return '${m ~/ 60} 小时';
    if (m >= 60) return '${m ~/ 60} 小时 ${m % 60} 分钟';
    return '$m 分钟';
  }
}

class _ReminderStage {
  final String label;
  final int minutesBefore;
  final NotifyPriority priority;
  final String body;

  const _ReminderStage({
    required this.label,
    required this.minutesBefore,
    required this.priority,
    required this.body,
  });
}
