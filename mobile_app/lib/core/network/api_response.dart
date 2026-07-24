import 'package:dio/dio.dart';

/// 统一 API 响应包装器。
///
/// 后端通用响应格式：
/// ```json
/// { "ok": true, "data": { "item": {...} } }
/// { "ok": true, "data": { "items": [...] } }
/// { "ok": false, "data": { "code": "...", "message": "..." } }
/// ```
///
/// 用法：
/// ```dart
/// final parsed = ApiResponse.single<User>(response.data, User.fromJson);
/// // 或
/// final list = ApiResponse.list<Tag>(response.data, Tag.fromJson);
/// ```
class ApiResponse<T> {
  final bool ok;
  final String? code;
  final String? message;
  final T? data;

  const ApiResponse._({
    required this.ok,
    this.code,
    this.message,
    this.data,
  });

  bool get isSuccess => ok && data != null;

  /// 解析单条记录：{ "data": { "item": ... } }
  factory ApiResponse.single(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final body = _body(raw);

    if (body['ok'] == false || (body['data'] is Map && body['data']?.containsKey('code') == true && body['data']?['ok'] == false)) {
      return ApiResponse<T>._(
        ok: false,
        code: _str(body['data']?['code'] ?? body['code']),
        message: _str(body['data']?['message'] ?? body['message']),
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return ApiResponse<T>._(ok: false, code: 'invalid_response', message: 'Unexpected response shape');
    }

    final item = data['item'];
    if (item is! Map<String, dynamic>) {
      return ApiResponse<T>._(ok: false, code: 'missing_item', message: 'Response missing item field');
    }

    try {
      return ApiResponse<T>._(ok: true, data: fromJson(item));
    } catch (e) {
      return ApiResponse<T>._(ok: false, code: 'parse_error', message: 'Failed to parse response item');
    }
  }

  /// 解析列表：{ "data": { "items": [...] } }
  factory ApiResponse.list(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final body = _body(raw);

    if (body['ok'] == false || (body['data'] is Map && body['data']?.containsKey('code') == true && body['data']?['ok'] == false)) {
      return ApiResponse<T>._(
        ok: false,
        code: _str(body['data']?['code'] ?? body['code']),
        message: _str(body['data']?['message'] ?? body['message']),
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return ApiResponse<T>._(ok: false, code: 'invalid_response', message: 'Unexpected response shape');
    }

    final items = data['items'];
    if (items is! List) {
      // 允许空列表
      if (items == null) {
        return ApiResponse<T>._(ok: true);
      }
      return ApiResponse<T>._(ok: false, code: 'missing_items', message: 'Response missing items field');
    }

    try {
      final list = items
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
      return ApiResponse<T>._(ok: true, data: list as T);
    } catch (e) {
      return ApiResponse<T>._(ok: false, code: 'parse_error', message: 'Failed to parse items list');
    }
  }

  /// 解析原始 data 字典（不提取 item/items）：
  /// { "ok": true, "data": { "tokens": {...}, "user": {...} } }
  factory ApiResponse.raw(
    dynamic raw,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final body = _body(raw);

    if (body['ok'] == false) {
      return ApiResponse<T>._(
        ok: false,
        code: _str(body['data']?['code'] ?? body['code']),
        message: _str(body['data']?['message'] ?? body['message']),
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return ApiResponse<T>._(ok: false, code: 'invalid_response', message: 'Unexpected response shape');
    }

    try {
      return ApiResponse<T>._(
        ok: true,
        data: fromJson != null ? fromJson(data) : data as T,
      );
    } catch (e) {
      return ApiResponse<T>._(ok: false, code: 'parse_error', message: 'Failed to parse raw data');
    }
  }

  /// 仅检查成功状态，不提取数据
  factory ApiResponse.ok(dynamic raw) {
    final body = _body(raw);
    final isOk = body['ok'] == true;
    return ApiResponse<T>._(ok: isOk);
  }

  /// 直接从 Dio Response 解析
  static Map<String, dynamic> fromDio(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return {'data': data, 'ok': true};
    return {'ok': false, 'data': {'code': 'invalid_response', 'message': 'Unexpected response type'}};
  }

  // --- helpers ---

  static Map<String, dynamic> _body(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Response) return _body(raw.data);
    return {};
  }

  static String? _str(dynamic v) => v?.toString();
}
