import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/personal_memory.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.watch(apiClientProvider));
});

class MemorySnapshot {
  const MemorySnapshot({required this.learningEnabled, required this.items});

  final bool learningEnabled;
  final List<PersonalMemory> items;
}

class MemoryRepository {
  const MemoryRepository(this._dio);

  final Dio _dio;

  Future<MemorySnapshot> load() async {
    final response = await _dio.get('/memories');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((item) => PersonalMemory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    return MemorySnapshot(
      learningEnabled: data['learningEnabled'] as bool? ?? true,
      items: items,
    );
  }

  Future<void> setLearningEnabled(bool enabled) => _dio.put(
        '/memories/settings',
        data: {'learningEnabled': enabled},
      );

  Future<PersonalMemory> setActive(PersonalMemory memory, bool active) async {
    final response = await _dio.put(
      '/memories/${memory.id}',
      data: {'active': active},
    );
    return PersonalMemory.fromJson(
      Map<String, dynamic>.from(response.data['data']['item'] as Map),
    );
  }

  Future<void> delete(int id) => _dio.delete('/memories/$id');

  Future<void> clear() => _dio.delete('/memories');
}
