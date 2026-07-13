import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/presentation/planner_calendar_panel.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  final today = DateTime(2026, 7, 10);
  final selectedDay = DateTime(2026, 7, 10);
  final visibleMonth = DateTime(2026, 7);

  group('PlannerCalendarPanel', () {
    testWidgets('renders month header and weekday labels', (tester) async {
      var previousCalled = false;
      var nextCalled = false;

      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: today,
          events: const [],
          onPreviousMonth: () => previousCalled = true,
          onNextMonth: () => nextCalled = true,
          onSelectDay: (_) {},
        ),
      ));

      expect(find.text('2026年7月'), findsOneWidget);
      expect(find.text('一'), findsOneWidget);
      expect(find.text('二'), findsOneWidget);
      expect(find.text('三'), findsOneWidget);
      expect(find.text('四'), findsOneWidget);
      expect(find.text('五'), findsOneWidget);
      expect(find.text('六'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
    });

    testWidgets('renders day numbers in grid', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: today,
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      // July 2026 has "1" appearing twice (July 1 and Aug 1 from the 42-cell grid)
      expect(find.text('1'), findsAtLeast(1));
      expect(find.text('31'), findsOneWidget);
    });

    testWidgets('selected day is rendered', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: DateTime(2026, 7, 15),
          today: today,
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      // The selected day cell should exist in the widget tree
      expect(find.text('15'), findsWidgets);
    });

    testWidgets('today cell shows "今" label', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: DateTime(2026, 7, 10),
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      expect(find.text('今'), findsOneWidget);
    });

    testWidgets('widget builds with events', (tester) async {
      final events = [
        PlannerEvent(
          id: 1,
          title: 'Meeting',
          startsAt: DateTime(2026, 7, 10, 10, 0),
          endsAt: DateTime(2026, 7, 10, 11, 0),
          status: 'planned',
        ),
      ];

      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: today,
          events: events,
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      // Widget should build without rendering errors
      expect(find.byType(PlannerCalendarPanel), findsOneWidget);
    });

    testWidgets('previous month button triggers callback', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: today,
          events: const [],
          onPreviousMonth: () => called = true,
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      expect(called, isTrue);
    });

    testWidgets('next month button triggers callback', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: visibleMonth,
          selectedDay: selectedDay,
          today: today,
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () => called = true,
          onSelectDay: (_) {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      expect(called, isTrue);
    });

    testWidgets('tapping a day cell calls onSelectDay with correct date',
        (tester) async {
      DateTime? tappedDay;
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: DateTime(2026, 7),
          selectedDay: DateTime(2026, 7, 10),
          today: today,
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (day) => tappedDay = day,
        ),
      ));

      // Tap on the 15th day cell
      await tester.tap(find.text('15').last);
      expect(tappedDay, isNotNull);
      expect(tappedDay!.day, 15);
      expect(tappedDay!.month, 7);
      expect(tappedDay!.year, 2026);
    });

    testWidgets('widget renders without overflow', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: DateTime(2026, 7),
          selectedDay: DateTime(2026, 7, 10),
          today: DateTime(2026, 7, 10),
          events: const [],
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      expect(find.byType(PlannerCalendarPanel), findsOneWidget);
      // No overflow errors should have been thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('widget builds with multiple events', (tester) async {
      final events = [
        PlannerEvent(
          id: 1,
          title: 'Event 1',
          startsAt: DateTime(2026, 7, 10, 9, 0),
          endsAt: DateTime(2026, 7, 10, 10, 0),
          status: 'planned',
        ),
        PlannerEvent(
          id: 2,
          title: 'Event 2',
          startsAt: DateTime(2026, 7, 11, 14, 0),
          endsAt: DateTime(2026, 7, 11, 15, 0),
          status: 'planned',
        ),
        PlannerEvent(
          id: 3,
          title: 'Event 3',
          startsAt: DateTime(2026, 7, 15, 8, 0),
          endsAt: DateTime(2026, 7, 15, 9, 0),
          status: 'planned',
        ),
      ];

      await tester.pumpWidget(_wrapWithMaterial(
        PlannerCalendarPanel(
          visibleMonth: DateTime(2026, 7),
          selectedDay: DateTime(2026, 7, 10),
          today: DateTime(2026, 7, 10),
          events: events,
          onPreviousMonth: () {},
          onNextMonth: () {},
          onSelectDay: (_) {},
        ),
      ));

      expect(find.byType(PlannerCalendarPanel), findsOneWidget);
    });
  });

  group('PlannerEvent.fromJson', () {
    test('parses full event JSON', () {
      final json = {
        'id': 42,
        'title': 'Team Standup',
        'startsAt': '2026-07-10T09:00:00.000Z',
        'endsAt': '2026-07-10T10:00:00.000Z',
        'status': 'planned',
      };

      final event = PlannerEvent.fromJson(json);

      expect(event.id, 42);
      expect(event.title, 'Team Standup');
      expect(event.startsAt.toUtc(), DateTime.utc(2026, 7, 10, 9, 0, 0));
      expect(event.endsAt.toUtc(), DateTime.utc(2026, 7, 10, 10, 0, 0));
      expect(event.status, 'planned');
    });

    test('handles missing title and status with defaults', () {
      final json = {
        'id': 1,
        'startsAt': '2026-07-10T09:00:00.000Z',
        'endsAt': '2026-07-10T10:00:00.000Z',
      };

      final event = PlannerEvent.fromJson(json);

      expect(event.title, '');
      expect(event.status, 'planned');
    });

    test('handles null title and status', () {
      final json = {
        'id': 1,
        'title': null,
        'startsAt': '2026-07-10T09:00:00.000Z',
        'endsAt': '2026-07-10T10:00:00.000Z',
        'status': null,
      };

      final event = PlannerEvent.fromJson(json);

      expect(event.title, '');
      expect(event.status, 'planned');
    });
  });

  group('PlannerTodo.fromJson', () {
    test('parses full todo JSON', () {
      final json = {
        'id': 7,
        'title': 'Buy groceries',
        'completed': true,
      };

      final todo = PlannerTodo.fromJson(json);

      expect(todo.id, 7);
      expect(todo.title, 'Buy groceries');
      expect(todo.completed, isTrue);
    });

    test('handles missing fields with defaults', () {
      final json = {
        'id': 2,
      };

      final todo = PlannerTodo.fromJson(json);

      expect(todo.id, 2);
      expect(todo.title, '');
      expect(todo.completed, isFalse);
    });

    test('handles null title and completed', () {
      final json = {
        'id': 3,
        'title': null,
        'completed': null,
      };

      final todo = PlannerTodo.fromJson(json);

      expect(todo.title, '');
      expect(todo.completed, isFalse);
    });
  });

  testWidgets('only future or current events show calendar dots',
      (tester) async {
    final events = [
      PlannerEvent(
        id: 1,
        title: 'Past',
        startsAt: DateTime(2026, 7, 10, 8),
        endsAt: DateTime(2026, 7, 10, 9),
        status: 'planned',
      ),
      PlannerEvent(
        id: 2,
        title: 'Future',
        startsAt: DateTime(2026, 7, 11, 8),
        endsAt: DateTime(2026, 7, 11, 9),
        status: 'planned',
      ),
    ];

    await tester.pumpWidget(_wrapWithMaterial(
      PlannerCalendarPanel(
        visibleMonth: DateTime(2026, 7),
        selectedDay: DateTime(2026, 7, 11),
        today: DateTime(2026, 7, 10, 12),
        events: events,
        onPreviousMonth: () {},
        onNextMonth: () {},
        onSelectDay: (_) {},
      ),
    ));

    expect(find.byKey(const Key('calendar_event_dot_2026_7_10')), findsNothing);
    expect(
        find.byKey(const Key('calendar_event_dot_2026_7_11')), findsOneWidget);
  });
  group('PlannerState', () {
    test('eventsForDay filters and sorts events for a specific day', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Afternoon',
            startsAt: DateTime(2026, 7, 10, 14, 0),
            endsAt: DateTime(2026, 7, 10, 15, 0),
            status: 'planned',
          ),
          PlannerEvent(
            id: 2,
            title: 'Morning',
            startsAt: DateTime(2026, 7, 10, 9, 0),
            endsAt: DateTime(2026, 7, 10, 10, 0),
            status: 'planned',
          ),
          PlannerEvent(
            id: 3,
            title: 'Other day',
            startsAt: DateTime(2026, 7, 11, 12, 0),
            endsAt: DateTime(2026, 7, 11, 13, 0),
            status: 'planned',
          ),
        ],
      );

      final result = state.eventsForDay(DateTime(2026, 7, 10));

      expect(result.length, 2);
      expect(result[0].id, 2); // Morning first (sorted by startsAt)
      expect(result[1].id, 1); // Afternoon second
    });

    test('eventsForDay returns empty list when no events match', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Event',
            startsAt: DateTime(2026, 7, 11, 10, 0),
            endsAt: DateTime(2026, 7, 11, 11, 0),
            status: 'planned',
          ),
        ],
      );

      final result = state.eventsForDay(DateTime(2026, 7, 10));

      expect(result, isEmpty);
    });

    test('upcomingEvents returns events after the given day', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Today',
            startsAt: DateTime(2026, 7, 10, 10, 0),
            endsAt: DateTime(2026, 7, 10, 11, 0),
            status: 'planned',
          ),
          PlannerEvent(
            id: 2,
            title: 'Tomorrow',
            startsAt: DateTime(2026, 7, 11, 9, 0),
            endsAt: DateTime(2026, 7, 11, 10, 0),
            status: 'planned',
          ),
          PlannerEvent(
            id: 3,
            title: 'Next week',
            startsAt: DateTime(2026, 7, 17, 14, 0),
            endsAt: DateTime(2026, 7, 17, 15, 0),
            status: 'planned',
          ),
        ],
      );

      final result = state.upcomingEvents(DateTime(2026, 7, 10));

      expect(result.length, 2);
      expect(result[0].id, 2);
      expect(result[1].id, 3);
    });

    test('upcomingEvents includes events at next day boundary', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Midnight',
            startsAt: DateTime(2026, 7, 11, 0, 0, 0),
            endsAt: DateTime(2026, 7, 11, 1, 0, 0),
            status: 'planned',
          ),
        ],
      );

      final result = state.upcomingEvents(DateTime(2026, 7, 10));

      expect(result.length, 1);
      expect(result[0].id, 1);
    });

    test('openTodos returns only incomplete todos', () {
      final state = PlannerState(
        todos: const [
          PlannerTodo(id: 1, title: 'Open 1', completed: false),
          PlannerTodo(id: 2, title: 'Done', completed: true),
          PlannerTodo(id: 3, title: 'Open 2', completed: false),
        ],
      );

      final result = state.openTodos;

      expect(result.length, 2);
      expect(result.map((t) => t.id), [1, 3]);
    });

    test('completedTodos returns only completed todos', () {
      final state = PlannerState(
        todos: const [
          PlannerTodo(id: 1, title: 'Open', completed: false),
          PlannerTodo(id: 2, title: 'Done 1', completed: true),
          PlannerTodo(id: 3, title: 'Done 2', completed: true),
        ],
      );

      final result = state.completedTodos;

      expect(result.length, 2);
      expect(result.map((t) => t.id), [2, 3]);
    });

    test('copyWith preserves unchanged fields', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Event',
            startsAt: DateTime(2026, 7, 10),
            endsAt: DateTime(2026, 7, 10, 1),
            status: 'planned',
          ),
        ],
        loading: true,
        errorMessage: 'error',
      );

      final copied = state.copyWith(loading: false);

      expect(copied.events.length, 1);
      expect(copied.loading, isFalse);
      expect(copied.errorMessage, 'error');
    });

    test('copyWith clearError removes error message', () {
      final state = PlannerState(errorMessage: 'some error');

      final copied = state.copyWith(clearError: true);

      expect(copied.errorMessage, isNull);
    });

    test('eventsForDay handles empty events list', () {
      final state = PlannerState();

      final result = state.eventsForDay(DateTime(2026, 7, 10));

      expect(result, isEmpty);
    });

    test('upcomingEvents handles empty events list', () {
      final state = PlannerState();

      final result = state.upcomingEvents(DateTime(2026, 7, 10));

      expect(result, isEmpty);
    });

    test('copyWith replaces events when provided', () {
      final state = PlannerState(
        events: [
          PlannerEvent(
            id: 1,
            title: 'Old',
            startsAt: DateTime(2026, 7, 10),
            endsAt: DateTime(2026, 7, 10, 1),
            status: 'planned',
          ),
        ],
      );

      final newEvents = [
        PlannerEvent(
          id: 2,
          title: 'New',
          startsAt: DateTime(2026, 7, 11),
          endsAt: DateTime(2026, 7, 11, 1),
          status: 'planned',
        ),
      ];

      final copied = state.copyWith(events: newEvents);

      expect(copied.events.length, 1);
      expect(copied.events[0].id, 2);
      expect(copied.events[0].title, 'New');
    });

    test('default PlannerState has empty lists and loading false', () {
      final state = PlannerState();

      expect(state.events, isEmpty);
      expect(state.todos, isEmpty);
      expect(state.loading, isFalse);
      expect(state.errorMessage, isNull);
    });
  });
}
