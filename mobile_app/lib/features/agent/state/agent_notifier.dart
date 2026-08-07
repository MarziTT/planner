import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/butler/butler_persona.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/voice/voice_output_service.dart';
import '../../fast_capture/data/speech_capture_gateway.dart';
import '../data/agent_repository.dart';
import '../domain/agent_repository.dart' as domain;
import '../domain/parse_result.dart';
import '../domain/schedule_request.dart';

final speechCaptureGatewayProvider = Provider<SpeechCaptureGateway>((ref) {
  return SpeechCaptureGateway(
    remoteAsrClient: RemoteAsrClient(ref.watch(apiClientProvider)),
  );
});

enum AgentStatus {
  idle,
  listening,
  recognizing,
  parsing,
  confirming,
  done,
  error
}

enum ChatMessageType { user, system, confirmCard, answerCard, error }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.type,
    required this.text,
    this.parseResult,
    this.isParsing = false,
  });

  final String id;
  final ChatMessageType type;
  final String text;
  final ParseResult? parseResult;
  final bool isParsing;
}

class AgentState {
  const AgentState({
    this.messages = const [],
    this.status = AgentStatus.idle,
    this.errorMessage,
    this.recognizedText,
  });

  final List<ChatMessage> messages;
  final AgentStatus status;
  final String? errorMessage;
  final String? recognizedText;

  AgentState copyWith({
    List<ChatMessage>? messages,
    AgentStatus? status,
    String? errorMessage,
    String? recognizedText,
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: errorMessage,
      recognizedText: recognizedText ?? this.recognizedText,
    );
  }
}

class AgentNotifier extends StateNotifier<AgentState> {
  AgentNotifier(
    this._repository,
    this._speechGateway,
    this._voiceOutput,
    this._personaPreset,
  ) : super(const AgentState());

  final domain.AgentRepository _repository;
  final SpeechCaptureGateway? _speechGateway;
  final VoiceOutputService _voiceOutput;
  final String _personaPreset;

  static int _nextId = 0;

  String _generateId() =>
      'msg_${++_nextId}_${DateTime.now().millisecondsSinceEpoch}';

  void startListening() {
    final gateway = _speechGateway;
    if (gateway == null) return;
    state = state.copyWith(
      status: AgentStatus.listening,
      errorMessage: null,
    );
    // ignore: unawaited_futures
    gateway.startListening();
  }

