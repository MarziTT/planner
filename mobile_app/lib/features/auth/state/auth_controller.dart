import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

class AuthState {
  const AuthState({
    this.session,
    this.loading = false,
    this.restoring = true,
    this.errorMessage,
  });

  final AuthSession? session;
  final bool loading;
  final bool restoring;
  final String? errorMessage;

  AuthState copyWith({
    AuthSession? session,
    bool? loading,
    bool? restoring,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      session: session ?? this.session,
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    restore();
  }

  final AuthRepository _repository;

  Future<void> restore() async {
    try {
      final session = await _repository.restoreSession();
      state = AuthState(session: session, loading: false, restoring: false);
    } catch (_) {
      state = const AuthState(restoring: false);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, restoring: false, clearError: true);
    try {
      final session = await _repository.login(email: email, password: password);
      state = AuthState(session: session, loading: false, restoring: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: '登录失败，请检查账号或接口是否可用。',
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    state = state.copyWith(loading: true, restoring: false, clearError: true);
    try {
      final session = await _repository.register(
        email: email,
        password: password,
        nickname: nickname,
      );
      state = AuthState(session: session, loading: false, restoring: false);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: '注册失败，请检查邮箱是否已被使用。',
      );
    }
  }

  Future<void> logout() async {
    final refreshToken = state.session?.refreshToken;
    await _repository.logout(refreshToken);
    state = const AuthState(restoring: false);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
