import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'data/weather_repository.dart';
import 'models/smart_advisory.dart';
import 'state/weather_controller.dart';

// ============================================================
// SmartAdvisoryState
// ============================================================

class SmartAdvisoryState {
  final SmartAdvisory? data;
  final bool loading;
  final String? error;
  final DateTime? lastFetchedAt;

  const SmartAdvisoryState({
    this.data,
    this.loading = false,
    this.error,
    this.lastFetchedAt,
  });

  SmartAdvisoryState copyWith({
    SmartAdvisory? data,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearData = false,
    DateTime? lastFetchedAt,
  }) {
    return SmartAdvisoryState(
      data: clearData ? null : (data ?? this.data),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }

  /// 数据超过 30 分钟视为过期
  bool get isStale {
    if (lastFetchedAt == null) return true;
    return DateTime.now().difference(lastFetchedAt!) >=
        const Duration(minutes: 30);
  }
}

// ============================================================
// SmartAdvisoryController
// ============================================================

class SmartAdvisoryController extends StateNotifier<SmartAdvisoryState> {
  final WeatherRepository _repository;
  Timer? _refreshTimer;

  SmartAdvisoryController(this._repository)
      : super(const SmartAdvisoryState()) {
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => loadAdvisory(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  /// 入口：带缓存判断。若数据未过期则跳过。
  Future<void> loadAdvisory() async {
    if (state.loading) return;
    if (state.lastFetchedAt != null && !state.isStale) return;
    await _doLoad();
  }

  /// 手动刷新：强制拉取最新数据。
  Future<void> manualRefresh() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    await _doLoad(forceRefresh: true);
  }

  Future<void> _doLoad({bool forceRefresh = false}) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      // 1. 位置权限
      final permission = await Geolocator.checkPermission();
      LocationPermission finalPermission = permission;
      if (permission == LocationPermission.denied) {
        finalPermission = await Geolocator.requestPermission();
      }
      if (finalPermission == LocationPermission.denied) {
        state = state.copyWith(
          loading: false,
          error: '需要位置权限才能获取天气建议',
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      final data = await _repository.fetchSmartAdvisory(
        lat: position.latitude,
        lon: position.longitude,
        forceRefresh: forceRefresh,
      );

      state = state.copyWith(
        data: data,
        loading: false,
        lastFetchedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: _formatAdvisoryError(e),
      );
    }
  }
}

String _formatAdvisoryError(Object e) {
  if (e is DioException) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return '登录态失效，请重新登录';
    if (statusCode != null && statusCode >= 500) {
      return '天气服务暂不可用 ($statusCode)';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '网络连接失败，请检查网络';
    }
    return '请求失败 (${statusCode ?? e.type.name})';
  }
  if (e is LocationServiceDisabledException) return '请开启手机定位服务';
  if (e.toString().contains('permission')) return '需要位置权限';
  return '获取天气建议失败: ${e.toString().split('\n').first}';
}

// ============================================================
// Provider
// ============================================================

final smartAdvisoryProvider =
    StateNotifierProvider<SmartAdvisoryController, SmartAdvisoryState>((ref) {
  final repository = ref.watch(weatherRepositoryProvider);
  return SmartAdvisoryController(repository);
});
