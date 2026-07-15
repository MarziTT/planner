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

class _ControllableTapGateway implements ReminderGateway {
  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();

  NotificationTapEvent? launchTap;

  void emitTap(NotificationTapEvent event) => _tapController.add(event);

  @override
  Stream<NotificationTapEvent> get taps => _tapController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => launchTap;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {}
}

const _defaultSettings = PlannerSettings(
  theme: 'premiumMinimal',
  themeMode: 'dark',
  notificationsEnabled: true,
  notificationsLeadMinutes: 15,
  voiceEnabled: true,
  updateChannel: 'stable',
  availableThemes: [],
);

void main() {
  testWidgets('notification tap navigates to planner tab and highlights event',
      (tester) async {
    final event = PlannerEvent(
      id: 42,
      title: '\u4e0a\u5348\u5341\u70b9\u4f1a\u8bae',
      startsAt: DateTime(2026, 7, 9, 10),
      endsAt: DateTime(2026, 7, 9, 11),
      status: 'planned',
    );

    final tapGateway = _ControllableTapGateway();

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
        reminderGatewayProvider.overrideWithValue(tapGateway),
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

    // Before tap, no event should be highlighted
    expect(
      container.read(selectedPlannerEventIdProvider),
      isNull,
    );

    // Emulate notification tap
    tapGateway.emitTap(const NotificationTapEvent(eventId: 42));
    await tester.pumpAndSettle();

    // After tap, the event should be highlighted
    expect(
      container.read(selectedPlannerEventIdProvider),
      42,
    );

    // Dashboard should show the highlighted event with "从提醒返回"
    expect(find.text('\u4ece\u63d0\u9192\u8fd4\u56de'), findsOneWidget);
    expect(
      find.textContaining('\u4e0a\u5348\u5341\u70b9\u4f1a\u8bae'),
      findsWidgets,
    );
  });

  testWidgets('launch tap highlights event on startup', (tester) async {
    final event = PlannerEvent(
      id: 7,
      title: '\u665a\u4e0a\u8dd1\u6b65',
      startsAt: DateTime(2026, 7, 9, 19),
      endsAt: DateTime(2026, 7, 9, 20),
      status: 'planned',
    );

    final tapGateway = _ControllableTapGateway()
      ..launchTap = const NotificationTapEvent(eventId: 7);

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
      focusArea: '',
      wantsFitness: false,
      fitnessMode: 'self',
    );

    final container = ProviderContainer(
      overrides: [
        reminderGatewayProvider.overrideWithValue(tapGateway),
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

    // On startup with launchTap, event should be highlighted
    expect(
      container.read(selectedPlannerEventIdProvider),
      7,
    );

    expect(find.text('\u4ece\u63d0\u9192\u8fd4\u56de'), findsOneWidget);
  });
}
