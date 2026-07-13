import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/core/storage/secure_token_storage.dart';
import 'package:pixel_planner_mobile/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository.restoreSession', () {
    test('clears stale tokens and returns null when refresh is unauthorized',
        () async {
      final storage = _MemoryTokenStorage()
        ..accessToken = 'old-access'
        ..refreshToken = 'old-refresh'
        ..sessionUser = _userJson();
      final dio = Dio()..httpClientAdapter = _StatusAdapter(401);
      final repository = AuthRepository(dio: dio, storage: storage);

      final session = await repository.restoreSession();

      expect(session, isNull);
      expect(storage.cleared, isTrue);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.readSessionUser(), isNull);
    });

    test('keeps cached session when refresh fails without an auth rejection',
        () async {
      final storage = _MemoryTokenStorage()
        ..accessToken = 'old-access'
        ..refreshToken = 'old-refresh'
        ..sessionUser = _userJson();
      final dio = Dio()..httpClientAdapter = _ThrowingAdapter();
      final repository = AuthRepository(dio: dio, storage: storage);

      final session = await repository.restoreSession();

      expect(session, isNotNull);
      expect(session!.accessToken, 'old-access');
      expect(storage.cleared, isFalse);
    });
  });
}

Map<String, dynamic> _userJson() => {
      'id': 1,
      'email': 'demo@pixelplanner.app',
      'nickname': 'Pixel User',
      'timezone': 'Asia/Shanghai',
      'onboardingDone': true,
    };

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() : super(const FlutterSecureStorage());

  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? sessionUser;
  bool cleared = false;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    sessionUser = Map<String, dynamic>.from(user);
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<Map<String, dynamic>?> readSessionUser() async =>
      sessionUser == null ? null : Map<String, dynamic>.from(sessionUser!);

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    sessionUser = null;
    cleared = true;
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'ok': false, 'error': 'unauthorized'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}
