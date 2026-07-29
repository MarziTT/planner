import '../theme/theme_controller.dart';
import '../voice/voice_profile.dart';

enum ButlerPersonaPreset {
  defaultButler,
  zzzTheme,
}

class ButlerPersona {
  const ButlerPersona({
    required this.preset,
    required this.displayName,
    required this.greeting,
    required this.styleHint,
    required this.voiceProfile,
  });

  final ButlerPersonaPreset preset;
  final String displayName;
  final String greeting;
  final String styleHint;
  final ButlerVoiceProfile voiceProfile;

  static const standard = ButlerPersona(
    preset: ButlerPersonaPreset.defaultButler,
    displayName: '贾维斯',
    greeting: '我在。今天想先处理什么？',
    styleHint: '温和、清晰、可靠；先给结论，再给下一步。',
    voiceProfile: ButlerVoiceProfile(
      rate: 0.46,
      pitch: 0.92,
      maxCharacters: 180,
    ),
  );

  /// ZZZ theme persona: an original restrained, mission-oriented style.
  /// It does not reproduce any character or actor performance.
  static const zzz = ButlerPersona(
    preset: ButlerPersonaPreset.zzzTheme,
    displayName: '零',
    greeting: '连接完成。告诉我下一项任务。',
    styleHint: '冷静、克制、短句、任务导向；少寒暄，不制造无意义提醒。',
    voiceProfile: ButlerVoiceProfile(
      rate: 0.42,
      pitch: 0.86,
      maxCharacters: 150,
    ),
  );

  static ButlerPersona forTheme(PlannerThemePreset theme) {
    return theme == PlannerThemePreset.kamenRiderZzz ? zzz : standard;
  }
}
