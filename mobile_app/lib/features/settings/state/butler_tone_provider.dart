import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

// ============================================================
// 预设语气模板
// ============================================================

class ButlerTonePreset {
  final String name;
  final String prompt;

  const ButlerTonePreset({required this.name, required this.prompt});
}

const butlerTonePresets = [
  ButlerTonePreset(
    name: '温暖管家',
    prompt:
        '用"你"称呼用户，语气温暖贴心，像家人一样关心。建议代替播报，用"建议你""记得""别忘了一类表达。适当使用语气词（呢、哦、呀），让用户感到被照顾。',
  ),
  ButlerTonePreset(
    name: 'Zero 式',
    prompt: '极简冷峻。每次最多两句话，不寒暄不问候不感叹。中英夹杂，英文关键词用原词不翻译。关心在行动里不在嘴上。只在极端危险时多给一句话。',
  ),
];

// ============================================================
// ButlerToneState
// ============================================================

class ButlerToneState {
  final String tone;
  final bool loading;
  final bool saving;
  final String? error;

  const ButlerToneState({
    this.tone = '',
    this.loading = false,
    this.saving = false,
    this.error,
  });

  ButlerToneState copyWith({
    String? tone,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return ButlerToneState(
      tone: tone ?? this.tone,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================
// ButlerToneController
// ============================================================

class ButlerToneController extends StateNotifier<ButlerToneState> {
  final Dio _dio;

  ButlerToneController(this._dio) : super(const ButlerToneState());

  /// 加载当前保存的语气
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await _dio.get('/settings/butler-tone');
      final data = response.data;
      final tone = data['data']?['butler_tone'] as String? ?? '';
      state = ButlerToneState(tone: tone, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 保存语气
  Future<bool> save(String tone) async {
    if (state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _dio.put('/settings/butler-tone', data: {'butler_tone': tone});
      state = ButlerToneState(tone: tone, saving: false);
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
      await _dio.put('/settings/butler-tone', data: {'butler_tone': ''});
      state = const ButlerToneState(tone: '', saving: false);
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

final butlerToneProvider =
    StateNotifierProvider<ButlerToneController, ButlerToneState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ButlerToneController(dio);
});
