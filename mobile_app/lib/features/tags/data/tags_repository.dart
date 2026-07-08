import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/tag_model.dart';

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepository(ref.watch(apiClientProvider));
});

class TagsRepository {
  TagsRepository(this._dio);

  final Dio _dio;

  Future<List<PlannerTag>> fetchTags() async {
    final response = await _dio.get('/tags');
    final items = (response.data['data']['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return items.map(PlannerTag.fromJson).toList();
  }

  Future<PlannerTag> createTag({required String name, required String color}) async {
    final response = await _dio.post('/tags', data: {'name': name, 'color': color});
    return PlannerTag.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<PlannerTag> updateTag(PlannerTag tag, {required String name, required String color}) async {
    final response = await _dio.put('/tags/' + tag.id.toString(), data: {'name': name, 'color': color});
    return PlannerTag.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<void> deleteTag(int id) async {
    await _dio.delete('/tags/' + id.toString());
  }
}
