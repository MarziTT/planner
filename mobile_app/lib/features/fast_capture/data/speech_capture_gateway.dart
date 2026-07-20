import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class RemoteAsrClient {
  RemoteAsrClient(this._dio);

  final Dio _dio;

  Future<String> recognizeWav(Uint8List audioBytes) async {
    final response = await _dio.post('/voice/asr', data: {
      'audioBase64': base64Encode(audioBytes),
      'voiceFormat': 'wav',
      'engineType': '16k_zh',
    });
    final responseData = response.data;
    if (responseData is! Map) {
      return '';
    }
    final data = responseData['data'];
    if (data is! Map) {
      return '';
    }
    return '${data['transcript'] ?? ''}'.trim();
  }
}

class SpeechCaptureGateway {
  SpeechCaptureGateway({
    stt.SpeechToText? speech,
    AudioRecorder? recorder,
    RemoteAsrClient? remoteAsrClient,
  })  : _speech = speech ?? stt.SpeechToText(),
        _recorder = remoteAsrClient == null ? null : recorder ?? AudioRecorder(),
        _remoteAsrClient = remoteAsrClient;

  final stt.SpeechToText _speech;
  final AudioRecorder? _recorder;
  final RemoteAsrClient? _remoteAsrClient;

  bool _initialized = false;
  bool _recording = false;
  String? _recordingPath;
  StreamController<String>? _streamController;
  Completer<String>? _completer;

  bool get isListening =>
      _remoteAsrClient != null
          ? _recording
          : _speech.isListening;

  bool get isAvailable =>
      _remoteAsrClient != null
          ? _initialized
          : _speech.isAvailable;

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (_remoteAsrClient != null) {
      _initialized = await _recorder!.hasPermission();
      return _initialized;
    }
    _initialized = await _speech.initialize();
    return _initialized;
  }

  // ── simple (Completer-based, for legacy callers) ──

  Future<String> startListening({String localeId = 'zh_CN'}) async {
    if (_remoteAsrClient != null) {
      return _startRecording();
    }
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return '';
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
    _completer = Completer<String>();
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult &&
            _completer != null &&
            !_completer!.isCompleted) {
          _completer!.complete(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
    );
    return _completer!.future;
  }

  // ── streaming (used by FastCaptureController) ──

  Stream<String> startListeningStream({String localeId = 'zh_CN'}) {
    _closeStreamIfActive();

    final controller = StreamController<String>();
    _streamController = controller;

    if (_remoteAsrClient != null) {
      _startRecordingStream(controller);
    } else {
      _startLocalSpeechStream(localeId, controller);
    }

    return controller.stream;
  }

  Future<String> finalizeStreamCapture() async {
    if (_remoteAsrClient == null || _recordingPath == null) {
      return '';
    }

    final path = _recordingPath;
    _recordingPath = null;
    _recording = false;

    try {
      await _recorder?.stop();
    } catch (_) {}

    final file = File(path!);
    if (!await file.exists()) return '';

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';
      final text = await _remoteAsrClient!.recognizeWav(
        Uint8List.fromList(bytes),
      );
      await file.delete().catchError((_) => file);
      return text;
    } catch (_) {
      await file.delete().catchError((_) => file);
      return '';
    }
  }

  Future<String> stopListening() async {
    if (_remoteAsrClient != null && _recording) {
      return _stopRecording();
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
    _closeStreamIfActive();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete('');
    }
    return _completer?.future ?? Future.value('');
  }

  void dispose() {
    _completer = null;
    _closeStreamIfActive();
    _recorder?.dispose();
  }

  // ── private: remote recording ──

  Future<void> _startRecordingStream(
    StreamController<String> controller,
  ) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        if (!controller.isClosed) {
          controller.addError(Exception('麦克风权限未授予'));
          controller.close();
        }
        return;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );
      _recording = true;
    } catch (e) {
      _recordingPath = null;
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
  }

  Future<String> _startRecording() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return '';
    }
    if (_recording) {
      await _stopRecording();
    }

    final tempDir = await getTemporaryDirectory();
    _recordingPath =
        '${tempDir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    _completer = Completer<String>();

    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    _recording = true;
    return _completer!.future;
  }

  Future<String> _stopRecording() async {
    // Streaming path: close the stream but leave _recordingPath intact
    // so finalizeStreamCapture() can read and process the audio.
    if (_completer == null) {
      _recording = false;
      _closeStreamIfActive();
      try {
        await _recorder?.stop();
      } catch (_) {}
      return '';
    }

    // Non-streaming path: stop, process, and complete.
    String? path = _recordingPath;
    _recordingPath = null;
    _recording = false;

    try {
      path = await _recorder?.stop() ?? path;
    } catch (_) {}

    final completer = _completer;
    if (completer == null || completer.isCompleted) {
      return completer?.future ?? Future.value('');
    }

    try {
      if (path == null) {
        completer.complete('');
      } else {
        final file = File(path);
        if (!await file.exists()) {
          completer.complete('');
        } else {
          final bytes = await file.readAsBytes();
          final text = bytes.isEmpty
              ? ''
              : await _remoteAsrClient!.recognizeWav(
                  Uint8List.fromList(bytes),
                );
          completer.complete(text);
          await file.delete().catchError((_) => file);
        }
      }
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  // ── private: local speech ──

  Future<void> _startLocalSpeechStream(
    String localeId,
    StreamController<String> controller,
  ) async {
    if (!_speech.isAvailable) {
      final ok = await _speech.initialize();
      if (!ok) {
        if (!controller.isClosed) {
          controller.add('');
          controller.close();
        }
        return;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    _speech.listen(
      onResult: (result) {
        if (!controller.isClosed) {
          controller.add(result.recognizedWords);
          if (result.finalResult) {
            controller.close();
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
    );
  }

  void _closeStreamIfActive() {
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.close();
      _streamController = null;
    }
  }
}
