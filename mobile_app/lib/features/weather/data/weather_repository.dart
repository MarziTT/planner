import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/weather_models.dart';

// ============================================================
// WeatherRepository
// ============================================================

class WeatherRepository {
  final Dio _dio;

  WeatherRepository(this._dio);

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
}
