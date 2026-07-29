/// Platform-independent contract for dynamic voice output.
///
/// The default implementation uses the device TTS engine. HarmonyOS uses a
/// separate MethodChannel implementation so the native app can select a
/// system or cloud-backed voice without coupling the rest of the app to it.
abstract class VoiceOutputPlatform {
  Future<void> speak(String text);

  Future<void> stop();

  Future<void> setRate(double rate);

  Future<void> setPitch(double pitch);

  Future<void> dispose();
}
