import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/planner_models.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository(ref.watch(apiClientProvider));
});

class PlannerRepository {
  PlannerRepository(this._dio);

  final Dio _dio;

  Future<List<PlannerEvent>> fetchEvents() async {
    final response = await _dio.get('/events');
    final items = (response.data['data']['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return items.map(PlannerEvent.fromJson).toList();
  }

  Future<List<PlannerTodo>> fetchTodos() async {
    final response = await _dio.get('/todos');
    final items = (response.data['data']['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return items.map(PlannerTodo.fromJson).toList();
  }

  Future<PlannerEvent> createEvent({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final response = await _dio.post('/events', data: {
      'title': title,
      'startsAt': startsAt.toIso8601String(),
      'endsAt': endsAt.toIso8601String(),
      'status': 'planned',
    });
    return PlannerEvent.fromJson(
      Map<String, dynamic>.from(response.data['data']['item'] as Map),
    );
  }

  Future<PlannerEvent> updateEvent({
    required PlannerEvent event,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final response = await _dio.put('/events/${event.id}', data: {
      'title': title,
      'startsAt': startsAt.toIso8601String(),
      'endsAt': endsAt.toIso8601String(),
      'status': event.status,
    });
    return PlannerEvent.fromJson(
      Map<String, dynamic>.from(response.data['data']['item'] as Map),
    );
  }

  Future<void> deleteEvent(int id) async {
    await _dio.delete('/events/$id');
  }

  Future<PlannerTodo> createTodo({required String title}) async {
    final response = await _dio.post('/todos', data: {
      'title': title,
      'completed': false,
    });
    return PlannerTodo.fromJson(
      Map<String, dynamic>.from(response.data['data']['item'] as Map),
    );
  }

  Future<PlannerTodo> updateTodo({
    required PlannerTodo todo,
    required String title,
    required bool completed,
  }) async {
    final response = await _dio.put('/todos/${todo.id}', data: {
      'title': title,
      'completed': completed,
    });
    return PlannerTodo.fromJson(
      Map<String, dynamic>.from(response.data['data']['item'] as Map),
    );
  }

  Future<void> deleteTodo(int id) async {
    await _dio.delete('/todos/$id');
  }
}
