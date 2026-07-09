import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/settings/domain/settings_model.dart';

void main() {
  test('settings expose default reminder lead time', () {
    final settings = PlannerSettings.fromJson(const {});

    expect(settings.notificationsLeadMinutes, 15);
  });
}
