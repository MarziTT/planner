import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/home/presentation/home_shell_page.dart';
import 'package:pixel_planner_mobile/features/notifications/data/reminder_gateway.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/notification_tap_event.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/reminder_schedule.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';
import 'package:pixel_planner_mobile/features/profile/data/profile_repository.dart';
import 'package:pixel_planner_mobile/features/profile/domain/profile_model.dart';
import 'package:pixel_planner_mobile/features/profile/state/profile_controller.dart';
import 'package:pixel_planner_mobile/features/settings/data/settings_repository.dart';
import 'package:pixel_planner_mobile/features/settings/domain/settings_model.dart';
import 'package:pixel_planner_mobile/features/settings/state/settings_controller.dart';

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

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository(this._settings) : super(Dio());
  final PlannerSettings? _settings;

  @override
  Future<PlannerSettings> fetchSettings() async {
    if (_settings == null) throw Exception('no settings');
    return _settings!;
  }
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

class _SpyReminderGateway implements ReminderGateway {
  int replaceSchedulesCallCount = 0;

  @override
  Stream<NotificationTapEvent> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => null;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {
    replaceSchedulesCallCount++;
  }
}

const _defaultSettings = PlannerSettings(
  theme: 'premiumMinimal',
  themeMode: 'dark',
  notificationsEnabled: true,
  notificationsLeadMinutes: 15,
  voiceEnabled: true,
  updateChannel: 'stable',
);

void main() {
  testWidgets('app resume triggers reminder resync', (tester) async {
    final event = PlannerEvent(
      id: 1,
      title: '\u7ad9\u4f1a',
      startsAt: DateTime(2026, 7, 9, 9),
      endsAt: DateTime(2026, 7, 9, 9, 30),
      status: 'planned',
    );

    final spyGateway = _SpyReminderGateway();

    final plannerController = _SeededPlannerController(
      _FakePlannerRepository(events: [event], todos: const []),
      PlannerState(events: [event], todos: const []),
    );

    final profile = const UserProfile(
      gender: '\u7537',
      age: 28,
      city: '\u4e0a\u6d77',
      bio: '',
      fitnessGoal: '',
      identity: 'worker',
      routineStart: '00:00',
      routineEnd: '23:59',
      focusArea: '\u6df1\u5ea6\u5de5\u4f5c',
      wantsFitness: false,
      fitnessMode: 'self',
    );

    final container = ProviderContainer(
      overrides: [
        reminderGatewayProvider.overrideWithValue(spyGateway),
        plannerControllerProvider.overrideWith((ref) => plannerController),
        settingsRepositoryProvider.overrideWithValue(
          _FakeSettingsRepository(_defaultSettings),
        ),
        profileControllerProvider.overrideWith(
          (ref) => ProfileController(
            _FakeProfileRepository(profile),
          )..state = ProfileState(profile: profile, loading: false),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: HomeShellPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Record call count after initial build
    final callsBeforeResume = spyGateway.replaceSchedulesCallCount;
    expect(callsBeforeResume, greaterThan(0));

    // Simulate app going to background: resumed → inactive → hidden → paused
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.inactive,
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.hidden,
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pumpAndSettle();

    // Simulate app coming back: paused → hidden → inactive → resumed
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.hidden,
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.inactive,
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle();

    // After resume, replaceSchedules should have been called again
    expect(
      spyGateway.replaceSchedulesCallCount,
      greaterThan(callsBeforeResume),
    );
  });
}
