import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/settings_model.dart';

class SettingsState {
  const SettingsState({
    this.settings,
    this.loading = false,
    this.errorMessage,
  });

  final PlannerSettings? settings;
  final bool loading;
  final String? errorMessage;

  SettingsState copyWith({
    PlannerSettings? settings,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repository) : super(const SettingsState());

  final SettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final settings = await _repository.fetchSettings();
      state = SettingsState(settings: settings, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '设置加载失败');
    }
  }

  Future<void> save(PlannerSettings settings) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final saved = await _repository.saveSettings(settings);
      state = SettingsState(settings: saved, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '设置保存失败');
    }
  }

  Future<void> updateNotifications({
    required bool enabled,
    int? leadMinutes,
  }) async {
    final current = state.settings ?? PlannerSettings.fromJson(const {});
    await save(
      current.copyWith(
        notificationsEnabled: enabled,
        notificationsLeadMinutes:
            leadMinutes ?? current.notificationsLeadMinutes,
      ),
    );
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>(
  (ref) => SettingsController(ref.watch(settingsRepositoryProvider)),
);
