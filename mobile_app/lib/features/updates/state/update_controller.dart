import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resource_cache.dart';
import '../data/update_repository.dart';

class UpdateState {
  const UpdateState({
    this.info,
    this.lastActionMessage,
    this.lastPromptToken,
    this.checking = false,
    this.resourceRevision = 0,
  });

  final UpdateInfo? info;
  final String? lastActionMessage;
  final String? lastPromptToken;
  final bool checking;
  final int resourceRevision;

  UpdateState copyWith({
    UpdateInfo? info,
    String? lastActionMessage,
    String? lastPromptToken,
    bool? checking,
    int? resourceRevision,
    bool clearMessage = false,
  }) {
    return UpdateState(
      info: info ?? this.info,
      lastActionMessage:
          clearMessage ? null : lastActionMessage ?? this.lastActionMessage,
      lastPromptToken: lastPromptToken ?? this.lastPromptToken,
      checking: checking ?? this.checking,
      resourceRevision: resourceRevision ?? this.resourceRevision,
    );
  }
}

class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._repository, this._resourceCache)
      : super(const UpdateState());

  final UpdateRepository _repository;
  final ResourceCache _resourceCache;

  Future<void> check() async {
    if (state.checking) return;
    state = state.copyWith(checking: true);
    try {
      final info = await _repository.checkVersion();
      if (info == null) {
        state = state.copyWith(checking: false);
        return;
      }

      final normalizedInfo = await _applyResourceSync(info);
      state = state.copyWith(
        info: normalizedInfo,
        checking: false,
      );
    } catch (_) {
      state = state.copyWith(checking: false);
    }
  }

  Future<void> applyResourceUpdateNow() async {
    final info = state.info;
    if (info == null || info.resources.isEmpty) {
      state = state.copyWith(lastActionMessage: '当前没有可同步的热更新资源。');
      return;
    }

    state = state.copyWith(checking: true);
    try {
      final normalizedInfo = await _applyResourceSync(info);
      state = state.copyWith(
        info: normalizedInfo,
        checking: false,
      );
    } catch (_) {
      state = state.copyWith(
        checking: false,
        lastActionMessage: '热更新资源同步失败，请检查网络后重试。',
      );
    }
  }

  Future<UpdateInfo> _applyResourceSync(UpdateInfo info) async {
    if (info.resources.isEmpty) {
      return info;
    }

    final result = await _resourceCache.syncResources(info.resources);
    var nextState = state;

    if (result.changedCount > 0) {
      nextState = nextState.copyWith(
        lastActionMessage: '主题资源已更新，页面会自动刷新显示新效果。',
        resourceRevision: nextState.resourceRevision + 1,
      );
    }

    if (result.failedCount == 0) {
      state = nextState;
      return info.copyWith(resources: const []);
    }

    nextState = nextState.copyWith(
      lastActionMessage: result.changedCount > 0
          ? '部分热更新资源同步失败，已先应用成功下载的资源。'
          : '热更新资源下载失败，请检查网络后重试。',
    );
    state = nextState;
    return info;
  }

  void announce(String message) {
    state = state.copyWith(lastActionMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  void markPromptShown(String token) {
    state = state.copyWith(lastPromptToken: token);
  }
}

final updateControllerProvider =
    StateNotifierProvider<UpdateController, UpdateState>(
  (ref) => UpdateController(
    ref.watch(updateRepositoryProvider),
    ref.watch(resourceCacheProvider),
  ),
);
