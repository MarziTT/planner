class BodyMeasurement {
  final DateTime measuredAt;
  final double weightKg;
  final double? bmi;
  final double? bodyFatPercent;
  final double? muscleMassKg;
  final double? bodyWaterPercent;
  final double? basalMetabolicRate;
  final double? visceralFatLevel;
  final String source;

  const BodyMeasurement({
    required this.measuredAt,
    required this.weightKg,
    this.bmi,
    this.bodyFatPercent,
    this.muscleMassKg,
    this.bodyWaterPercent,
    this.basalMetabolicRate,
    this.visceralFatLevel,
    this.source = 'huawei_health',
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      weightKg: (json['weightKg'] as num).toDouble(),
      bmi: _optionalDouble(json['bmi']),
      bodyFatPercent: _optionalDouble(json['bodyFatPercent']),
      muscleMassKg: _optionalDouble(json['muscleMassKg']),
      bodyWaterPercent: _optionalDouble(json['bodyWaterPercent']),
      basalMetabolicRate: _optionalDouble(json['basalMetabolicRate']),
      visceralFatLevel: _optionalDouble(json['visceralFatLevel']),
      source: json['source'] as String? ?? 'huawei_health',
    );
  }

  static double? _optionalDouble(Object? value) =>
      value == null ? null : (value as num).toDouble();
}
