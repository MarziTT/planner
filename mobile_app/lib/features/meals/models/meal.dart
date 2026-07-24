/// 餐食类型
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label {
    switch (this) {
      case MealType.breakfast:
        return '早餐';
      case MealType.lunch:
        return '午餐';
      case MealType.dinner:
        return '晚餐';
      case MealType.snack:
        return '加餐';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🍳';
      case MealType.lunch:
        return '🍱';
      case MealType.dinner:
        return '🍲';
      case MealType.snack:
        return '🍎';
    }
  }

  String get apiValue {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  /// 根据统一用餐时间推断餐食类型
  static MealType inferFromTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 6 && hour < 10) return MealType.breakfast;
    if (hour >= 11 && hour < 14) return MealType.lunch;
    if (hour >= 17 && hour < 20) return MealType.dinner;
    return MealType.snack;
  }

  static MealType fromApiValue(String value) {
    switch (value) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.snack;
    }
  }
}

/// 单项菜品
class MealItem {
  final String name;
  final int? calories;
  final String? category; // '主食', '蔬菜', '肉类', '水果', '饮料' 等

  const MealItem({
    required this.name,
    this.calories,
    this.category,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'] as String? ?? '',
      calories: json['calories'] as int?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (calories != null) 'calories': calories,
        if (category != null) 'category': category,
      };
}

/// 一餐饮食记录
class MealRecord {
  final int? id;
  final MealType type;
  final List<MealItem> items;
  final DateTime recordedAt;
  final String source; // 'photo' / 'manual' / 'popup'
  final String? imagePath;

  const MealRecord({
    this.id,
    required this.type,
    required this.items,
    required this.recordedAt,
    required this.source,
    this.imagePath,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MealRecord(
      id: json['id'] as int?,
      type: MealType.fromApiValue(json['meal_type'] as String? ?? 'snack'),
      items: itemsList,
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'] as String)
          : DateTime.now(),
      source: json['source'] as String? ?? 'manual',
    );
  }

  /// 总热量（千卡）
  int get totalCalories {
    return items.fold<int>(
      0,
      (sum, item) => sum + (item.calories ?? 0),
    );
  }

  /// 菜品名称列表，以「 + 」分隔
  String get itemsSummary {
    if (items.isEmpty) return '暂无记录';
    return items.map((e) => e.name).join(' + ');
  }

  String get formattedTime {
    return '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }
}

/// 今日饮食汇总
class DailyMealSummary {
  final DateTime date;
  final List<MealRecord> records;

  const DailyMealSummary({
    required this.date,
    required this.records,
  });

  /// 按餐食类型分组
  Map<MealType, MealRecord?> get byType {
    final map = <MealType, MealRecord?>{};
    for (final type in MealType.values) {
      map[type] = null;
    }
    for (final r in records) {
      map[r.type] = r;
    }
    return map;
  }

  /// 今日总热量
  int get totalCalories {
    return records.fold<int>(0, (sum, r) => sum + r.totalCalories);
  }

  /// 已记录的餐食数量
  int get recordedMeals => records.length;
}