  Future<void> stopListening() async {
    final gateway = _speechGateway;
    if (gateway == null) return;

    state = state.copyWith(status: AgentStatus.recognizing);

    final text = await gateway.stopListening();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        status: AgentStatus.idle,
        errorMessage: '没有听到声音，再试一次？',
      );
      return;
    }

    final userMsg = ChatMessage(
      id: _generateId(),
      type: ChatMessageType.user,
      text: trimmed,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      recognizedText: trimmed,
      status: AgentStatus.parsing,
      errorMessage: null,
    );

    await _parseText(trimmed);
  }

  Future<void> submitText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: _generateId(),
      type: ChatMessageType.user,
      text: trimmed,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      status: AgentStatus.parsing,
      errorMessage: null,
    );

    await _parseText(trimmed);
  }

  Future<void> _parseText(String text) async {
    try {
      final result = await _repository.parseMulti(
        text,
        personaPreset: _personaPreset,
      );

      if (result.llmWarning != null && result.llmWarning!.isNotEmpty) {
        final noticeMsg = ChatMessage(
          id: _generateId(),
          type: ChatMessageType.system,
          text: result.llmWarning!,
        );
        state = state.copyWith(
          messages: [...state.messages, noticeMsg],
          errorMessage: null,
        );
      }

      // Query intent — auto-execute and show answer immediately
      if (result.intent == 'query') {
        await _handleQuery(result);
        return;
      }

      // Unknown / low confidence — ask user to rephrase
      if (result.intent == 'unknown' || result.confidence < 0.4) {
        final systemMsg = ChatMessage(
          id: _generateId(),
          type: ChatMessageType.system,
          text: _personaText(
            standard: '没太理解，试试说得更具体些？比如"我吃了一碗面"或"今天有什么安排"',
            zero: '指令不够明确。可以说“记录一碗面”或“查看今天安排”。',
          ),
          isParsing: false,
        );
        state = state.copyWith(
          messages: [...state.messages, systemMsg],
          status: AgentStatus.idle,
          errorMessage: null,
        );
        return;
      }

      // All other intents — show confirm card
      final confirmMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.confirmCard,
        text: _confirmCardLabel(result),
        parseResult: result,
      );
      state = state.copyWith(
        messages: [...state.messages, confirmMsg],
        status: AgentStatus.confirming,
        errorMessage: null,
      );
    } on DioException {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: _personaText(
          standard: '智能解析暂不可用，请稍后重试。',
          zero: '连接异常。稍后重试。',
        ),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: '智能解析暂不可用',
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: _personaText(
          standard: '解析失败：${e.toString()}',
          zero: '任务解析失败。请重新下达指令。',
        ),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Handle query intent — execute immediately and show answer.
  Future<void> _handleQuery(ParseResult parsed) async {
    try {
      final result = await _repository.execute(parsed);
      final answer = result.answer ?? '查询完成';

      final answerMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.answerCard,
        text: answer,
        parseResult: parsed,
      );
      state = state.copyWith(
        messages: [...state.messages, answerMsg],
        status: AgentStatus.done,
        errorMessage: null,
      );
      unawaited(_voiceOutput.speak(answer));
    } on DioException {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: '查询失败，请稍后重试。',
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: '查询失败',
      );
    }
  }

  /// Confirm and execute the parsed action (meal/exercise/routine/reminder/event).
  Future<bool> confirmAction(ParseResult parsed) async {
    try {
      // For create_event, use the legacy schedule endpoint (backward compat)
      if (parsed.intent == 'create_event') {
        return confirmSchedule(parsed);
      }

      final result = await _repository.execute(parsed);
      final summary = result.answer ?? '已完成';

      final systemMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.system,
        text: summary,
        isParsing: false,
      );
      state = state.copyWith(
        messages: [...state.messages, systemMsg],
        status: AgentStatus.done,
        errorMessage: null,
      );
      unawaited(_voiceOutput.speak(summary));
      return true;
    } on DioException {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: '执行失败，请重试。',
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: '执行失败，请重试',
      );
      return false;
    }
  }

  void updatePendingAction(ParseResult updated) {
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.type == ChatMessageType.confirmCard,
    );
    if (index < 0) return;

    final current = messages[index];
    messages[index] = ChatMessage(
      id: current.id,
      type: current.type,
      text: _confirmCardLabel(updated),
      parseResult: updated,
    );
    state = state.copyWith(
      messages: messages,
      status: AgentStatus.confirming,
      errorMessage: null,
    );
  }

  void cancelPendingAction() {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: _generateId(),
          type: ChatMessageType.system,
          text: '已取消本次操作',
        ),
      ],
      status: AgentStatus.idle,
      errorMessage: null,
    );
  }

  Future<bool> confirmSchedule(ParseResult result) async {
    if (result.datetimeStart == null || result.eventName == null) {
      return false;
    }

    final end = result.datetimeEnd ??
        result.datetimeStart!.add(const Duration(hours: 1));

    try {
      await _repository.schedule(ScheduleRequest(
        eventName: result.eventName!,
        start: result.datetimeStart!,
        end: end,
        reminderMinutes: 30,
        sourceText: result.sourceText,
      ));

      final systemMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.system,
        text: '已安排：${result.eventName}',
        isParsing: false,
      );
      state = state.copyWith(
        messages: [...state.messages, systemMsg],
        status: AgentStatus.done,
        errorMessage: null,
      );
      unawaited(_voiceOutput.speak('已安排：${result.eventName}'));
      return true;
    } on DioException {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: '创建失败，请重试',
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: '创建失败，请重试',
      );
      return false;
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.error,
        text: '创建失败，请重试',
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const AgentState();
  }

  /// Human-readable label for the confirm card based on intent.
  String _confirmCardLabel(ParseResult r) {
    switch (r.intent) {
      case 'log_meal':
        return '记录饮食';
      case 'log_exercise':
        return '记录运动';
      case 'log_routine':
        return '记录作息';
      case 'create_reminder':
        return '创建提醒';
      default:
        return '确认安排';
    }
  }

  String _personaText({required String standard, required String zero}) {
    return _personaPreset == 'zzz_zero' ? zero : standard;
  }
}

final agentControllerProvider =
    StateNotifierProvider<AgentNotifier, AgentState>((ref) {
  final repository = ref.watch(agentRepositoryProvider);
  final gateway = ref.watch(speechCaptureGatewayProvider);
  final voiceOutput = ref.watch(voiceOutputProvider);
  final persona = ButlerPersona.forTheme(
    ref.watch(themeControllerProvider).preset,
  );
  final personaPreset =
      persona.preset == ButlerPersonaPreset.zzzTheme ? 'zzz_zero' : 'default';
  return AgentNotifier(repository, gateway, voiceOutput, personaPreset);
});
