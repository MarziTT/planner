import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // 确保数据在 backup/restore 后仍可用
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device_only,
    ),
  ));
});

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _sessionUserKey = 'session_user';
  static const _loginPhoneKey = 'login_phone';

  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;
  static Map<String, dynamic>? _cachedSessionUser;

  final ValueNotifier<int> invalidateNotifier = ValueNotifier<int>(0);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    _cachedSessionUser = Map<String, dynamic>.from(user);

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _sessionUserKey, value: jsonEncode(user));
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null && token.isNotEmpty) {
      _cachedAccessToken = token;
    }
    return token;
  }

  Future<String?> readRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    final token = await _storage.read(key: _refreshTokenKey);
    if (token != null && token.isNotEmpty) {
      _cachedRefreshToken = token;
    }
    return token;
  }

  Future<Map<String, dynamic>?> readSessionUser() async {
    if (_cachedSessionUser != null) {
      return Map<String, dynamic>.from(_cachedSessionUser!);
    }

    final raw = await _storage.read(key: _sessionUserKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final user = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    _cachedSessionUser = user;
    return Map<String, dynamic>.from(user);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedSessionUser = null;

    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _sessionUserKey);
    invalidateNotifier.value++;
  }

  Future<void> savePhoneNumber(String phone) async {
    await _storage.write(key: _loginPhoneKey, value: phone);
  }

  Future<String?> getPhoneNumber() async {
    return await _storage.read(key: _loginPhoneKey);
  }
}