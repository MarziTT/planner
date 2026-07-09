import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/planner_repository.dart';
import '../data/schedule_text_parser.dart';
import '../domain/parsed_schedule_draft.dart';

class FastCaptureState {
  const FastCaptureState({
    this.pendingDraft,
    this.errorMessage,
  });

  final ParsedScheduleDraft? pendingDraft;
  final String? errorMessage;

  FastCaptureState copyWith({
    ParsedScheduleDraft? pendingDraft,
    String? errorMessage,
    bool clearPendingDraft = false,
    bool clearError = false,
  }) {
    return FastCaptureState(
      pendingDraft: clearPendingDraft ? null : pendingDraft ?? this.pendingDraft,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class FastCaptureController extends StateNotifier<FastCaptureState> {
  FastCaptureController({
    required PlannerRepository repository,
    ScheduleTextParser? parser,
  })  : _repository = repository,
        _parser = parser ?? ScheduleTextParser(),
        super(const FastCaptureState());

  final PlannerRepository _repository;
  final ScheduleTextParser _parser;

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
