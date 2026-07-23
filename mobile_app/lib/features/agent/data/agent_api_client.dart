import 'package:dio/dio.dart';

import '../domain/parse_result.dart';
import '../domain/schedule_request.dart';

class AgentApiClient {
  AgentApiClient(this._dio);

  final Dio _dio;

  Future<ParseResult> parse(String text) async {
    final response = await _dio.post('/api/v1/agent/parse', data: {
      'text': text,
    });
    final data = response.data;
    if (data is! Map || data['data'] is! Map) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid parse response',
      );
    }
    return ParseResult.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> schedule(ScheduleRequest request) async {
    await _dio.post('/api/v1/agent/schedule', data: request.toJson());
  }
}
