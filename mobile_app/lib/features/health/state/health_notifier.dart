import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_repository.dart';
import '../domain/health_models.dart';

/// Loading state for the health dashboard.
enum HealthLoadState { initial, loading, loaded, error }

class HealthState {
  final HealthLoadState loadState;
  final HealthTrends? trends;
  final String? errorMessage;

  const HealthState({
    this.loadState = HealthLoadState.initial,
    this.trends,
    this.errorMessage,
  });

  HealthState copyWith({
    HealthLoadState? loadState,
    HealthTrends? trends,
    String? errorMessage,
  }) {
    return HealthState(
      loadState: loadState ?? this.loadState,
      trends: trends ?? this.trends,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class HealthNotifier extends StateNotifier<HealthState> {
  final HealthRepository _repository;

  HealthNotifier(this._repository) : super(const HealthState());

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
}

final healthNotifierProvider =
    StateNotifierProvider<HealthNotifier, HealthState>((ref) {
  return HealthNotifier(ref.read(healthRepositoryProvider));
});
