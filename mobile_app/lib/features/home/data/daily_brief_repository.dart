import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/daily_brief.dart';

class DailyBriefRepository {
  const DailyBriefRepository(this._dio);

  final Dio _dio;

  Future<DailyBrief> fetch({double? latitude, double? longitude}) async {
    final response = await _dio.get<dynamic>(
      '/dashboard/brief',
      queryParameters: {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lon': longitude,
      },
    );
    final parsed = ApiResponse.raw(response.data, DailyBrief.fromJson);
    if (!parsed.ok || parsed.data == null) {
      throw Exception(parsed.message ?? '生活简报暂时不可用');
    }
    return parsed.data!;
  }
}

final dailyBriefRepositoryProvider = Provider<DailyBriefRepository>((ref) {
  return DailyBriefRepository(ref.read(apiClientProvider));
});
