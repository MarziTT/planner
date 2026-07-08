import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/export_snapshot.dart';

final importExportRepositoryProvider = Provider<ImportExportRepository>((ref) {
  return ImportExportRepository(ref.watch(apiClientProvider));
});

class ImportExportRepository {
  ImportExportRepository(this._dio);

  final Dio _dio;

  Future<ExportSnapshot> exportSnapshot() async {
    final response = await _dio.get('/export');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return ExportSnapshot(
      eventCount: (data['events'] as List<dynamic>? ?? []).length,
      todoCount: (data['todos'] as List<dynamic>? ?? []).length,
      tagCount: (data['tags'] as List<dynamic>? ?? []).length,
    );
  }

  Future<void> importSample() async {
    await _dio.post('/import', data: {
      'events': [
        {
          'title': '导入示例训练',
          'startsAt': DateTime.now().toIso8601String(),
          'endsAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        }
      ],
      'todos': [
        {'title': '导入示例待办'}
      ],
      'tags': [
        {'name': '示例', 'color': '#7C5CFF'}
      ],
    });
  }
}
