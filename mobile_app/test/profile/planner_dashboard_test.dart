import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/presentation/planner_dashboard.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';
import 'package:pixel_planner_mobile/features/profile/data/profile_repository.dart';
import 'package:pixel_planner_mobile/features/profile/domain/profile_model.dart';
import 'package:pixel_planner_mobile/features/profile/state/profile_controller.dart';

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository({required this.events, required this.todos})
      : super(Dio());

  final List<PlannerEvent> events;
  final List<PlannerTodo> todos;

  @override
  Future<List<PlannerEvent>> fetchEvents() async => events;

  @override
  Future<List<PlannerTodo>> fetchTodos() async => todos;
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.profile) : super(Dio());

  final UserProfile profile;

  @override
  Future<UserProfile> fetchProfile() async => profile;
}

class _SeededPlannerController extends PlannerController {
  _SeededPlannerController(super.repository, PlannerState seeded) {
    state = seeded;
  }
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.repository, UserProfile seeded) {
    state = ProfileState(profile: seeded, loading: false);
  }
}

void main() {
  testWidgets('dashboard keeps unified agenda and work actions',
      (tester) async {
    final now = DateTime.now();
    final event = PlannerEvent(
      id: 1,
      title: '站会',
      startsAt: now.add(const Duration(minutes: 30)),
      endsAt: now.add(const Duration(minutes: 60)),
      status: 'planned',
    );
    const todo = PlannerTodo(id: 1, title: '九点开发', completed: false);
    const profile = UserProfile(
      gender: '男',
      age: 28,
      city: '上海',
      bio: '',
      fitnessGoal: '减脂',
      identity: 'worker',
      routineStart: '00:00',
      routineEnd: '23:59',
      focusArea: '深度工作',
      wantsFitness: true,
      fitnessMode: 'coach',
    );

    final plannerController = _SeededPlannerController(
      _FakePlannerRepository(events: [event], todos: const [todo]),
      PlannerState(events: [event], todos: const [todo]),
    );

    final profileController = _SeededProfileController(
      _FakeProfileRepository(profile),
      profile,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerControllerProvider.overrideWith((ref) => plannerController),
          profileControllerProvider.overrideWith((ref) => profileController),
        ],
        child: const MaterialApp(home: Scaffold(body: PlannerDashboard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天安排'), findsOneWidget);
    expect(find.text('待办动作'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('站会'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('站会'), findsOneWidget);
    expect(find.text('九点开发'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);

    await tester.scrollUntilVisible(
      find.text('接下来'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('接下来'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('上班模式'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('上班模式'), findsOneWidget);
    expect(find.text('开发'), findsOneWidget);
    expect(find.text('开会'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('训练模块'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('训练模块'), findsOneWidget);
    expect(find.text('私教陪练'), findsOneWidget);
  });
}
