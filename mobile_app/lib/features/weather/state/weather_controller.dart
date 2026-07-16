import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';
import '../data/weather_repository.dart';

// ============================================================
// 状态定义
// ============================================================

class WeatherState {
  final WeatherData? data;
  final bool loading;
  final String? error;

  const WeatherState({
    this.data,
    this.loading = false,
    this.error,
  });

  WeatherState copyWith({
    WeatherData? data,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearData = false,
  }) {
    return WeatherState(
      data: clearData ? null : (data ?? this.data),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================
// Provider
// ============================================================

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return WeatherRepository(dio);
});

final weatherControllerProvider =
    StateNotifierProvider<WeatherController, WeatherState>((ref) {
  final repository = ref.watch(weatherRepositoryProvider);
  return WeatherController(repository);
});

// ============================================================
// Controller
// ============================================================

class WeatherController extends StateNotifier<WeatherState> {
  final WeatherRepository _repository;

  WeatherController(this._repository) : super(const WeatherState());

  Future<void> loadWeather() async {
    if (state.loading) return;

    state = state.copyWith(loading: true, clearError: true);

    try {
      // 1. 获取位置权限
      final permission = await Geolocator.checkPermission();
      LocationPermission finalPermission = permission;
      if (permission == LocationPermission.denied) {
        finalPermission = await Geolocator.requestPermission();
      }
      if (finalPermission == LocationPermission.denied) {
        state = state.copyWith(
          loading: false,
          error: '需要位置权限才能获取天气信息',
        );
        return;
      }
      if (finalPermission == LocationPermission.deniedForever) {
        state = state.copyWith(
          loading: false,
          error: '位置权限已被禁止，请在系统设置中开启',
        );
        return;
      }

      // 2. 获取经纬度
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // 3. 调用 repository
      final data = await _repository.fetchWeather(
        lat: position.latitude,
        lon: position.longitude,
      );

      state = state.copyWith(data: data, loading: false);
    } catch (e) {
      final msg = _formatError(e);
      state = state.copyWith(loading: false, error: msg);
    }
  }
}

String _formatError(Object e) {
  if (e is DioException) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return '登录态失效，请重新登录';
    if (statusCode != null && statusCode >= 500) return '天气服务暂不可用 (${statusCode})';
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '网络连接失败，请检查网络';
    }
    return '请求失败 (${statusCode ?? e.type.name})';
  }
  if (e is LocationServiceDisabledException) return '请开启手机定位服务';
  if (e.toString().contains('permission')) return '需要位置权限';
  return '获取天气失败: ${e.toString().split('\n').first}';
}
