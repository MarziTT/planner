import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/planner_repository.dart';
import '../data/schedule_text_parser.dart';
import '../data/speech_capture_gateway.dart';
import '../domain/capture_enums.dart';
import '../domain/parsed_schedule_draft.dart';

class FastCaptureState {
  const FastCaptureState({
    this.pendingDraft,
    this.errorMessage,
    this.recognizedText,
    this.partialText,
    this.isListening = false,
    this.isRecognizing = false,
    this.isSubmitting = false,
  });

  final ParsedScheduleDraft? pendingDraft;
  final String? errorMessage;
  final String? recognizedText;
  final String? partialText;
  final bool isListening;
  final bool isRecognizing;
  final bool isSubmitting;

  FastCaptureState copyWith({
    ParsedScheduleDraft? pendingDraft,
    String? errorMessage,
    String? recognizedText,
    String? partialText,
    bool? isListening,
    bool? isRecognizing,
    bool? isSubmitting,
    bool clearPendingDraft = false,
    bool clearError = false,
    bool clearRecognizedText = false,
    bool clearPartialText = false,
  }) {
    return FastCaptureState(
      pendingDraft:
          clearPendingDraft ? null : pendingDraft ?? this.pendingDraft,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      recognizedText:
          clearRecognizedText ? null : recognizedText ?? this.recognizedText,
      partialText:
          clearPartialText ? null : partialText ?? this.partialText,
      isListening: isListening ?? this.isListening,
      isRecognizing: isRecognizing ?? this.isRecognizing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class FastCaptureController extends StateNotifier<FastCaptureState> {
  FastCaptureController({
    required PlannerRepository repository,
    ScheduleTextParser? parser,
    SpeechCaptureGateway? speechGateway,
  })  : _repository = repository,
        _parser = parser ?? ScheduleTextParser(),
        _speechGateway = speechGateway ?? SpeechCaptureGateway(),
        super(const FastCaptureState());

  final PlannerRepository _repository;
  final ScheduleTextParser _parser;
  final SpeechCaptureGateway _speechGateway;

  Future<void> submitText(String input) async {
    if (state.isSubmitting) {
      return;
    }

    final draft = _parser.parse(input);
    if (draft.ambiguousHour != null ||
        draft.ambiguityKind == TimeAmbiguityKind.missingTime) {
      state = state.copyWith(
        pendingDraft: draft,
        clearError: true,
        isRecognizing: false,
        isSubmitting: false,
      );
      return;
    }

    if (draft.confidence < 0.5) {
      state = state.copyWith(
        pendingDraft: draft,
        clearError: true,
        isRecognizing: false,
        isSubmitting: false,
      );
      return;
    }

    await _createEventFromDraft(draft);
  }

  Future<void> confirmAmbiguousHour(int resolvedHour24) async {
    final pendingDraft = state.pendingDraft;
    if (pendingDraft == null || state.isSubmitting) {
      return;
    }

    final resolvedStartsAt = DateTime(
      pendingDraft.startsAt.year,
      pendingDraft.startsAt.month,
      pendingDraft.startsAt.day,
      resolvedHour24,
      pendingDraft.startsAt.minute,
    );
    final resolvedEndsAt = resolvedStartsAt.add(
      pendingDraft.endsAt.difference(pendingDraft.startsAt),
    );

    await _createEventFromDraft(
      ParsedScheduleDraft(
        title: pendingDraft.title,
        eventType: pendingDraft.eventType,
        startsAt: resolvedStartsAt,
        endsAt: resolvedEndsAt,
        ambiguityKind: pendingDraft.ambiguityKind,
        confidence: pendingDraft.confidence,
      ),
    );
  }

  Future<void> confirmMissingTime(TimePeriod period) async {
    final pendingDraft = state.pendingDraft;
    if (pendingDraft == null || state.isSubmitting) {
      return;
    }

    final resolvedHour = switch (period) {
      TimePeriod.morning => 9,
      TimePeriod.afternoon => 15,
      TimePeriod.evening => 19,
      TimePeriod.allDay => 9,
    };
    final resolvedStartsAt = DateTime(
      pendingDraft.startsAt.year,
      pendingDraft.startsAt.month,
      pendingDraft.startsAt.day,
      resolvedHour,
      0,
    );
    final resolvedEndsAt = resolvedStartsAt.add(
      pendingDraft.endsAt.difference(pendingDraft.startsAt),
    );

    await _createEventFromDraft(
      ParsedScheduleDraft(
        title: pendingDraft.title,
        eventType: pendingDraft.eventType,
        startsAt: resolvedStartsAt,
        endsAt: resolvedEndsAt,
        ambiguityKind: TimeAmbiguityKind.none,
        confidence: pendingDraft.confidence,
      ),
    );
  }

  Future<void> confirmLowConfidence(ParsedScheduleDraft updatedDraft) async {
    final pendingDraft = state.pendingDraft;
    if (pendingDraft == null || state.isSubmitting) {
      return;
    }

    await _createEventFromDraft(updatedDraft);
  }

  Future<void> cancelPendingDraft() async {
    state = state.copyWith(
      clearPendingDraft: true,
      clearError: true,
      isRecognizing: false,
      isSubmitting: false,
    );
  }

  Future<void> startListening() async {
    if (state.isSubmitting || state.isRecognizing) {
      return;
    }

    state = state.copyWith(
      isListening: true,
      isRecognizing: false,
      clearError: true,
      clearPartialText: true,
    );

    String lastPartial = '';

    try {
      final stream = _speechGateway.startListeningStream();

      await for (final partial in stream) {
        lastPartial = partial;
        state = state.copyWith(
          partialText: partial.isNotEmpty ? partial : null,
        );
      }
    } catch (_) {
      // Stream error: fall through to handle gracefully
    }

    // Stream closed — recording was stopped by user or auto-finalized
    state = state.copyWith(
      isListening: false,
      isRecognizing: true,
      clearPartialText: true,
    );

    try {
      // Retrieve backend ASR correction for higher accuracy
      final corrected = await _speechGateway.finalizeStreamCapture();
      final finalText = corrected.isNotEmpty ? corrected : lastPartial.trim();

      if (finalText.isNotEmpty) {
        state = state.copyWith(
          recognizedText: finalText,
          isRecognizing: false,
          clearError: true,
        );
        await submitText(finalText);
      } else {
        state = state.copyWith(
          isRecognizing: false,
          errorMessage: '没有识别到内容，请再说一次。',
        );
      }
    } catch (error) {
      state = state.copyWith(
        isListening: false,
        isRecognizing: false,
        errorMessage: _voiceCaptureErrorMessage(error),
      );
    }
  }

  Future<void> stopListening() async {
    if (!state.isListening) {
      return;
    }

    // Signal the gateway to stop; the running startListening() will
    // pick up stream completion and continue with backend correction.
    try {
      await _speechGateway.stopListening();
    } catch (_) {
      // Gateway may have already stopped; ignore
    }
  }

  @override
  void dispose() {
    _speechGateway.dispose();
    super.dispose();
  }

  Future<void> _createEventFromDraft(ParsedScheduleDraft draft) async {
    state = state.copyWith(
      isSubmitting: true,
      isRecognizing: false,
      clearError: true,
    );
    try {
      await _repository.createEvent(
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
      );
      state = state.copyWith(
        isSubmitting: false,
        isRecognizing: false,
        clearPendingDraft: true,
        clearError: true,
        clearRecognizedText: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        isRecognizing: false,
        errorMessage: _fastCaptureErrorMessage(error),
      );
    }
  }
}

String _fastCaptureErrorMessage(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return '登录态失效或未同步，请重新登录后再试。';
    }
    if (statusCode == 404) {
      return '新增接口不存在，当前线上后端可能还没更新到最新版本。';
    }
    if (statusCode != null && statusCode >= 500) {
      return '后端服务暂时异常，请稍后再试。';
    }
  }
  return '创建日程失败，请稍后重试。';
}

String _voiceCaptureErrorMessage(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return '语音识别接口还没部署到线上，请等待后端更新完成。';
    }
    if (statusCode == 401) {
      return '登录态失效，请重新登录后再试语音录入。';
    }
    if (statusCode != null && statusCode >= 500) {
      return '语音识别服务暂时异常，请稍后再试。';
    }
  }
  return '语音识别失败，请检查麦克风权限或稍后重试。';
}
