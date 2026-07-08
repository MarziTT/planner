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
    return AuthSession(
      user: AuthUser.fromJson(userJson),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    final userJson = Map<String, dynamic>.from(data['user'] as Map);
    final user = AuthUser.fromJson(userJson);
    final tokens = data['tokens'] as Map<String, dynamic>;
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

  Future<AuthSession> register({
    required String email,
    required String password,
    required String nickname,
    String timezone = 'Asia/Shanghai',
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'nickname': nickname,
      'timezone': timezone,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    final userJson = Map<String, dynamic>.from(data['user'] as Map);
    final user = AuthUser.fromJson(userJson);
    final tokens = data['tokens'] as Map<String, dynamic>;
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

  Future<void> logout(String? refreshToken) async {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    }
    await _storage.clear();
  }
}
