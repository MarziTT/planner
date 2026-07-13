import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/remote_resource.dart';

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
    required this.resources,
  });

  final String version;
  final bool required;
  final List<String> releaseNotes;
  final String downloadUrl;
  final String buildNumber;
  final List<RemoteResource> resources;

  int get resourceCount => resources.length;

  UpdateInfo copyWith({
    String? version,
    bool? required,
    List<String>? releaseNotes,
    String? downloadUrl,
    String? buildNumber,
    List<RemoteResource>? resources,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      required: required ?? this.required,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      buildNumber: buildNumber ?? this.buildNumber,
      resources: resources ?? this.resources,
    );
  }
}

class UpdateRepository {
  UpdateRepository(this._dio);

  final Dio _dio;

  Future<UpdateInfo?> checkVersion() async {
    final response = await _dio.get('/app/update-manifest');
    final data = response.data['data'] as Map<String, dynamic>;
    final resources = (data['resources'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RemoteResource.fromJson)
        .where((resource) => resource.isValid)
        .toList();

    return UpdateInfo(
      version: data['latestVersion'] as String? ?? '5.0.0',
      required: data['required'] as bool? ?? false,
      releaseNotes: (data['releaseNotes'] as List<dynamic>? ?? [])
          .map((e) => '$e')
          .toList(),
      downloadUrl: data['downloadUrl'] as String? ?? '',
      buildNumber: data['buildNumber'] as String? ?? '50000',
      resources: resources,
    );
  }
}
