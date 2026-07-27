import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/cache/local_cache_service.dart';
import '../domain/weather_models.dart';
import '../models/smart_advisory.dart';

// ============================================================
// WeatherRepository
// ============================================================

class WeatherRepository {
  final Dio _dio;
  final LocalCacheService? _cache;

  WeatherRepository(this._dio, {LocalCacheService? cache}) : _cache = cache;

  /// 调用后端 /api/v1/weather/ GET 端点
  Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/weather/',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
        },
      );

      if (response.data == null) {
        throw Exception('Weather API returned null data');
      }

      final wrapper = response.data!;
      if (wrapper['data'] == null) {
        throw Exception('Weather API returned null data field');
      }

      return WeatherData.fromJson(wrapper['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('WeatherRepository.fetchWeather DioException: ${e.message}');
      rethrow;
    }
  }

  /// ===============================================================
  /// Smart Advisory API (天气智能管家)
  /// ===============================================================

  static const _advisoryCacheKey = 'cache:weather:smart_advisory';
  static const _advisoryCacheTsKey = 'cache:weather:smart_advisory:ts';
  static const _cacheTtlSeconds = 30 * 60; // 30 分钟

  /// 调用 GET /api/v1/weather/smart-advisory
  ///
  /// 返回 [SmartAdvisory] 数据。优先使用缓存（30 分钟 TTL），
  /// 缓存过期或不存在时发起网络请求并回写缓存。
  Future<SmartAdvisory> fetchSmartAdvisory({
    required double lat,
    required double lon,
    String? date,
    bool forceRefresh = false,
  }) async {
    // 尝试读缓存
    if (!forceRefresh && _cache != null) {
      final cached = _readCachedAdvisory();
      if (cached != null) return cached;
    }

    try {
      final queryParams = <String, dynamic>{
        'lat': lat.toString(),
        'lon': lon.toString(),
      };
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '/weather/smart-advisory',
        queryParameters: queryParams,
      );

      if (response.data == null) {
        throw Exception('Smart advisory API returned null');
      }

      final advisory = SmartAdvisory.fromJson(response.data!);
      _writeCachedAdvisory(advisory);
      return advisory;
    } on DioException catch (e) {
      debugPrint(
          'WeatherRepository.fetchSmartAdvisory DioException: ${e.message}');
      // Fallback to stale cache on network error
      final stale = _readCachedAdvisory(ignoreTtl: true);
      if (stale != null) return stale;
      rethrow;
    }
  }

  SmartAdvisory? _readCachedAdvisory({bool ignoreTtl = false}) {
    if (_cache == null) return null;
    if (!ignoreTtl) {
      final tsRaw = _cache!.readRaw(_advisoryCacheTsKey);
      if (tsRaw == null) return null;
      final ts = int.tryParse(tsRaw);
      if (ts == null ||
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - ts >=
              _cacheTtlSeconds) {
        return null;
      }
    }
    return _cache!.readObject<SmartAdvisory>(
      key: _advisoryCacheKey,
      fromJson: (json) => SmartAdvisory.fromJson(json),
    );
  }

  void _writeCachedAdvisory(SmartAdvisory advisory) {
    _cache?.writeObject(
      key: _advisoryCacheKey,
      json: advisory.toJson(),
    );
    _cache?.writeRaw(
      _advisoryCacheTsKey,
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    );
  }
}
