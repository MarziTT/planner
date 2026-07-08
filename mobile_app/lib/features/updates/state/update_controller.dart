import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/update_repository.dart';

class UpdateState {
  const UpdateState({
    this.info,
    this.lastActionMessage,
    this.lastPromptToken,
    this.checking = false,
  });

  final UpdateInfo? info;
  final String? lastActionMessage;
  final String? lastPromptToken;
  final bool checking;

  UpdateState copyWith({
    UpdateInfo? info,
    String? lastActionMessage,
    String? lastPromptToken,
    bool? checking,
    bool clearMessage = false,
  }) {
    return UpdateState(
      info: info ?? this.info,
      lastActionMessage: clearMessage ? null : lastActionMessage ?? this.lastActionMessage,
      lastPromptToken: lastPromptToken ?? this.lastPromptToken,
      checking: checking ?? this.checking,
    );
  }
}

class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._repository) : super(const UpdateState());

  final UpdateRepository _repository;

  Future<void> check() async {
    if (state.checking) return;
    state = state.copyWith(checking: true);
    try {
      final info = await _repository.checkVersion();
      state = state.copyWith(info: info, checking: false);
    } catch (_) {
      state = state.copyWith(checking: false);
    }
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

final updateControllerProvider = StateNotifierProvider<UpdateController, UpdateState>(
  (ref) => UpdateController(ref.watch(updateRepositoryProvider)),
);
