import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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

enum AgentStatus { idle, listening, parsing, confirming, done, error }

enum ChatMessageType { user, system, confirmCard, error }

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
  ) : super(const AgentState());

  final domain.AgentRepository _repository;
  final SpeechCaptureGateway? _speechGateway;

  static int _nextId = 0;

  String _generateId() => 'msg_${++_nextId}_${DateTime.now().millisecondsSinceEpoch}';

  void startListening() {
    final gateway = _speechGateway;
    if (gateway == null) return;
    state = state.copyWith(
      status: AgentStatus.listening,
      errorMessage: null,
    );
    // Kick off the recording; the returned future completes when
    // stopListening() finalizes the capture, so we don't await it here.
    // ignore: unawaited_futures
    gateway.startListening();
  }

  Future<void> stopListening() async {
    final gateway = _speechGateway;
    if (gateway == null) return;

    state = state.copyWith(status: AgentStatus.parsing);

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
      final result = await _repository.parse(text);

      if (result.confidence < 0.5 || result.eventName == null) {
        final systemMsg = ChatMessage(
          id: _generateId(),
          type: ChatMessageType.system,
          text: '没太理解，请补充时间信息。你说的是"$text"',
          isParsing: false,
        );
        state = state.copyWith(
          messages: [...state.messages, systemMsg],
          status: AgentStatus.idle,
          errorMessage: null,
        );
        return;
      }

      final confirmMsg = ChatMessage(
        id: _generateId(),
        type: ChatMessageType.confirmCard,
        text: '确认安排',
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
        text: '智能解析暂不可用，请稍后重试。',
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
        text: '解析失败：${e.toString()}',
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        status: AgentStatus.error,
        errorMessage: e.toString(),
      );
    }
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
}

final agentControllerProvider =
    StateNotifierProvider<AgentNotifier, AgentState>((ref) {
  final repository = ref.watch(agentRepositoryProvider);
  final gateway = ref.watch(speechCaptureGatewayProvider);
  return AgentNotifier(repository, gateway);
});
