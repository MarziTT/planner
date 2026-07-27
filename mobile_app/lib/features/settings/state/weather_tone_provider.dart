import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

// ============================================================
// 预设语气模板
// ============================================================

class WeatherTonePreset {
  final String name;
  final String prompt;

  const WeatherTonePreset({required this.name, required this.prompt});
}

const weatherTonePresets = [
  WeatherTonePreset(
    name: '温暖管家',
    prompt:
        '用"你"称呼用户，语气温暖贴心，像家人一样关心。建议代替播报，用"建议你""记得""别忘了一类表达。适当使用语气词（呢、哦、呀），让用户感到被照顾。',
  ),
  WeatherTonePreset(
    name: 'Zero 式',
    prompt:
        '极简冷峻。每次最多两句话，不寒暄不问候不感叹。中英夹杂，英文关键词用原词不翻译。关心在行动里不在嘴上。只在极端危险时多给一句话。',
  ),
];

// ============================================================
// WeatherToneState
// ============================================================

class WeatherToneState {
  final String tone;
  final bool loading;
  final bool saving;
  final String? error;

  const WeatherToneState({
    this.tone = '',
    this.loading = false,
    this.saving = false,
    this.error,
  });

  WeatherToneState copyWith({
    String? tone,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return WeatherToneState(
      tone: tone ?? this.tone,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================
// WeatherToneController
// ============================================================

class WeatherToneController extends StateNotifier<WeatherToneState> {
  final Dio _dio;

  WeatherToneController(this._dio) : super(const WeatherToneState());

  /// 加载当前保存的语气
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/settings/weather-tone');
      final data = response.data;
      final tone = data['data']?['weather_tone'] as String? ?? '';
      state = WeatherToneState(tone: tone, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 保存语气
  Future<bool> save(String tone) async {
    if (state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _dio.put('/settings/weather-tone', data: {'weather_tone': tone});
      state = WeatherToneState(tone: tone, saving: false);
      return true;
    } catch (_) {
      state = state.copyWith(saving: false, error: '保存失败，请重试');
      return false;
    }
  }

  /// 恢复默认（清空）
  Future<bool> resetToDefault() async {
    if (state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _dio.put('/settings/weather-tone', data: {'weather_tone': ''});
      state = const WeatherToneState(tone: '', saving: false);
      return true;
    } catch (_) {
      state = state.copyWith(saving: false, error: '恢复默认失败，请重试');
      return false;
    }
  }

  /// 本地更新（不调 API），用于模板点击时即时填入文本框
  void updateLocal(String tone) {
    state = state.copyWith(tone: tone);
  }
}

// ============================================================
// Provider
// ============================================================

final weatherToneProvider =
    StateNotifierProvider<WeatherToneController, WeatherToneState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return WeatherToneController(dio);
});
