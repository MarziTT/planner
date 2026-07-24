import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_cache_service.dart';
import '../../../core/network/api_client.dart';
import '../domain/tag_model.dart';

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepository(
    ref.watch(apiClientProvider),
    cache: ref.watch(localCacheProvider),
  );
});

class TagsRepository {
  TagsRepository(this._dio, {LocalCacheService? cache}) : _cache = cache;

  final Dio _dio;
  final LocalCacheService? _cache;

  Future<List<PlannerTag>> fetchTags() async {
    try {
      final response = await _dio.get('/tags');
      final items = (response.data['data']['items'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final tags = items.map(PlannerTag.fromJson).toList();
      _cache?.writeList(
        key: CacheKeys.tags,
        items: tags,
        toJson: _tagToJson,
      );
      return tags;
    } on DioException {
      final cached = _cache?.readList<PlannerTag>(
        key: CacheKeys.tags,
        fromJson: PlannerTag.fromJson,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<PlannerTag> createTag({
    required String name,
    required String color,
    bool isRecurring = false,
    String recurrenceRule = '',
  }) async {
    final response = await _dio.post('/tags', data: {
      'name': name,
      'color': color,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule,
    });
    return PlannerTag.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<PlannerTag> updateTag(PlannerTag tag, {
    required String name,
    required String color,
    bool? isRecurring,
    String? recurrenceRule,
  }) async {
    final data = <String, dynamic>{'name': name, 'color': color};
    if (isRecurring != null) data['isRecurring'] = isRecurring;
    if (recurrenceRule != null) data['recurrenceRule'] = recurrenceRule;
    final response = await _dio.put('/tags/' + tag.id.toString(), data: data);
    return PlannerTag.fromJson(Map<String, dynamic>.from(response.data['data']['item'] as Map));
  }

  Future<void> deleteTag(int id) async {
    await _dio.delete('/tags/' + id.toString());
  }
}

Map<String, dynamic> _tagToJson(PlannerTag t) => {
      'id': t.id,
      'name': t.name,
      'color': t.color,
      'isRecurring': t.isRecurring,
      'recurrenceRule': t.recurrenceRule,
    };
