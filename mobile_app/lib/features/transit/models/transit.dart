/// Transit data models for Jarvis Agent Phase 2.
///
/// Spec: §6 出行模块 — 高铁票 OCR + 地铁路线 + 提醒链

class TransitTrip {
  final String tripId;
  final String trainNumber; // 车次，如 G1234
  final DateTime departureDate;
  final String departureStation;
  final String arrivalStation;
  final String? carriage; // 车厢号
  final String? seatNumber; // 座位号
  final String? departureTime; // HH:MM
  final String? ticketImagePath;

  const TransitTrip({
    required this.tripId,
    required this.trainNumber,
    required this.departureDate,
    required this.departureStation,
    required this.arrivalStation,
    this.carriage,
    this.seatNumber,
    this.departureTime,
    this.ticketImagePath,
  });

  factory TransitTrip.fromJson(Map<String, dynamic> json) {
    return TransitTrip(
      tripId: json['trip_id'] as String? ?? '',
      trainNumber: json['train_number'] as String? ?? '',
      departureDate: DateTime.tryParse(json['departure_date'] as String? ?? '') ?? DateTime.now(),
      departureStation: json['departure_station'] as String? ?? '',
      arrivalStation: json['arrival_station'] as String? ?? '',
      carriage: json['carriage'] as String?,
      seatNumber: json['seat_number'] as String?,
      departureTime: json['departure_time'] as String?,
      ticketImagePath: json['ticket_image_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'train_number': trainNumber,
    'departure_date': departureDate.toIso8601String().split('T').first,
    'departure_station': departureStation,
    'arrival_station': arrivalStation,
    'carriage': carriage,
    'seat_number': seatNumber,
    'departure_time': departureTime,
    'ticket_image_path': ticketImagePath,
  };

  TransitTrip copyWith({
    String? tripId,
    String? trainNumber,
    DateTime? departureDate,
    String? departureStation,
    String? arrivalStation,
    String? carriage,
    String? seatNumber,
    String? departureTime,
    String? ticketImagePath,
  }) {
    return TransitTrip(
      tripId: tripId ?? this.tripId,
      trainNumber: trainNumber ?? this.trainNumber,
      departureDate: departureDate ?? this.departureDate,
      departureStation: departureStation ?? this.departureStation,
      arrivalStation: arrivalStation ?? this.arrivalStation,
      carriage: carriage ?? this.carriage,
      seatNumber: seatNumber ?? this.seatNumber,
      departureTime: departureTime ?? this.departureTime,
      ticketImagePath: ticketImagePath ?? this.ticketImagePath,
    );
  }
}

class TransitRoute {
  final String fromStation;
  final String toStation;
  final String startTime;
  final String endTime;
  final String durationMinutes;
  final List<String> transferStations;
  final int totalWalkingMeters;
  final List<TransitRouteLeg> legs;

  const TransitRoute({
    required this.fromStation,
    required this.toStation,
    this.startTime = '',
    this.endTime = '',
    this.durationMinutes = '0',
    this.transferStations = const [],
    this.totalWalkingMeters = 0,
    this.legs = const [],
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      fromStation: json['from_station'] as String? ?? '',
      toStation: json['to_station'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] ?? 0).toString(),
      transferStations: (json['transfer_stations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalWalkingMeters: json['total_walking_meters'] as int? ?? 0,
      legs: (json['legs'] as List<dynamic>?)
              ?.map((e) => TransitRouteLeg.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TransitRouteLeg {
  final String fromStation;
  final String toStation;
  final String line;
  final int minutes;

  const TransitRouteLeg({
    required this.fromStation,
    required this.toStation,
    required this.line,
    required this.minutes,
  });

  factory TransitRouteLeg.fromJson(Map<String, dynamic> json) {
    return TransitRouteLeg(
      fromStation: json['from_station'] as String? ?? '',
      toStation: json['to_station'] as String? ?? '',
      line: json['line'] as String? ?? '',
      minutes: json['minutes'] as int? ?? 0,
    );
  }
}

class ReminderTimeline {
  final TransitTrip trip;
  final List<ReminderNode> nodes;

  const ReminderTimeline({required this.trip, required this.nodes});
}

class ReminderNode {
  final String label; // "出发前 2 小时"
  final int minutesBefore; // 120
  final bool passed;

  const ReminderNode({
    required this.label,
    required this.minutesBefore,
    this.passed = false,
  });

  // Predefined reminder stages
  static const List<({String label, int minutes})> stages = [
    (label: '出发前 2 小时 — 准备行李', minutes: 120),
    (label: '出发前 1 小时 — 准备出发', minutes: 60),
    (label: '出发前 30 分钟 — 紧急提醒', minutes: 30),
  ];

  /// Build timeline from a departure datetime.
  static ReminderTimeline build(TransitTrip trip, DateTime now) {
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

    final nodes = <ReminderNode>[];
    for (final stage in stages) {
      final reminderTime = departure.subtract(Duration(minutes: stage.minutes));
      nodes.add(ReminderNode(
        label: stage.label,
        minutesBefore: stage.minutes,
        passed: now.isAfter(reminderTime),
      ));
    }

    return ReminderTimeline(trip: trip, nodes: nodes);
  }
}
