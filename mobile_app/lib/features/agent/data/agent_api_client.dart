import 'package:dio/dio.dart';

import '../domain/parse_result.dart';
import '../domain/schedule_request.dart';

class AgentApiClient {
  AgentApiClient(this._dio);

  final Dio _dio;

  Future<ParseResult> parse(String text) async {
    final response = await _dio.post('/agent/parse', data: {
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

  /// Phase 4: multi-intent NLU — classifies ANY natural-language request.
  Future<ParseResult> parseMulti(String text, {String? personaPreset}) async {
    final response = await _dio.post(
      '/agent/parse-multi',
      data: {
        'text': text,
        if (personaPreset != null && personaPreset.trim().isNotEmpty)
          'persona_preset': personaPreset.trim(),
      },
      options: Options(receiveTimeout: const Duration(seconds: 130)),
    );
    final data = response.data;
    if (data is! Map || data['data'] is! Map) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid parse-multi response',
      );
    }
    return ParseResult.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Phase 4: execute a parsed intent — creates the actual record.
  Future<ParseResult> execute(ParseResult parsed) async {
    final response = await _dio.post('/agent/execute', data: parsed.toJson());
    final data = response.data;
    final result = data['data'] as Map<String, dynamic>? ?? {};
    return ParseResult(
      intent: 'done',
      answer: result['summary'] as String? ?? result['answer'] as String?,
    );
  }

  Future<void> schedule(ScheduleRequest request) async {
    await _dio.post('/agent/schedule', data: request.toJson());
  }
}
