import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/profile/domain/profile_model.dart';

void main() {
  test('worker profile becomes active during configured work hours', () {
    const profile = UserProfile(
      gender: '男',
      age: 28,
      city: '上海',
      bio: '',
      fitnessGoal: '',
      identity: 'worker',
      routineStart: '09:00',
      routineEnd: '18:00',
      focusArea: '深度工作',
      wantsFitness: true,
      fitnessMode: 'self',
    );

    expect(profile.isScheduleActiveAt(DateTime(2026, 7, 9, 10)), isTrue);
    expect(profile.isScheduleActiveAt(DateTime(2026, 7, 9, 20)), isFalse);
  });
}
