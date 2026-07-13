import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/planner_repository.dart';
import '../domain/planner_models.dart';

final selectedPlannerEventIdProvider = StateProvider<int?>((ref) => null);

class PlannerState {
  const PlannerState({
    this.events = const [],
    this.todos = const [],
    this.loading = false,
    this.errorMessage,
  });

  final List<PlannerEvent> events;
  final List<PlannerTodo> todos;
  final bool loading;
  final String? errorMessage;

  List<PlannerEvent> eventsForDay(DateTime day) {
    return events.where((item) {
      final startsAt = item.startsAt;
      return startsAt.year == day.year &&
          startsAt.month == day.month &&
          startsAt.day == day.day;
    }).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<PlannerEvent> upcomingEvents(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    return events
        .where(
          (item) =>
              item.startsAt.isAfter(nextDay) ||
              item.startsAt.isAtSameMomentAs(nextDay),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<PlannerTodo> get openTodos =>
      todos.where((item) => !item.completed).toList();

  List<PlannerTodo> get completedTodos =>
      todos.where((item) => item.completed).toList();

  PlannerState copyWith({
    List<PlannerEvent>? events,
    List<PlannerTodo>? todos,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlannerState(
      events: events ?? this.events,
      todos: todos ?? this.todos,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PlannerController extends StateNotifier<PlannerState> {
  PlannerController(this._repository) : super(const PlannerState()) {
    loadDashboard();
  }

  final PlannerRepository _repository;

  Future<void> loadDashboard() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final events = await _repository.fetchEvents();
      final todos = await _repository.fetchTodos();
      state = PlannerState(events: events, todos: todos, loading: false);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: _plannerErrorMessage(error, fallback: '首页数据加载失败'),
      );
    }
  }

  Future<void> addQuickEvent({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    try {
      final item = await _repository.createEvent(
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      final events = [...state.events, item]
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      state = state.copyWith(events: events, clearError: true);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '新增行程失败'),
      );
    }
  }

  Future<void> updateEventSchedule({
    required PlannerEvent event,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    try {
      final updated = await _repository.updateEvent(
        event: event,
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      final events = state.events
          .map((item) => item.id == updated.id ? updated : item)
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      state = state.copyWith(events: events, clearError: true);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '编辑行程失败'),
      );
    }
  }

  Future<void> removeEvent(int id) async {
    try {
      await _repository.deleteEvent(id);
      state = state.copyWith(
        events: state.events.where((item) => item.id != id).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '删除行程失败'),
      );
    }
  }

  Future<void> addQuickTodo({required String title}) async {
    try {
      final item = await _repository.createTodo(title: title);
      state = state.copyWith(todos: [item, ...state.todos], clearError: true);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '新增待办失败'),
      );
    }
  }

  Future<void> updateTodoTitle(PlannerTodo todo, String title) async {
    try {
      final updated = await _repository.updateTodo(
        todo: todo,
        title: title,
        completed: todo.completed,
      );
      final todos = state.todos
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      state = state.copyWith(todos: todos, clearError: true);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '编辑待办失败'),
      );
    }
  }

  Future<void> toggleTodo(PlannerTodo todo, bool completed) async {
    try {
      final updated = await _repository.updateTodo(
        todo: todo,
        title: todo.title,
        completed: completed,
      );
      final todos = state.todos
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      state = state.copyWith(todos: todos, clearError: true);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '更新待办状态失败'),
      );
    }
  }

  Future<void> removeTodo(int id) async {
    try {
      await _repository.deleteTodo(id);
      state = state.copyWith(
        todos: state.todos.where((item) => item.id != id).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: _plannerErrorMessage(error, fallback: '删除待办失败'),
      );
    }
  }

  void markLoggedOut() {
    state = const PlannerState();
  }
}

String _plannerErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return '登录态失效或未同步，请重新登录后再试。';
    }
    if (statusCode == 404) {
      return '计划接口不存在，当前线上后端可能还没更新到最新版本。';
    }
    if (statusCode != null && statusCode >= 500) {
      return '后端服务暂时异常，请稍后再试。';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '当前无法连接到计划服务，请检查网络或后端状态。';
    }
  }
  return fallback;
}

final plannerControllerProvider =
    StateNotifierProvider<PlannerController, PlannerState>(
  (ref) => PlannerController(ref.watch(plannerRepositoryProvider)),
);
