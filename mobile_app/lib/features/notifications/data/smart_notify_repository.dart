import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/smart_notify_models.dart';

/// Repository for smart notification API endpoints (P3-F3).
class SmartNotifyRepository {
  const SmartNotifyRepository({required this.dio});

  final Dio dio;

  /// GET /notify/insights — smart notification suggestions.
  Future<InsightsResult> fetchInsights() async {
    final response = await dio.get('/notify/insights');
    final parsed = ApiResponse.raw(response.data, InsightsResult.fromJson);
    if (!parsed.ok || parsed.data == null) {
      throw Exception(parsed.message ?? 'Failed to fetch insights');
    }
    return parsed.data!;
  }

  /// GET /notify/history — notification event history.
  Future<NotifyHistoryResult> fetchHistory({
    String? notifyType,
    int days = 7,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'days': days,
      'limit': limit,
    };
    if (notifyType != null && notifyType.isNotEmpty) {
      queryParams['notify_type'] = notifyType;
    }

    final response = await dio.get('/notify/history', queryParameters: queryParams);
    final parsed = ApiResponse.raw(response.data, NotifyHistoryResult.fromJson);
    if (!parsed.ok || parsed.data == null) {
      throw Exception(parsed.message ?? 'Failed to fetch history');
    }
    return parsed.data!;
  }
}

/// Riverpod provider for SmartNotifyRepository.
final smartNotifyRepoProvider = Provider<SmartNotifyRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return SmartNotifyRepository(dio: dio);
});
