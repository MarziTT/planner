import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/health_models.dart';

class HealthRepository {
  final Dio _dio;

  const HealthRepository(this._dio);

  Future<HealthTrends> fetchTrends({int days = 7}) async {
    final response = await _dio.get('/dashboard/health', queryParameters: {'days': days});
    final parsed = ApiResponse.raw(response.data, HealthTrends.fromJson);

    if (!parsed.ok || parsed.data == null) {
      throw Exception(parsed.message ?? 'Failed to fetch health trends');
    }
    return parsed.data!;
  }
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.read(apiClientProvider));
});
