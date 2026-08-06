import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/harmony_health_service.dart';
import '../data/health_repository.dart';
import '../domain/health_models.dart';

/// Loading state for the health dashboard.
enum HealthLoadState { initial, loading, loaded, error }

class HealthState {
  final HealthLoadState loadState;
  final HealthTrends? trends;
  final String? errorMessage;
  final HealthActivityReport? activityReport;
  final HealthAuthorizationStatus deviceHealthStatus;
  final bool deviceHealthLoading;
  final String? deviceHealthError;
  final String? deviceHealthDebugInfo;

  const HealthState({
    this.loadState = HealthLoadState.initial,
    this.trends,
    this.errorMessage,
    this.activityReport,
    this.deviceHealthStatus = HealthAuthorizationStatus.notDetermined,
    this.deviceHealthLoading = false,
    this.deviceHealthError,
    this.deviceHealthDebugInfo,
  });

  HealthState copyWith({
    HealthLoadState? loadState,
    HealthTrends? trends,
    String? errorMessage,
    HealthActivityReport? activityReport,
    HealthAuthorizationStatus? deviceHealthStatus,
    bool? deviceHealthLoading,
    String? deviceHealthError,
    String? deviceHealthDebugInfo,
    bool clearDeviceHealthError = false,
    bool clearDeviceHealthDebugInfo = false,
  }) {
    return HealthState(
      loadState: loadState ?? this.loadState,
      trends: trends ?? this.trends,
      errorMessage: errorMessage ?? this.errorMessage,
      activityReport: activityReport ?? this.activityReport,
      deviceHealthStatus: deviceHealthStatus ?? this.deviceHealthStatus,
      deviceHealthLoading: deviceHealthLoading ?? this.deviceHealthLoading,
      deviceHealthError: clearDeviceHealthError
          ? null
          : (deviceHealthError ?? this.deviceHealthError),
      deviceHealthDebugInfo: clearDeviceHealthDebugInfo
          ? null
          : (deviceHealthDebugInfo ?? this.deviceHealthDebugInfo),
    );
  }
}

class HealthNotifier extends StateNotifier<HealthState> {
  final HealthRepository _repository;
  final HarmonyHealthService _harmonyHealth;

  HealthNotifier(this._repository, this._harmonyHealth)
      : super(const HealthState());

  Future<void> load({int days = 7}) async {
    state = state.copyWith(loadState: HealthLoadState.loading);
    try {
      final trends = await _repository.fetchTrends(days: days);
      state = state.copyWith(
        loadState: HealthLoadState.loaded,
        trends: trends,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        loadState: HealthLoadState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> connectDeviceHealth() async {
    state = state.copyWith(
      deviceHealthLoading: true,
      clearDeviceHealthError: true,
      clearDeviceHealthDebugInfo: true,
    );
    try {
      final available = await _harmonyHealth.isAvailable();
      if (!available) {
        state = state.copyWith(
          deviceHealthStatus: HealthAuthorizationStatus.unavailable,
          deviceHealthLoading: false,
          deviceHealthError: '当前设备未提供鸿蒙健康服务',
          deviceHealthDebugInfo: 'isAvailable=false',
        );
        return;
      }
      final authorization =
          await _harmonyHealth.requestActivityAuthorizationDebug();
      final debug = await _harmonyHealth.readTodayActivityReportDebug();
      final report = debug.report;
      final debugInfo =
          'requestGranted=${authorization.granted}; requestStatus=${authorization.authorizationStatus.name}; requestError=${authorization.debugMessage ?? 'none'}; activityStatus=${debug.authorizationStatus.name}; readError=${debug.debugMessage ?? 'none'}';
      if (report == null) {
        state = state.copyWith(
          deviceHealthStatus: HealthAuthorizationStatus.denied,
          deviceHealthLoading: false,
          deviceHealthError: _formatDeviceHealthError(
            authorizationGranted: authorization.granted,
            readError: debug.debugMessage,
          ),
          deviceHealthDebugInfo: debugInfo,
        );
        return;
      }
      state = state.copyWith(
        activityReport: report,
        deviceHealthStatus: debug.authorizationStatus,
        deviceHealthLoading: false,
        deviceHealthDebugInfo: debugInfo,
      );
    } catch (error) {
      state = state.copyWith(
        deviceHealthLoading: false,
        deviceHealthError: '读取鸿蒙健康数据失败：$error',
        deviceHealthDebugInfo: 'unexpected=$error',
      );
    }
  }

  static String _formatDeviceHealthError({
    required bool authorizationGranted,
    required String? readError,
  }) {
    final errorText = readError ?? '';
    if (errorText.contains('DAILY_ACTIVITIES read permission')) {
      return 'PixelPlanner 缺少 DAILY_ACTIVITIES 读取权限。这不是手机授权问题，需要在华为开发者后台为 Health Service Kit 申请/启用“日常活动”读取 scope，生效后再同步。';
    }
    return authorizationGranted
        ? '已授权但暂时读不到运动健康数据。请打开华为运动健康 > 我的 > 隐私管理 > 数据分享与授权，确认 HUAWEI Health Kit / PixelPlanner 已开启后再同步。'
        : '请打开华为运动健康 > 我的 > 隐私管理 > 数据分享与授权，开启 HUAWEI Health Kit / PixelPlanner 授权后，再回到这里同步。';
  }
}

final healthNotifierProvider =
    StateNotifierProvider<HealthNotifier, HealthState>((ref) {
  return HealthNotifier(
    ref.read(healthRepositoryProvider),
    const HarmonyHealthService(),
  );
});
