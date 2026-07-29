import 'package:flutter/services.dart';

import 'voice_output_platform.dart';

/// HarmonyOS bridge. The native side owns the actual TTS engine and voice
/// selection; Dart only sends short dynamic messages and preferences.
class DeviceVoiceOutputPlatform implements VoiceOutputPlatform {
  static const MethodChannel _channel =
      MethodChannel('pixelplanner/harmony_voice');

  @override
  Future<void> speak(String text) async {
    await _channel.invokeMethod<void>('speak', {'text': text});
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  @override
  Future<void> setRate(double rate) async {
    await _channel.invokeMethod<void>('setRate', {'rate': rate});
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _channel.invokeMethod<void>('setPitch', {'pitch': pitch});
  }

  @override
  Future<void> dispose() async {
    await _channel.invokeMethod<void>('dispose');
  }
}
