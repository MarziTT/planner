import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechCaptureGateway {
  final stt.SpeechToText _speech = stt.SpeechToText();
  Completer<String>? _completer;
  bool _initialized = false;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  Future<String> startListening({String localeId = 'zh_CN'}) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return '';
    }
    if (_speech.isListening) {
      await stopListening();
    }
    _completer = Completer<String>();
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && _completer != null && !_completer!.isCompleted) {
          _completer!.complete(result.recognizedWords);
        }
      },
      localeId: localeId,
    );
    return _completer!.future;
  }

  Future<String> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete('');
    }
    return _completer?.future ?? Future.value('');
  }

  void dispose() {
    _completer = null;
  }
}
