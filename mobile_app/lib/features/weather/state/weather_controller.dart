import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
  // 与 planner_repository 保持一致：通过 api_client 获取 dio 实例
  // 若项目中 api_client 暴露了 getDio() / ApiClient.instance.dio，请在此处替换。
  throw UnimplementedError(
    'weatherRepositoryProvider 需要注入 dio 实例，请参考 api_client.dart 的实现进行替换。',
  );
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
      if (finalPermission == LocationPermission.denied ||
          finalPermission == LocationPermission.deniedForever) {
        state = state.copyWith(
          loading: false,
          error: '需要位置权限才能获取天气信息',
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
      state = state.copyWith(
        loading: false,
        error: '获取天气失败，请稍后重试',
      );
    }
  }
}
