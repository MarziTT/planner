import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/profile/data/profile_repository.dart';
import 'package:pixel_planner_mobile/features/profile/domain/profile_model.dart';
import 'package:pixel_planner_mobile/features/profile/presentation/profile_page.dart';
import 'package:pixel_planner_mobile/features/profile/state/profile_controller.dart';

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.profile) : super(Dio());

  UserProfile profile;

  @override
  Future<UserProfile> fetchProfile() async => profile;

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    this.profile = profile;
    return profile;
  }
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.repository, UserProfile seeded) {
    state = ProfileState(profile: seeded, loading: false);
  }
}

void main() {
  testWidgets('worker profile shows work schedule and fitness mode controls', (tester) async {
    final profile = UserProfile(
      gender: '男',
      age: 28,
      city: '上海',
      bio: '产品开发',
      fitnessGoal: '增肌',
      identity: 'worker',
      routineStart: '09:00',
      routineEnd: '18:00',
      focusArea: '深度工作',
      wantsFitness: true,
      fitnessMode: 'coach',
    );
    final controller = _SeededProfileController(_FakeProfileRepository(profile), profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('身份与节奏'), findsOneWidget);
    expect(find.text('上班族'), findsWidgets);
    expect(find.text('上班时间'), findsOneWidget);
    expect(find.text('下班时间'), findsOneWidget);
    expect(find.text('健身方式'), findsOneWidget);
    expect(find.text('私教陪练'), findsOneWidget);
  });
}
