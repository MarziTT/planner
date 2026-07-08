import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.loading = false,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool loading;
  final String? errorMessage;

  ProfileState copyWith({
    UserProfile? profile,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = await _repository.fetchProfile();
      state = ProfileState(profile: profile, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '资料加载失败');
    }
  }

  Future<void> save(UserProfile profile) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final saved = await _repository.saveProfile(profile);
      state = ProfileState(profile: saved, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '资料保存失败');
    }
  }
}

final profileControllerProvider = StateNotifierProvider<ProfileController, ProfileState>(
  (ref) => ProfileController(ref.watch(profileRepositoryProvider)),
);
