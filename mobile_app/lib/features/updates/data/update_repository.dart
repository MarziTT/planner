import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  return UpdateRepository(ref.watch(apiClientProvider));
});

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.required,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.buildNumber,
    required this.resourceCount,
  });

  final String version;
  final bool required;
  final List<String> releaseNotes;
  final String downloadUrl;
  final String buildNumber;
  final int resourceCount;
}

class UpdateRepository {
  UpdateRepository(this._dio);

  final Dio _dio;

  Future<UpdateInfo?> checkVersion() async {
    final response = await _dio.get('/app/update-manifest');
    final data = response.data['data'] as Map<String, dynamic>;
    return UpdateInfo(
      version: data['latestVersion'] as String? ?? '5.0.0',
      required: data['required'] as bool? ?? false,
      releaseNotes: (data['releaseNotes'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      downloadUrl: data['downloadUrl'] as String? ?? '',
      buildNumber: data['buildNumber'] as String? ?? '50000',
      resourceCount: (data['resources'] as List<dynamic>? ?? const []).length,
    );
  }
}
