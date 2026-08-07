import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/memory_repository.dart';
import '../domain/personal_memory.dart';

class MemoryState {
  const MemoryState({
    this.learningEnabled = true,
    this.items = const [],
    this.loading = false,
    this.errorMessage,
  });

  final bool learningEnabled;
  final List<PersonalMemory> items;
  final bool loading;
  final String? errorMessage;

  MemoryState copyWith({
    bool? learningEnabled,
    List<PersonalMemory>? items,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      MemoryState(
        learningEnabled: learningEnabled ?? this.learningEnabled,
        items: items ?? this.items,
        loading: loading ?? this.loading,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class MemoryController extends StateNotifier<MemoryState> {
  MemoryController(this._repository) : super(const MemoryState());

  final MemoryRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snapshot = await _repository.load();
      state = MemoryState(
        learningEnabled: snapshot.learningEnabled,
        items: snapshot.items,
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '个人记忆加载失败');
    }
  }

  Future<void> setLearningEnabled(bool enabled) async {
    final previous = state.learningEnabled;
    state = state.copyWith(learningEnabled: enabled, clearError: true);
    try {
      await _repository.setLearningEnabled(enabled);
    } catch (_) {
      state = state.copyWith(
        learningEnabled: previous,
        errorMessage: '学习开关保存失败',
      );
    }
  }

  Future<void> setActive(PersonalMemory memory, bool active) async {
    try {
      final updated = await _repository.setActive(memory, active);
      state = state.copyWith(
        items: state.items
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: '记忆状态保存失败');
    }
  }

  Future<void> remove(int id) async {
    try {
      await _repository.delete(id);
      state = state.copyWith(
        items: state.items.where((item) => item.id != id).toList(),
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: '删除记忆失败');
    }
  }

  Future<bool> clear() async {
    try {
      await _repository.clear();
      state = state.copyWith(items: const [], clearError: true);
      return true;
    } catch (_) {
      state = state.copyWith(errorMessage: '清空记忆失败');
      return false;
    }
  }
}

final memoryControllerProvider =
    StateNotifierProvider<MemoryController, MemoryState>((ref) {
  return MemoryController(ref.watch(memoryRepositoryProvider));
});
