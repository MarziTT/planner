/// Health trends data models — P3-F2.
///
/// Mirrors the JSON returned by GET /api/v1/dashboard/health
library;

class HealthTrends {
  final PeriodInfo period;
  final ExerciseDomain exercise;
  final MealsDomain meals;
  final RoutineDomain routine;
  final StandingDomain standing;

  const HealthTrends({
    required this.period,
    required this.exercise,
    required this.meals,
    required this.routine,
    required this.standing,
  });

  factory HealthTrends.fromJson(Map<String, dynamic> json) {
    return HealthTrends(
      period: PeriodInfo.fromJson(json['period'] as Map<String, dynamic>),
      exercise: ExerciseDomain.fromJson(json['exercise'] as Map<String, dynamic>),
      meals: MealsDomain.fromJson(json['meals'] as Map<String, dynamic>),
      routine: RoutineDomain.fromJson(json['routine'] as Map<String, dynamic>),
      standing: StandingDomain.fromJson(json['standing'] as Map<String, dynamic>),
    );
  }
}

class PeriodInfo {
  final String start;
  final String end;
  final int days;

  const PeriodInfo({required this.start, required this.end, required this.days});

  factory PeriodInfo.fromJson(Map<String, dynamic> json) {
    return PeriodInfo(
      start: json['start'] as String,
      end: json['end'] as String,
      days: json['days'] as int,
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise
// ---------------------------------------------------------------------------

class ExerciseDomain {
  final List<ExerciseDaily> daily;
  final ExerciseSummary summary;

  const ExerciseDomain({required this.daily, required this.summary});

  factory ExerciseDomain.fromJson(Map<String, dynamic> json) {
    return ExerciseDomain(
      daily: (json['daily'] as List)
          .map((e) => ExerciseDaily.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: ExerciseSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class ExerciseDaily {
  final String date;
  final int totalMinutes;
  final int totalCalories;
  final int totalSteps;
  final int recordCount;

  const ExerciseDaily({
    required this.date,
    required this.totalMinutes,
    required this.totalCalories,
    required this.totalSteps,
    required this.recordCount,
  });

  factory ExerciseDaily.fromJson(Map<String, dynamic> json) {
    return ExerciseDaily(
      date: json['date'] as String,
      totalMinutes: json['total_minutes'] as int,
      totalCalories: json['total_calories'] as int,
      totalSteps: json['total_steps'] as int,
      recordCount: json['record_count'] as int,
    );
  }
}

class ExerciseSummary {
  final int totalMinutes;
  final int totalCalories;
  final int totalSteps;
  final int totalRecords;
  final double avgMinutes;
  final double avgCalories;
  final double avgSteps;
  final int activeDays;
  final int streak;

  const ExerciseSummary({
    required this.totalMinutes,
    required this.totalCalories,
    required this.totalSteps,
    required this.totalRecords,
    required this.avgMinutes,
    required this.avgCalories,
    required this.avgSteps,
    required this.activeDays,
    required this.streak,
  });

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) {
    return ExerciseSummary(
      totalMinutes: (json['total_minutes'] as num).toInt(),
      totalCalories: (json['total_calories'] as num).toInt(),
      totalSteps: (json['total_steps'] as num).toInt(),
      totalRecords: (json['total_records'] as num).toInt(),
      avgMinutes: (json['avg_minutes'] as num).toDouble(),
      avgCalories: (json['avg_calories'] as num).toDouble(),
      avgSteps: (json['avg_steps'] as num).toDouble(),
      activeDays: (json['active_days'] as num).toInt(),
      streak: (json['streak'] as num).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Meals
// ---------------------------------------------------------------------------

class MealsDomain {
  final List<MealsDaily> daily;
  final MealsSummary summary;

  const MealsDomain({required this.daily, required this.summary});

  factory MealsDomain.fromJson(Map<String, dynamic> json) {
    return MealsDomain(
      daily: (json['daily'] as List)
          .map((e) => MealsDaily.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: MealsSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class MealsDaily {
  final String date;
  final int totalCalories;
  final int mealCount;
  final int breakfast;
  final int lunch;
  final int dinner;
  final int snack;
  final double proteinG;
  final double carbG;
  final double fatG;

  const MealsDaily({
    required this.date,
    required this.totalCalories,
    required this.mealCount,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  factory MealsDaily.fromJson(Map<String, dynamic> json) {
    return MealsDaily(
      date: json['date'] as String,
      totalCalories: json['total_calories'] as int,
      mealCount: json['meal_count'] as int,
      breakfast: json['breakfast'] as int,
      lunch: json['lunch'] as int,
      dinner: json['dinner'] as int,
      snack: json['snack'] as int,
      proteinG: (json['protein_g'] as num).toDouble(),
      carbG: (json['carb_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
    );
  }
}

class MealsSummary {
  final int totalCalories;
  final int totalMeals;
  final double avgDailyCalories;
  final double avgMealCount;
  final int activeDays;
  final int streak;

  const MealsSummary({
    required this.totalCalories,
    required this.totalMeals,
    required this.avgDailyCalories,
    required this.avgMealCount,
    required this.activeDays,
    required this.streak,
  });

  factory MealsSummary.fromJson(Map<String, dynamic> json) {
    return MealsSummary(
      totalCalories: (json['total_calories'] as num).toInt(),
      totalMeals: (json['total_meals'] as num).toInt(),
      avgDailyCalories: (json['avg_daily_calories'] as num).toDouble(),
      avgMealCount: (json['avg_meal_count'] as num).toDouble(),
      activeDays: (json['active_days'] as num).toInt(),
      streak: (json['streak'] as num).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Routine / Sleep
// ---------------------------------------------------------------------------

class RoutineDomain {
  final List<RoutineDaily> daily;
  final RoutineSummary summary;

  const RoutineDomain({required this.daily, required this.summary});

  factory RoutineDomain.fromJson(Map<String, dynamic> json) {
    return RoutineDomain(
      daily: (json['daily'] as List)
          .map((e) => RoutineDaily.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: RoutineSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class RoutineDaily {
  final String date;
  final String wakeTime;
  final String wakeSource;
  final String sleepTime;
  final double sleepHours;

  const RoutineDaily({
    required this.date,
    required this.wakeTime,
    required this.wakeSource,
    required this.sleepTime,
    required this.sleepHours,
  });

  factory RoutineDaily.fromJson(Map<String, dynamic> json) {
    return RoutineDaily(
      date: json['date'] as String,
      wakeTime: json['wake_time'] as String,
      wakeSource: json['wake_source'] as String,
      sleepTime: json['sleep_time'] as String,
      sleepHours: (json['sleep_hours'] as num).toDouble(),
    );
  }
}

class RoutineSummary {
  final String avgWakeTime;
  final double avgSleepHours;
  final String defaultWakeTime;
  final int activeDays;

  const RoutineSummary({
    required this.avgWakeTime,
    required this.avgSleepHours,
    required this.defaultWakeTime,
    required this.activeDays,
  });

  factory RoutineSummary.fromJson(Map<String, dynamic> json) {
    return RoutineSummary(
      avgWakeTime: json['avg_wake_time'] as String,
      avgSleepHours: (json['avg_sleep_hours'] as num).toDouble(),
      defaultWakeTime: json['default_wake_time'] as String,
      activeDays: (json['active_days'] as num).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Standing
// ---------------------------------------------------------------------------

class StandingDomain {
  final List<StandingDaily> daily;
  final StandingSummary summary;

  const StandingDomain({required this.daily, required this.summary});

  factory StandingDomain.fromJson(Map<String, dynamic> json) {
    return StandingDomain(
      daily: (json['daily'] as List)
          .map((e) => StandingDaily.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: StandingSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}

class StandingDaily {
  final String date;
  final int total;
  final int completed;
  final int skipped;
  final double completionRate;

  const StandingDaily({
    required this.date,
    required this.total,
    required this.completed,
    required this.skipped,
    required this.completionRate,
  });

  factory StandingDaily.fromJson(Map<String, dynamic> json) {
    return StandingDaily(
      date: json['date'] as String,
      total: json['total'] as int,
      completed: json['completed'] as int,
      skipped: json['skipped'] as int,
      completionRate: (json['completion_rate'] as num).toDouble(),
    );
  }
}

class StandingSummary {
  final int total;
  final int completed;
  final int skipped;
  final double avgCompletionRate;
  final int activeDays;
  final int streak;

  const StandingSummary({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.avgCompletionRate,
    required this.activeDays,
    required this.streak,
  });

  factory StandingSummary.fromJson(Map<String, dynamic> json) {
    return StandingSummary(
      total: (json['total'] as num).toInt(),
      completed: (json['completed'] as num).toInt(),
      skipped: (json['skipped'] as num).toInt(),
      avgCompletionRate: (json['avg_completion_rate'] as num).toDouble(),
      activeDays: (json['active_days'] as num).toInt(),
      streak: (json['streak'] as num).toInt(),
    );
  }
}
