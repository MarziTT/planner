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
  testWidgets(
      'dashboard shows highlighted reminder card for selected future event',
      (tester) async {
    final event = PlannerEvent(
      id: 1,
      title: '明早航班',
      startsAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
      endsAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
      status: 'planned',
    );

    final plannerController = _SeededPlannerController(
      _FakePlannerRepository(events: [event], todos: const []),
      PlannerState(events: [event], todos: const []),
    );

    const profile = UserProfile(
      gender: '男',
      age: 28,
      city: '上海',
      bio: '',
      fitnessGoal: '',
      identity: 'worker',
      routineStart: '00:00',
      routineEnd: '23:59',
      focusArea: '深度工作',
      wantsFitness: false,
      fitnessMode: 'self',
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
          selectedPlannerEventIdProvider.overrideWith((ref) => 1),
        ],
        child: const MaterialApp(home: Scaffold(body: PlannerDashboard())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('从提醒返回'), findsOneWidget);
    expect(find.textContaining('明早航班'), findsWidgets);
  });
}
