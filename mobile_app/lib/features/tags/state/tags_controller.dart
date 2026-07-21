import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tags_repository.dart';
import '../domain/tag_model.dart';

class TagsState {
  const TagsState({
    this.tags = const [],
    this.loading = false,
    this.errorMessage,
  });

  final List<PlannerTag> tags;
  final bool loading;
  final String? errorMessage;

  TagsState copyWith({
    List<PlannerTag>? tags,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TagsState(
      tags: tags ?? this.tags,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TagsController extends StateNotifier<TagsState> {
  TagsController(this._repository) : super(const TagsState()) {
    load();
  }

  final TagsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final tags = await _repository.fetchTags();
      state = TagsState(tags: tags, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '标签加载失败');
    }
  }

  Future<void> create(String name, String color, {bool isRecurring = false, String recurrenceRule = ''}) async {
    try {
      final tag = await _repository.createTag(
        name: name,
        color: color,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule,
      );
      state = state.copyWith(tags: [...state.tags, tag], clearError: true);
    } catch (_) {
      state = state.copyWith(errorMessage: '新增标签失败');
    }
  }

  Future<void> update(PlannerTag tag, String name, String color, {bool? isRecurring, String? recurrenceRule}) async {
    try {
      final updated = await _repository.updateTag(
        tag,
        name: name,
        color: color,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule,
      );
      state = state.copyWith(
        tags: state.tags.map((item) => item.id == updated.id ? updated : item).toList(),
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: '编辑标签失败');
    }
  }

  Future<void> remove(int id) async {
    try {
      await _repository.deleteTag(id);
      state = state.copyWith(tags: state.tags.where((item) => item.id != id).toList(), clearError: true);
    } catch (_) {
      state = state.copyWith(errorMessage: '删除标签失败');
    }
  }
}

final tagsControllerProvider = StateNotifierProvider<TagsController, TagsState>(
  (ref) => TagsController(ref.watch(tagsRepositoryProvider)),
);
