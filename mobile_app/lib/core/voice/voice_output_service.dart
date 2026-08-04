import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';
import '../butler/butler_persona.dart';
import 'voice_output_platform.dart';
import 'voice_profile.dart';
import 'voice_output_platform_io.dart' as io_voice;
import 'voice_output_platform_ohos.dart' as ohos_voice;

class VoiceOutputService {
  VoiceOutputService({
    VoiceOutputPlatform? platform,
    ButlerVoiceProfile profile = const ButlerVoiceProfile(),
  })  : _platform = platform ??
            (Platform.operatingSystem == 'ohos'
                ? ohos_voice.DeviceVoiceOutputPlatform()
                : io_voice.DeviceVoiceOutputPlatform()),
        _profile = profile;

  final VoiceOutputPlatform _platform;
  ButlerVoiceProfile _profile;
  bool _enabled = true;
  Future<void> _lastSpeech = Future<void>.value();

  bool get enabled => _enabled;

  void setProfile(ButlerVoiceProfile profile) {
    _profile = profile;
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _lastSpeech =
          _lastSpeech.catchError((_) {}).then((_) => _platform.stop());
    }
  }

  Future<void> speak(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!_enabled || normalized.isEmpty) return Future<void>.value();

    final clipped = normalized.length <= _profile.maxCharacters
        ? normalized
        : '${normalized.substring(0, _profile.maxCharacters)}……';

    // Serialize speech requests so fast agent responses never overlap.
    _lastSpeech = _lastSpeech.catchError((_) {}).then((_) async {
      await _platform.setRate(_profile.rate);
      await _platform.setPitch(_profile.pitch);
      await _platform.speak(clipped);
    });
    return _lastSpeech;
  }

  Future<void> stop() => _platform.stop();

  Future<void> dispose() => _platform.dispose();
}

final voiceOutputProvider = Provider<VoiceOutputService>((ref) {
  final theme = ref.read(themeControllerProvider);
  final persona = ButlerPersona.forTheme(theme.preset);
  final service = VoiceOutputService(profile: persona.voiceProfile);
  ref.listen<ThemeState>(themeControllerProvider, (_, next) {
    service.setProfile(ButlerPersona.forTheme(next.preset).voiceProfile);
  });
  ref.onDispose(service.dispose);
  return service;
});
