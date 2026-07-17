import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_planner_mobile/core/storage/secure_token_storage.dart';

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
  AuthController(this._repository, this._tokenStorage)
      : super(const AuthState()) {
    restore();
    _tokenStorage.invalidateNotifier.addListener(_onTokensCleared);
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  void _onTokensCleared() {
    if (state.session != null) {
      state = const AuthState(restoring: false);
    }
  }

  @override
  void dispose() {
    _tokenStorage.invalidateNotifier.removeListener(_onTokensCleared);
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final session = await _repository.restoreSession();
      state = AuthState(session: session, loading: false, restoring: false);
    } catch (_) {
      state = const AuthState(restoring: false);
    }
  }

  Future<void> sendCode({required String phone}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repository.sendCode(phone: phone);
      state = state.copyWith(loading: false, restoring: false);
    } catch (e) {
      final msg = e is DioException ? '发送失败：${_dioErrorMsg(e)}' : '发送失败：$e';
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: msg,
      );
    }
  }

  Future<void> loginWithPhone({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(loading: true, restoring: false, clearError: true);
    try {
      final session = await _repository.loginWithPhone(
        phone: phone,
        code: code,
      );
      await _tokenStorage.savePhoneNumber(phone);
      state = AuthState(session: session, loading: false, restoring: false);
    } catch (e) {
      final msg = e is DioException ? '登录失败：${_dioErrorMsg(e)}' : '登录失败：$e';
      state = state.copyWith(
        loading: false,
        restoring: false,
        errorMessage: msg,
      );
    }
  }

  Future<void> completeOnboarding() async {
    final session = state.session;
    if (session == null || session.user.onboardingDone) {
      return;
    }
    final updatedSession = session.copyWith(
      user: session.user.copyWith(onboardingDone: true),
    );
    await _repository.persistSession(updatedSession);
    state = state.copyWith(
      session: updatedSession,
      loading: false,
      restoring: false,
      clearError: true,
    );
  }

  static String _dioErrorMsg(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '响应超时';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.connectionError:
        return '无法连接服务器（DNS 或网络不通）';
      case DioExceptionType.badResponse:
        final msg = e.response?.data?['error']?['message'] ?? e.message;
        return '服务器错误：${_cleanServerMessage(msg)}';
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        final detail = e.error?.toString() ?? e.message ?? '';
        return '网络异常：$detail';
    }
  }

  static String _cleanServerMessage(Object? value) {
    final message = value?.toString().trim() ?? '';
    if (message.isEmpty) {
      return '请检查手机号或稍后重试';
    }
    if (message.contains('code') || message.contains('expired')) {
      return '验证码错误或已过期';
    }
    return message;
  }

  Future<void> logout() async {
    final refreshToken = state.session?.refreshToken;
    await _repository.logout(refreshToken);
    state = const AuthState(restoring: false);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStorageProvider),
  ),
);
