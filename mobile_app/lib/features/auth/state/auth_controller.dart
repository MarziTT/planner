import 'package:dio/dio.dart';
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
    } catch (e) {
      final msg = e is DioException
          ? '登录失败：${_dioErrorMsg(e)}'
          : '登录失败：$e';
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: msg,
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
    } catch (e) {
      final msg = e is DioException
          ? '注册失败：${_dioErrorMsg(e)}'
          : '注册失败：$e';
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: msg,
      );
    }
  }

  static String _dioErrorMsg(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '响应超时';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      case DioExceptionType.badResponse:
        final msg = e.response?.data?['error']?['message'] ?? e.message;
        return '服务器错误：$msg';
      default:
        return e.message ?? '未知网络错误';
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
