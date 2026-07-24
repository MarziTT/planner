import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/smart_notify_repository.dart';
import '../domain/smart_notify_models.dart';

/// State for the smart notification feature.
class SmartNotifyState {
  final bool isLoadingInsights;
  final bool isLoadingHistory;
  final InsightsResult? insights;
  final NotifyHistoryResult? history;
  final String? errorMessage;

  const SmartNotifyState({
    this.isLoadingInsights = false,
    this.isLoadingHistory = false,
    this.insights,
    this.history,
    this.errorMessage,
  });

  SmartNotifyState copyWith({
    bool? isLoadingInsights,
    bool? isLoadingHistory,
    InsightsResult? insights,
    NotifyHistoryResult? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SmartNotifyState(
      isLoadingInsights: isLoadingInsights ?? this.isLoadingInsights,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      insights: insights ?? this.insights,
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SmartNotifyNotifier extends StateNotifier<SmartNotifyState> {
  SmartNotifyNotifier(this._repo) : super(const SmartNotifyState());

  final SmartNotifyRepository _repo;

  Future<void> loadInsights() async {
    state = state.copyWith(isLoadingInsights: true, clearError: true);
    try {
      final insights = await _repo.fetchInsights();
      state = state.copyWith(isLoadingInsights: false, insights: insights);
    } catch (e) {
      state = state.copyWith(
        isLoadingInsights: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadHistory({String? notifyType, int days = 7}) async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final history = await _repo.fetchHistory(
        notifyType: notifyType,
        days: days,
      );
      state = state.copyWith(isLoadingHistory: false, history: history);
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await Future.wait([loadInsights(), loadHistory()]);
  }
}

final smartNotifyProvider =
    StateNotifierProvider<SmartNotifyNotifier, SmartNotifyState>((ref) {
  final repo = ref.watch(smartNotifyRepoProvider);
  return SmartNotifyNotifier(repo);
});
