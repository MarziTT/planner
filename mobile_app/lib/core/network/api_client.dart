import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_storage.dart';

const _defaultApiBaseUrl = 'https://planner-production-d1ee.up.railway.app/api/v1';
const _skipAuthRefreshKey = 'skipAuthRefresh';

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final options = BaseOptions(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
    ),
    connectTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(seconds: 25),
    headers: const {'Content-Type': 'application/json'},
  );

  final dio = Dio(options);
  final refreshDio = Dio(options);
  Future<String?>? refreshFuture;

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await storage.readAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 ||
            error.requestOptions.extra[_skipAuthRefreshKey] == true) {
          handler.next(error);
          return;
        }

        refreshFuture ??= _refreshAccessToken(storage, refreshDio)
            .whenComplete(() => refreshFuture = null);
        final refreshedAccessToken = await refreshFuture;

        if (refreshedAccessToken == null || refreshedAccessToken.isEmpty) {
          handler.next(error);
          return;
        }

        try {
          final response = await _retryRequest(
            dio,
            error.requestOptions,
            refreshedAccessToken,
          );
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        } catch (_) {
          handler.next(error);
        }
      },
    ),
  );

  return dio;
});

Future<String?> _refreshAccessToken(TokenStorage storage, Dio dio) async {
  final refreshToken = await storage.readRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) {
    // 不要 clear(), 让上层显式登出时才清。
    // refreshToken 为空可能是模拟器 secure_storage 延迟导致的瞬态,
    // 清除 session 会导致用户被无故踢出。
    return null;
  }

  try {
    final response = await dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: const {_skipAuthRefreshKey: true}),
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
    final nextAccessToken = tokens['accessToken'] as String? ?? '';
    final nextRefreshToken = tokens['refreshToken'] as String? ?? '';

    if (nextAccessToken.isEmpty || nextRefreshToken.isEmpty) {
      return null;
    }

    await storage.saveTokens(
      accessToken: nextAccessToken,
      refreshToken: nextRefreshToken,
    );
    return nextAccessToken;
  } on DioException {
    return null;
  }
}

Future<Response<dynamic>> _retryRequest(
  Dio dio,
  RequestOptions requestOptions,
  String accessToken,
) {
  final headers = Map<String, dynamic>.from(requestOptions.headers)
    ..['Authorization'] = 'Bearer $accessToken';
  final extra = Map<String, dynamic>.from(requestOptions.extra)
    ..[_skipAuthRefreshKey] = true;

  return dio.request<dynamic>(
    requestOptions.path,
    data: requestOptions.data,
    queryParameters: requestOptions.queryParameters,
    cancelToken: requestOptions.cancelToken,
    onReceiveProgress: requestOptions.onReceiveProgress,
    onSendProgress: requestOptions.onSendProgress,
    options: Options(
      method: requestOptions.method,
      headers: headers,
      extra: extra,
      contentType: requestOptions.contentType,
      responseType: requestOptions.responseType,
      followRedirects: requestOptions.followRedirects,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      validateStatus: requestOptions.validateStatus,
      listFormat: requestOptions.listFormat,
    ),
  );
}