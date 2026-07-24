/// 运动模式
enum ExerciseMode {
  self,
  trainer;

  String get label {
    switch (this) {
      case ExerciseMode.self:
        return '自主运动';
      case ExerciseMode.trainer:
        return '私教模式';
    }
  }

  String get apiValue {
    switch (this) {
      case ExerciseMode.self:
        return 'self';
      case ExerciseMode.trainer:
        return 'trainer';
    }
  }

  static ExerciseMode fromApiValue(String value) {
    switch (value) {
      case 'trainer':
        return ExerciseMode.trainer;
      default:
        return ExerciseMode.self;
    }
  }
}

/// 运动类型
enum ExerciseType {
  walking,
  running,
  cycling,
  swimming,
  strength,
  yoga,
  hiit,
  stretching,
  other;

  String get label {
    switch (this) {
      case ExerciseType.walking:
        return '步行';
      case ExerciseType.running:
        return '跑步';
      case ExerciseType.cycling:
        return '骑行';
      case ExerciseType.swimming:
        return '游泳';
      case ExerciseType.strength:
        return '力量训练';
      case ExerciseType.yoga:
        return '瑜伽';
      case ExerciseType.hiit:
        return 'HIIT';
      case ExerciseType.stretching:
        return '拉伸';
      case ExerciseType.other:
        return '其他';
    }
  }

  String get emoji {
    switch (this) {
      case ExerciseType.walking:
        return '🚶';
      case ExerciseType.running:
        return '🏃';
      case ExerciseType.cycling:
        return '🚴';
      case ExerciseType.swimming:
        return '🏊';
      case ExerciseType.strength:
        return '🏋️';
      case ExerciseType.yoga:
        return '🧘';
      case ExerciseType.hiit:
        return '⚡';
      case ExerciseType.stretching:
        return '🤸';
      case ExerciseType.other:
        return '🎯';
    }
  }

  String get apiValue {
    switch (this) {
      case ExerciseType.walking:
        return 'walking';
      case ExerciseType.running:
        return 'running';
      case ExerciseType.cycling:
        return 'cycling';
      case ExerciseType.swimming:
        return 'swimming';
      case ExerciseType.strength:
        return 'strength';
      case ExerciseType.yoga:
        return 'yoga';
      case ExerciseType.hiit:
        return 'hiit';
      case ExerciseType.stretching:
        return 'stretching';
      case ExerciseType.other:
        return 'other';
    }
  }

  static ExerciseType fromApiValue(String value) {
    switch (value) {
      case 'walking':
        return ExerciseType.walking;
      case 'running':
        return ExerciseType.running;
      case 'cycling':
        return ExerciseType.cycling;
      case 'swimming':
        return ExerciseType.swimming;
      case 'strength':
        return ExerciseType.strength;
      case 'yoga':
        return ExerciseType.yoga;
      case 'hiit':
        return ExerciseType.hiit;
      case 'stretching':
        return ExerciseType.stretching;
      default:
        return ExerciseType.other;
    }
  }

  /// 根据步数统计和 Activity 推断运动类型（自主模式用）
  static ExerciseType inferFromActivity({
    required String activityType,
    int? steps,
    int? durationMinutes,
  }) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return ExerciseType.walking;
      case 'running':
        return ExerciseType.running;
      case 'cycling':
      case 'on_bicycle':
        return ExerciseType.cycling;
      case 'swimming':
        return ExerciseType.swimming;
      default:
        // 步数 > 0 且无明确类型 → 步行
        if (steps != null && steps > 0) return ExerciseType.walking;
        return ExerciseType.other;
    }
  }
}

/// 单次运动记录
class ExerciseRecord {
  final int? id;
  final ExerciseType type;
  final int durationMinutes;
  final int? calories;
  final int? steps;
  final DateTime recordedAt;
  final String source; // 'sensor' / 'manual'

  const ExerciseRecord({
    this.id,
    required this.type,
    required this.durationMinutes,
    this.calories,
    this.steps,
    required this.recordedAt,
    required this.source,
  });

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      id: json['id'] as int?,
      type: ExerciseType.fromApiValue(json['exercise_type'] as String? ?? 'other'),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      calories: json['calories'] as int?,
      steps: json['steps'] as int?,
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'] as String)
          : DateTime.now(),
      source: json['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_type': type.apiValue,
        'duration_minutes': durationMinutes,
        if (calories != null) 'calories': calories,
        if (steps != null) 'steps': steps,
        'source': source,
      };

  String get formattedTime {
    return '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }
}

/// 每日运动汇总
class DailyExerciseSummary {
  final DateTime date;
  final int totalMinutes;
  final int totalCalories;
  final int totalSteps;
  final List<ExerciseRecord> records;

  const DailyExerciseSummary({
    required this.date,
    required this.totalMinutes,
    required this.totalCalories,
    required this.totalSteps,
    required this.records,
  });

  factory DailyExerciseSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['records'] as List<dynamic>?)
            ?.map((e) => ExerciseRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return DailyExerciseSummary(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      totalMinutes: json['total_minutes'] as int? ?? 0,
      totalCalories: json['total_calories'] as int? ?? 0,
      totalSteps: json['total_steps'] as int? ?? 0,
      records: list,
    );
  }
}

/// 模式切换响应
class ModeInfo {
  final ExerciseMode mode;
  final DateTime? trainerEndDate;

  const ModeInfo({
    required this.mode,
    this.trainerEndDate,
  });

  factory ModeInfo.fromJson(Map<String, dynamic> json) {
    return ModeInfo(
      mode: ExerciseMode.fromApiValue(json['exercise_mode'] as String? ?? 'self'),
      trainerEndDate: json['trainer_end_date'] != null
          ? DateTime.parse(json['trainer_end_date'] as String)
          : null,
    );
  }
}
