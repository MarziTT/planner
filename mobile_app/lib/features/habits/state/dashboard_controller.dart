import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/device/harmony_device_permissions.dart';
import '../../../../core/network/api_client.dart';
import '../models/dashboard.dart';

// ============================================================
// Providers
// ============================================================

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DashboardService(dio: dio);
});

final dashboardLoadingProvider = StateProvider<bool>((ref) => false);

// ============================================================
// Controller (supports manual refresh)
// ============================================================

class DashboardController extends StateNotifier<AsyncValue<DashboardData?>> {
  final DashboardService _service;

  DashboardController(this._service) : super(const AsyncValue.loading()) {
    load();
  }

  /// 加载仪表盘数据。自动尝试获取位置以提供天气数据。
  Future<void> load({double? lat, double? lon}) async {
    state = const AsyncValue.loading();

    double? resolvedLat = lat;
    double? resolvedLon = lon;

    // 调用方未传坐标时，尝试获取本地位置
    if (resolvedLat == null || resolvedLon == null) {
      try {
        final position = await const HarmonyDevicePermissions()
            .getCurrentLocation()
            .timeout(const Duration(seconds: 5));
        resolvedLat = position.latitude;
        resolvedLon = position.longitude;
      } on TimeoutException {
        // GPS 超时，不带坐标请求
      } catch (_) {
        // 其他位置错误，不带坐标请求
      }
    }

    try {
      final data = await _service.fetchOverview(
        lat: resolvedLat,
        lon: resolvedLon,
      );
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, AsyncValue<DashboardData?>>(
        (ref) {
  final service = ref.watch(dashboardServiceProvider);
  return DashboardController(service);
});
