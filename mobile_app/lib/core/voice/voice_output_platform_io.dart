import 'package:flutter_tts/flutter_tts.dart';

import 'voice_output_platform.dart';

class DeviceVoiceOutputPlatform implements VoiceOutputPlatform {
  DeviceVoiceOutputPlatform() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text) async {
    await _tts.setLanguage('zh-CN');
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}
