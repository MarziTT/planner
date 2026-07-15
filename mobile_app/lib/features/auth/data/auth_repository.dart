import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(apiClientProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository({required Dio dio, required TokenStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final TokenStorage _storage;

  Future<AuthSession?> restoreSession() async {
    final accessToken = await _storage.readAccessToken();
    final refreshToken = await _storage.readRefreshToken();
    final userJson = await _storage.readSessionUser();
    if (accessToken == null || refreshToken == null || userJson == null) {
      return null;
    }

    final user = AuthUser.fromJson(userJson);
    try {
      return await refreshSession(refreshToken: refreshToken, user: user);
    } on DioException catch (error) {
      if (_isAuthRejection(error)) {
        await _storage.clear();
        return null;
      }
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
  }

  Future<void> sendCode({required String phone}) async {
    await _dio.post('/auth/send-code', data: {
      'phone': phone,
    });
  }

  Future<AuthSession> loginWithPhone({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post('/auth/phone-login', data: {
      'phone': phone,
      'code': code,
    });
    return _persistAuthResponse(response.data['data'] as Map<String, dynamic>);
  }

  Future<AuthSession> refreshSession({
    required String refreshToken,
    required AuthUser user,
  }) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
    await _storage.saveSession(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      user: user.toJson(),
    );
    return AuthSession(
      user: user,
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<void> persistSession(AuthSession session) async {
    await _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: session.user.toJson(),
    );
  }

  Future<void> logout(String? refreshToken) async {
    final effectiveRefreshToken =
        refreshToken ?? await _storage.readRefreshToken();
    if (effectiveRefreshToken != null && effectiveRefreshToken.isNotEmpty) {
      try {
        await _dio.post(
          '/auth/logout',
          data: {'refreshToken': effectiveRefreshToken},
          options: Options(extra: const {'skipAuthRefresh': true}),
        );
      } on DioException {
        // Local cleanup still matters even if remote logout fails.
      }
    }
    await _storage.clear();
  }

  Future<AuthSession> _persistAuthResponse(Map<String, dynamic> rawData) async {
    final data = Map<String, dynamic>.from(rawData);
    final userJson = Map<String, dynamic>.from(data['user'] as Map);
    final user = AuthUser.fromJson(userJson);
    final tokens = Map<String, dynamic>.from(data['tokens'] as Map);

    await _storage.saveSession(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      user: userJson,
    );

    return AuthSession(
      user: user,
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  bool _isAuthRejection(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 400 || statusCode == 401 || statusCode == 403;
  }
}
