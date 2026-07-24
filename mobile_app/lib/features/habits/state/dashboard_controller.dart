import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> load({double? lat, double? lon}) async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.fetchOverview(lat: lat, lon: lon);
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
