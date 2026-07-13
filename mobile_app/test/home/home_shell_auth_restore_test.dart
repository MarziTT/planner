import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/core/storage/secure_token_storage.dart';
import 'package:pixel_planner_mobile/features/auth/data/auth_repository.dart';
import 'package:pixel_planner_mobile/features/auth/domain/auth_models.dart';
import 'package:pixel_planner_mobile/features/auth/state/auth_controller.dart';
import 'package:pixel_planner_mobile/features/home/presentation/home_shell_page.dart';
import 'package:pixel_planner_mobile/features/notifications/data/reminder_gateway.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/notification_tap_event.dart';
import 'package:pixel_planner_mobile/features/notifications/domain/reminder_schedule.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';
import 'package:pixel_planner_mobile/features/settings/data/settings_repository.dart';
import 'package:pixel_planner_mobile/features/settings/domain/settings_model.dart';

void main() {
  testWidgets('logged in home shell reloads dashboard after initial failed load',
      (tester) async {
    final repository = _FailFirstPlannerRepository();
    final plannerController = PlannerController(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _ReadyAuthController()),
          plannerControllerProvider.overrideWith((ref) => plannerController),
          reminderGatewayProvider.overrideWithValue(_SilentReminderGateway()),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(_defaultSettings),
          ),
        ],
        child: const MaterialApp(home: HomeShellPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.fetchEventsCalls, greaterThanOrEqualTo(2));
    expect(plannerController.state.events, isNotEmpty);
    expect(plannerController.state.events.first.title, '恢复后的行程');
  });
}

const _defaultSettings = PlannerSettings(
  theme: 'premiumMinimal',
  themeMode: 'dark',
  notificationsEnabled: false,
  notificationsLeadMinutes: 15,
  voiceEnabled: true,
  updateChannel: 'stable',
);

class _FailFirstPlannerRepository extends PlannerRepository {
  _FailFirstPlannerRepository() : super(Dio());

  int fetchEventsCalls = 0;

  @override
  Future<List<PlannerEvent>> fetchEvents() async {
    fetchEventsCalls += 1;
    if (fetchEventsCalls == 1) {
      throw DioException(requestOptions: RequestOptions(path: '/events'));
    }
    final now = DateTime.now();
    return [
      PlannerEvent(
        id: 100,
        title: '恢复后的行程',
        startsAt: DateTime(now.year, now.month, now.day, now.hour, now.minute),
        endsAt: DateTime(now.year, now.month, now.day, now.hour, now.minute)
            .add(const Duration(hours: 1)),
        status: 'planned',
      ),
    ];
  }

  @override
  Future<List<PlannerTodo>> fetchTodos() async => const [];
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository(this._settings) : super(Dio());

  final PlannerSettings _settings;

  @override
  Future<PlannerSettings> fetchSettings() async => _settings;
}

class _SilentReminderGateway implements ReminderGateway {
  @override
  Stream<NotificationTapEvent> get taps => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermissions() async => true;

  @override
  Future<NotificationTapEvent?> getLaunchTap() async => null;

  @override
  Future<void> replaceSchedules(List<ReminderSchedule> schedules) async {}
}

class _ReadyAuthController extends AuthController {
  _ReadyAuthController()
      : super(AuthRepository(dio: Dio(), storage: _NoopTokenStorage())) {
    state = const AuthState(
      session: AuthSession(
        user: AuthUser(
          id: 1,
          email: 'demo@pixelplanner.app',
          nickname: 'Demo',
          onboardingDone: true,
        ),
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
      restoring: false,
    );
  }

  @override
  Future<void> restore() async {}
}

class _NoopTokenStorage extends TokenStorage {
  _NoopTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {}

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<Map<String, dynamic>?> readSessionUser() async => null;

  @override
  Future<void> clear() async {}
}