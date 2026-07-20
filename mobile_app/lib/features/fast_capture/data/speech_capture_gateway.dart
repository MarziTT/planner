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
  Completer<String>? _completer;
  StreamController<String>? _streamController;
  bool _initialized = false;
  bool _isRecording = false;
  String? _recordingPath;
  String? _streamCaptureAudioPath;
  bool _streamRecordingActive = false;

  bool get isListening =>
      _remoteAsrClient == null ? _speech.isListening : _isRecording;
  bool get isAvailable =>
      _remoteAsrClient == null ? _speech.isAvailable : _initialized;

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (_remoteAsrClient != null) {
      _initialized = await _recorder!.hasPermission();
      return _initialized;
    }
    _initialized = await _speech.initialize();
    return _initialized;
  }

  Future<String> startListening({String localeId = 'zh_CN'}) async {
    if (_remoteAsrClient != null) {
      return _startRemoteRecording();
    }
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

  /// Returns a stream of partial recognition results from on-device speech
  /// recognition. Each emission contains the cumulative recognized text so far.
  /// The stream closes when speech recognition finalizes or is stopped.
  ///
  /// When [RemoteAsrClient] is configured, audio is also recorded in parallel
  /// so [finalizeStreamCapture] can retrieve a backend-ASR-corrected result.
  Stream<String> startListeningStream({String localeId = 'zh_CN'}) {
    _closeStreamIfActive();

    final controller = StreamController<String>();
    _streamController = controller;

    _initStreamAndListen(localeId, controller);

    return controller.stream;
  }

  /// Retrieves the backend ASR result for a streaming capture session.
  /// Must be called after [startListeningStream]'s stream has closed.
  /// Returns empty string if no remote ASR client is configured or
  /// if the recording could not be processed.
  Future<String> finalizeStreamCapture() async {
    if (_remoteAsrClient == null ||
        _streamCaptureAudioPath == null ||
        !_streamRecordingActive) {
      return '';
    }

    String? path;
    try {
      path = await _recorder?.stop();
    } catch (_) {
      path = null;
    }
    path ??= _streamCaptureAudioPath;
    _streamRecordingActive = false;
    _streamCaptureAudioPath = null;

    if (path == null) return '';

    final file = File(path);
    if (!await file.exists()) return '';

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';
      final text = await _remoteAsrClient.recognizeWav(
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
    if (_remoteAsrClient != null && _isRecording) {
      return _stopRemoteRecording();
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

  // --------------- private ---------------

  void _closeStreamIfActive() {
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.close();
      _streamController = null;
    }
  }

  Future<void> _initStreamAndListen(
    String localeId,
    StreamController<String> controller,
  ) async {
    // Ensure local speech_to_text is ready
    if (!_speech.isAvailable) {
      final ok = await _speech.initialize();
      if (!ok && _remoteAsrClient == null) {
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

    // Start remote recording in parallel if backend ASR is available
    if (_remoteAsrClient != null && _recorder != null) {
      if (!_initialized) {
        await initialize();
      }
      try {
        final tempDirectory = await getTemporaryDirectory();
        _streamCaptureAudioPath =
            '${tempDirectory.path}${Platform.pathSeparator}pixel_planner_stream_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _streamCaptureAudioPath!,
        );
        _streamRecordingActive = true;
      } catch (_) {
        _streamCaptureAudioPath = null;
      }
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

  Future<String> _startRemoteRecording() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return '';
    }
    if (_isRecording) {
      await _stopRemoteRecording();
    }

    final tempDirectory = await getTemporaryDirectory();
    _recordingPath =
        '${tempDirectory.path}${Platform.pathSeparator}pixel_planner_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    _completer = Completer<String>();
    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    _isRecording = true;
    return _completer!.future;
  }

  Future<String> _stopRemoteRecording() async {
    String? path = _recordingPath;
    if (_isRecording) {
      path = await _recorder!.stop() ?? path;
    }
    _isRecording = false;
    _recordingPath = null;

    final completer = _completer;
    if (completer == null) {
      return '';
    }
    if (!completer.isCompleted) {
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
    }
    return completer.future;
  }
}