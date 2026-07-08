import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/settings_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  Future<PlannerSettings> fetchSettings() async {
    final response = await _dio.get('/settings');
    return PlannerSettings.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<PlannerSettings> saveSettings(PlannerSettings settings) async {
    final response = await _dio.put('/settings', data: settings.toJson());
    return PlannerSettings.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }
}
