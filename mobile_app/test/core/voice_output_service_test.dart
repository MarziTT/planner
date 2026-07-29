import 'package:flutter_test/flutter_test.dart';

import 'package:pixel_planner_mobile/core/voice/voice_output_platform.dart';
import 'package:pixel_planner_mobile/core/voice/voice_output_service.dart';
import 'package:pixel_planner_mobile/core/voice/voice_profile.dart';

class _FakeVoicePlatform implements VoiceOutputPlatform {
  final spoken = <String>[];
  final rates = <double>[];
  final pitches = <double>[];
  int stopCount = 0;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> setRate(double rate) async => rates.add(rate);

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);

  @override
  Future<void> dispose() async {}
}

void main() {
  test('uses the calm default profile and trims whitespace', () async {
    final platform = _FakeVoicePlatform();
    final service = VoiceOutputService(platform: platform);

    await service.speak('  今天 记得喝水。  ');

    expect(platform.spoken, ['今天 记得喝水。']);
    expect(platform.rates, [0.42]);
    expect(platform.pitches, [0.86]);
  });

  test('clips long dynamic messages to protect the listener', () async {
    final platform = _FakeVoicePlatform();
    final service = VoiceOutputService(
      platform: platform,
      profile: const ButlerVoiceProfile(maxCharacters: 6),
    );

    await service.speak('这是一个很长的动态管家建议。');

    expect(platform.spoken, ['这是一个很长……']);
  });

  test('disabled output stops the current voice and skips new speech',
      () async {
    final platform = _FakeVoicePlatform();
    final service = VoiceOutputService(platform: platform);

    service.setEnabled(false);
    await service.speak('不应该播报');

    expect(platform.spoken, isEmpty);
    expect(platform.stopCount, 1);
  });
}
