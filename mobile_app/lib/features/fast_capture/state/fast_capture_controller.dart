import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/planner_repository.dart';
import '../data/schedule_text_parser.dart';
import '../data/speech_capture_gateway.dart';
import '../domain/parsed_schedule_draft.dart';

class FastCaptureState {
  const FastCaptureState({
    this.pendingDraft,
    this.errorMessage,
    this.isListening = false,
  });

  final ParsedScheduleDraft? pendingDraft;
  final String? errorMessage;
  final bool isListening;

  FastCaptureState copyWith({
    ParsedScheduleDraft? pendingDraft,
    String? errorMessage,
    bool? isListening,
    bool clearPendingDraft = false,
    bool clearError = false,
  }) {
    return FastCaptureState(
      pendingDraft: clearPendingDraft ? null : pendingDraft ?? this.pendingDraft,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isListening: isListening ?? this.isListening,
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
    final draft = _parser.parse(input);
    if (draft.ambiguousHour != null) {
      state = state.copyWith(
        pendingDraft: draft,
        clearError: true,
      );
      return;
    }

    await _createEventFromDraft(draft);
  }

  Future<void> confirmAmbiguousHour(int resolvedHour24) async {
    final pendingDraft = state.pendingDraft;
    if (pendingDraft == null) {
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
      ),
    );
  }

  Future<void> cancelPendingDraft() async {
    state = state.copyWith(
      clearPendingDraft: true,
      clearError: true,
    );
  }

  Future<void> startListening() async {
    state = state.copyWith(isListening: true, clearError: true);
    try {
      final available = await _speechGateway.initialize();
      if (!available) {
        state = state.copyWith(
          isListening: false,
          errorMessage: '语音服务不可用，请检查麦克风权限',
        );
        return;
      }
      final text = await _speechGateway.startListening();
      if (text.isNotEmpty) {
        await submitText(text);
      }
    } finally {
      if (state.isListening) {
        state = state.copyWith(isListening: false);
      }
    }
  }

  Future<void> stopListening() async {
    await _speechGateway.stopListening();
    if (state.isListening) {
      state = state.copyWith(isListening: false);
    }
  }

  @override
  void dispose() {
    _speechGateway.dispose();
    super.dispose();
  }

  Future<void> _createEventFromDraft(ParsedScheduleDraft draft) async {
    try {
      await _repository.createEvent(
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
      );
      state = state.copyWith(
        clearPendingDraft: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: '创建日程失败',
      );
    }
  }
}
