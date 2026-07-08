import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository({
    this.events = const [],
    this.todos = const [],
  }) : super(Dio());

  final List<PlannerEvent> events;
  final List<PlannerTodo> todos;

  @override
  Future<List<PlannerEvent>> fetchEvents() async => events;

  @override
  Future<List<PlannerTodo>> fetchTodos() async => todos;
}

void main() {
  test('planner state groups today and upcoming events', () {
    final now = DateTime(2026, 7, 8, 10, 0);
    final state = PlannerState(
      events: [
        PlannerEvent(
          id: 1,
          title: 'Today',
          startsAt: DateTime(2026, 7, 8, 12, 0),
          endsAt: DateTime(2026, 7, 8, 13, 0),
          status: 'planned',
        ),
        PlannerEvent(
          id: 2,
          title: 'Tomorrow',
          startsAt: DateTime(2026, 7, 9, 9, 0),
          endsAt: DateTime(2026, 7, 9, 10, 0),
          status: 'planned',
        ),
      ],
      todos: const [
        PlannerTodo(id: 1, title: 'Open', completed: false),
        PlannerTodo(id: 2, title: 'Done', completed: true),
      ],
    );

    expect(state.eventsForDay(now).map((item) => item.id), [1]);
    expect(state.upcomingEvents(now).map((item) => item.id), [2]);
    expect(state.openTodos.map((item) => item.id), [1]);
    expect(state.completedTodos.map((item) => item.id), [2]);
  });

  test('markLoggedOut clears loaded dashboard state', () async {
    final controller = PlannerController(
      _FakePlannerRepository(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Loaded',
            startsAt: DateTime(2026, 7, 8, 10, 0),
            endsAt: DateTime(2026, 7, 8, 11, 0),
            status: 'planned',
          ),
        ],
        todos: const [PlannerTodo(id: 1, title: 'Todo', completed: false)],
      ),
    );

    await controller.loadDashboard();
    expect(controller.state.events, isNotEmpty);
    expect(controller.state.todos, isNotEmpty);

    controller.markLoggedOut();

    expect(controller.state.events, isEmpty);
    expect(controller.state.todos, isEmpty);
    expect(controller.state.errorMessage, isNull);
  });
}
