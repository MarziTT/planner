import 'package:dio/dio.dart';

import '../../../core/cache/local_cache_service.dart';
import '../models/exercise.dart';

/// 运动 API 服务
///
/// 封装所有运动相关后端 API 调���。
class ExerciseService {
  final Dio _dio;
  final LocalCacheService? _cache;

  ExerciseService({required Dio dio, LocalCacheService? cache})
      : _dio = dio,
        _cache = cache;

  // ---------------------------------------------------------------------------
  // 今日汇总
  // ---------------------------------------------------------------------------

  Future<DailyExerciseSummary?> getTodaySummary() async {
    try {
      final response = await _dio.get('/exercise/today');
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final summary = DailyExerciseSummary.fromJson(
            data['data'] as Map<String, dynamic>);
        _cache?.writeObject(
          key: CacheKeys.exerciseToday,
          json: data['data'] as Map<String, dynamic>,
        );
        return summary;
      }
    } on DioException {
      final cached = _cache?.readObject<DailyExerciseSummary>(
        key: CacheKeys.exerciseToday,
        fromJson: DailyExerciseSummary.fromJson,
      );
      if (cached != null) return cached;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 手动记录运动
  // ---------------------------------------------------------------------------

  Future<ExerciseRecord?> addRecord({
    required ExerciseType type,
    required int durationMinutes,
    int? calories,
    int? steps,
    DateTime? recordedAt,
  }) async {
    try {
      final response = await _dio.post(
        '/exercise/record',
        data: {
          'exercise_type': type.apiValue,
          'duration_minutes': durationMinutes,
          if (calories != null) 'calories': calories,
          if (steps != null) 'steps': steps,
          if (recordedAt != null) 'recorded_at': recordedAt.toIso8601String(),
          'source': 'manual',
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        return ExerciseRecord.fromJson(data['data'] as Map<String, dynamic>);
      }
    } on DioException {
      // fall through
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 自动记录（自主模式 sensor 来源）
  // ---------------------------------------------------------------------------

  Future<ExerciseRecord?> addAutoRecord({
    required ExerciseType type,
    required int durationMinutes,
    int? calories,
    int? steps,
    DateTime? recordedAt,
  }) async {
    try {
      final response = await _dio.post(
        '/exercise/record',
        data: {
          'exercise_type': type.apiValue,
          'duration_minutes': durationMinutes,
          if (calories != null) 'calories': calories,
          if (steps != null) 'steps': steps,
          if (recordedAt != null) 'recorded_at': recordedAt.toIso8601String(),
          'source': 'sensor',
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        return ExerciseRecord.fromJson(data['data'] as Map<String, dynamic>);
      }
    } on DioException {
      // fall through
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 运动模式
  // ---------------------------------------------------------------------------

  Future<ModeInfo?> getMode() async {
    try {
      final response = await _dio.get('/exercise/mode');
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final mode = ModeInfo.fromJson(data['data'] as Map<String, dynamic>);
        _cache?.writeObject(
          key: CacheKeys.exerciseMode,
          json: data['data'] as Map<String, dynamic>,
        );
        return mode;
      }
    } on DioException {
      final cached = _cache?.readObject<ModeInfo>(
        key: CacheKeys.exerciseMode,
        fromJson: ModeInfo.fromJson,
      );
      if (cached != null) return cached;
    }
    return null;
  }

  Future<ModeInfo?> switchMode(ExerciseMode mode, {DateTime? trainerEndDate}) async {
    try {
      final response = await _dio.put(
        '/exercise/mode',
        data: {
          'exercise_mode': mode.apiValue,
          if (trainerEndDate != null)
            'trainer_end_date': trainerEndDate.toIso8601String().split('T')[0],
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        return ModeInfo.fromJson(data['data'] as Map<String, dynamic>);
      }
    } on DioException {
      // fall through
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 历史记录
  // ---------------------------------------------------------------------------

  Future<List<ExerciseRecord>> getHistory({int days = 7}) async {
    try {
      final response = await _dio.get(
        '/exercise/history',
        queryParameters: {'days': days},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        final list = data['data']['records'] as List<dynamic>? ?? [];
        final records = list
            .map((e) => ExerciseRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache?.writeList(
          key: CacheKeys.exerciseHistory,
          items: records,
          toJson: _exRecordToJson,
        );
        return records;
      }
    } on DioException {
      final cached = _cache?.readList<ExerciseRecord>(
        key: CacheKeys.exerciseHistory,
        fromJson: ExerciseRecord.fromJson,
      );
      if (cached != null) return cached;
    }
    return [];
  }
}

Map<String, dynamic> _exRecordToJson(ExerciseRecord r) => {
      'id': r.id,
      'type': r.type.apiValue,
      'duration_minutes': r.durationMinutes,
      'calories': r.calories,
      'steps': r.steps,
      'recorded_at': r.recordedAt.toIso8601String(),
      'source': r.source,
    };
