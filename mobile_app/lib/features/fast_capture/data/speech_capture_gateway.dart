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
  bool _micPermissionDenied = false;

  bool get isListening =>
      _remoteAsrClient == null ? _speech.isListening : _isRecording;
  bool get isAvailable =>
      _remoteAsrClient == null ? _speech.isAvailable : _initialized;
  bool get micPermissionDenied => _micPermissionDenied;

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
      final wav = _pcmToWav(Uint8List.fromList(bytes));
      final text = await _remoteAsrClient.recognizeWav(wav);
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

  /// Wraps raw 16-bit linear PCM data (16 kHz, mono) in a RIFF/WAV header
  /// so Tencent ASR (expecting WAV) can consume it.
  static Uint8List _pcmToWav(Uint8List pcmData) {
    const sampleRate = 16000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 44 + dataSize;

    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize - 8, Endian.little);
    // WAVE
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // subchunk size
    header.setUint16(20, 1, Endian.little);  // PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    return Uint8List(44 + dataSize)
      ..setAll(0, header.buffer.asUint8List())
      ..setAll(44, pcmData);
  }

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

    // Start recorder FIRST — before calling _speech.listen() — so we know
    // early whether the recorder path is viable.
    bool recorderFailed = false;
    if (_remoteAsrClient != null && _recorder != null) {
      // Explicitly check microphone permission before attempting to record.
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        _micPermissionDenied = true;
        recorderFailed = true;
      } else {
        if (!_initialized) {
          await initialize();
        }
        try {
          final tempDirectory = await getTemporaryDirectory();
          _streamCaptureAudioPath =
              '${tempDirectory.path}${Platform.pathSeparator}pixel_planner_stream_${DateTime.now().millisecondsSinceEpoch}.pcm';
          await _recorder!.start(
            const RecordConfig(
              encoder: AudioEncoder.pcm16Bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: _streamCaptureAudioPath!,
          );
          _streamRecordingActive = true;
        } catch (_) {
          _streamCaptureAudioPath = null;
          recorderFailed = true;
        }
      }
    }

    try {
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
    } catch (_) {
      // _speech.listen() threw — local speech is unavailable.
      // If the recorder also failed, there is no recovery path.
      if (_remoteAsrClient != null && recorderFailed) {
        if (!controller.isClosed) {
          controller.addError(
            Exception('Both local speech and recorder failed'),
          );
          controller.close();
        }
        return;
      }
      // Otherwise the stream stays alive so stopListening() ->
      // _closeStreamIfActive() can close it, allowing finalizeStreamCapture
      // to use the recorder audio for backend ASR.
    }
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
        '${tempDirectory.path}${Platform.pathSeparator}pixel_planner_voice_${DateTime.now().millisecondsSinceEpoch}.pcm';
    _completer = Completer<String>();
    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16Bits,
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
                    _pcmToWav(Uint8List.fromList(bytes)),
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