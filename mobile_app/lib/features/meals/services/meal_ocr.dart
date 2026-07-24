import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/cache/local_cache_service.dart';
import '../models/meal.dart';

/// 饮食 OCR 服务
///
/// 调起相机拍照 → 上传后端 OCR → 静默写入 meal_records → 返回结果。
/// 不弹确认框（乔布斯建议），OCR 失败时由调用方展示 snackbar。
class MealOcrService {
  final Dio _dio;
  final ImagePicker _picker = ImagePicker();
  final LocalCacheService? _cache;

  MealOcrService({required Dio dio, LocalCacheService? cache})
      : _dio = dio,
        _cache = cache;

  /// 拍照并 OCR 识别
  ///
  /// 返回识别到的菜品列表。如果 OCR 失败返回空列表。
  /// [mealTypeHint] 可选，用于指定餐食类型提示（如已知现在是午餐时间）。
  Future<OcrResult> captureAndRecognize({MealType? mealTypeHint}) async {
    // 1. 拍照
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile == null) {
      return OcrResult.cancelled();
    }

    final imageBytes = await File(xFile.path).readAsBytes();
    final imageBase64 = base64Encode(imageBytes);

    // 2. 上传后端 OCR
    try {
      final response = await _dio.post(
        '/meals/ocr',
        data: {
          'image_base64': imageBase64,
          if (mealTypeHint != null) 'meal_type': mealTypeHint.apiValue,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final recordData = data['data'] as Map<String, dynamic>;
        return OcrResult.success(
          record: MealRecord.fromJson(recordData),
          imagePath: xFile.path,
        );
      }

      return OcrResult.failed(
        reason: data['error']?['message'] as String? ?? '未知错误',
        imagePath: xFile.path,
      );
    } on DioException catch (e) {
      return OcrResult.failed(
        reason: e.message ?? '网络错误',
        imagePath: xFile.path,
      );
    }
  }

  /// 手动记录一餐
  Future<MealRecord?> addManual({
    required MealType mealType,
    required List<MealItem> items,
    DateTime? recordedAt,
  }) async {
    try {
      final response = await _dio.post(
        '/meals/manual',
        data: {
          'meal_type': mealType.apiValue,
          'items': items.map((e) => e.toJson()).toList(),
          if (recordedAt != null) 'recorded_at': recordedAt.toIso8601String(),
          'source': 'manual',
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        return MealRecord.fromJson(data['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException {
      return null;
    }
  }

  /// 获取今日饮食记录
  Future<List<MealRecord>> getTodayMeals() async {
    try {
      final response = await _dio.get('/meals/today');
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final list = data['data']['records'] as List<dynamic>? ?? [];
        final records = list
            .map((e) => MealRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache?.writeList(
          key: CacheKeys.mealsToday,
          items: records,
          toJson: _mealToJson,
        );
        return records;
      }
    } on DioException {
      final cached = _cache?.readList<MealRecord>(
        key: CacheKeys.mealsToday,
        fromJson: MealRecord.fromJson,
      );
      if (cached != null) return cached;
    }
    return [];
  }

  /// 获取饮食历史
  Future<List<MealRecord>> getHistory({int days = 7}) async {
    try {
      final response = await _dio.get('/meals/history', queryParameters: {'days': days});
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final list = data['data']['records'] as List<dynamic>? ?? [];
        final records = list
            .map((e) => MealRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache?.writeList(
          key: CacheKeys.mealsHistory,
          items: records,
          toJson: _mealToJson,
        );
        return records;
      }
    } on DioException {
      final cached = _cache?.readList<MealRecord>(
        key: CacheKeys.mealsHistory,
        fromJson: MealRecord.fromJson,
      );
      if (cached != null) return cached;
    }
    return [];
  }

  /// 获取每日汇总（含周均热量）
  Future<DailySummaryResponse?> getDailySummary() async {
    try {
      final response = await _dio.get('/meals/summary');
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final summary = DailySummaryResponse.fromJson(data['data'] as Map<String, dynamic>);
        _cache?.writeObject(
          key: CacheKeys.mealsSummary,
          json: _summaryToJson(summary),
        );
        return summary;
      }
    } on DioException {
      final cached = _cache?.readObject<DailySummaryResponse>(
        key: CacheKeys.mealsSummary,
        fromJson: DailySummaryResponse.fromJson,
      );
      if (cached != null) return cached;
    }
    return null;
  }
}

/// OCR 识别结果
class OcrResult {
  final bool isSuccess;
  final bool isCancelled;
  final MealRecord? record;
  final String? reason;
  final String? imagePath;

  const OcrResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.record,
    this.reason,
    this.imagePath,
  });

  factory OcrResult.success({
    required MealRecord record,
    String? imagePath,
  }) =>
      OcrResult._(
        isSuccess: true,
        isCancelled: false,
        record: record,
        imagePath: imagePath,
      );

  factory OcrResult.failed({String? reason, String? imagePath}) =>
      OcrResult._(
        isSuccess: false,
        isCancelled: false,
        reason: reason ?? '识别失败',
        imagePath: imagePath,
      );

  factory OcrResult.cancelled() =>
      OcrResult._(isSuccess: false, isCancelled: true);
}

/// 每日汇总响应
class DailySummaryResponse {
  final DateTime date;
  final int totalCalories;
  final double weeklyAvgCalories;
  final int mealCount;
  final Map<String, MealRecord?> byType;

  const DailySummaryResponse({
    required this.date,
    required this.totalCalories,
    required this.weeklyAvgCalories,
    required this.mealCount,
    required this.byType,
  });

  factory DailySummaryResponse.fromJson(Map<String, dynamic> json) {
    final byTypeRaw = json['by_type'] as Map<String, dynamic>? ?? {};
    final byType = <String, MealRecord?>{};
    for (final key in ['breakfast', 'lunch', 'dinner', 'snack']) {
      final val = byTypeRaw[key];
      byType[key] = val != null
          ? MealRecord.fromJson(val as Map<String, dynamic>)
          : null;
    }

    return DailySummaryResponse(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      totalCalories: json['total_calories'] as int? ?? 0,
      weeklyAvgCalories: (json['weekly_avg_calories'] as num?)?.toDouble() ?? 0,
      mealCount: json['meal_count'] as int? ?? 0,
      byType: byType,
    );
  }
}

// ---------------------------------------------------------------------------
// Cache serialization helpers (private)
// ---------------------------------------------------------------------------

Map<String, dynamic> _mealToJson(MealRecord m) => {
      if (m.id != null) 'id': m.id,
      'meal_type': m.type.apiValue,
      'items': m.items.map((i) => i.toJson()).toList(),
      'recorded_at': m.recordedAt.toIso8601String(),
      'source': m.source,
    };

Map<String, dynamic> _summaryToJson(DailySummaryResponse s) => {
      'date': s.date.toIso8601String().split('T')[0],
      'total_calories': s.totalCalories,
      'weekly_avg_calories': s.weeklyAvgCalories,
      'meal_count': s.mealCount,
      'by_type': s.byType.map((k, v) => MapEntry(k, v != null ? _mealToJson(v) : null)),
    };
