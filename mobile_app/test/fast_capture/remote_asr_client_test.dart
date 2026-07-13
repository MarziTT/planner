import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/speech_capture_gateway.dart';

void main() {
  test('remote ASR client uploads wav bytes and returns transcript', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = _AsrAdapter();
    final client = RemoteAsrClient(dio);

    final transcript = await client.recognizeWav(Uint8List.fromList([1, 2, 3]));

    expect(transcript, '今天下午七点去健身');
  });
}

class _AsrAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/voice/asr');
    final data = Map<String, dynamic>.from(options.data as Map);
    expect(data['voiceFormat'], 'wav');
    expect(data['engineType'], '16k_zh');
    expect(base64Decode(data['audioBase64'] as String), [1, 2, 3]);

    return ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': {'transcript': '今天下午七点去健身'},
        'error': null,
        'meta': {},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}