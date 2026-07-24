import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../planner/state/planner_controller.dart';
import '../domain/parse_result.dart';
import '../state/agent_notifier.dart';
import 'chat_bubble.dart';

class AgentDialogPanel extends ConsumerStatefulWidget {
  const AgentDialogPanel({super.key});

  @override
  ConsumerState<AgentDialogPanel> createState() => _AgentDialogPanelState();
}

class _AgentDialogPanelState extends ConsumerState<AgentDialogPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _confirming = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isLoadingStatus(AgentStatus status) {
    return status == AgentStatus.recognizing || status == AgentStatus.parsing;
  }

  String _loadingText(AgentStatus status) {
    switch (status) {
      case AgentStatus.recognizing:
        return '正在识别语音...';
      case AgentStatus.parsing:
      default:
        return '正在解析...';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final state = ref.read(agentControllerProvider);
    if (state.status == AgentStatus.recognizing ||
        state.status == AgentStatus.parsing ||
        state.status == AgentStatus.confirming) {
      return;
    }

    _textController.clear();
    await ref.read(agentControllerProvider.notifier).submitText(text);
    _scrollToBottom();
  }

  Future<void> _handleMicPress() async {
    final currentState = ref.read(agentControllerProvider);
    if (currentState.status == AgentStatus.recognizing ||
        currentState.status == AgentStatus.parsing ||
        currentState.status == AgentStatus.confirming) {
      return;
    }

    if (currentState.status == AgentStatus.listening) {
      await ref.read(agentControllerProvider.notifier).stopListening();
      _scrollToBottom();
    } else {
      ref.read(agentControllerProvider.notifier).startListening();
    }
  }

  Future<void> _handleConfirm() async {
    final state = ref.read(agentControllerProvider);
    if (state.status != AgentStatus.confirming || _confirming) return;

    final messages = state.messages;
    ParseResult? lastResult;
    for (final msg in messages.reversed) {
      if (msg.type == ChatMessageType.confirmCard) {
        lastResult = msg.parseResult;
        break;
      }
    }

    if (lastResult == null) return;

    setState(() => _confirming = true);
    try {
      final success = await ref
          .read(agentControllerProvider.notifier)
          .confirmAction(lastResult);
      _scrollToBottom();

      if (success) {
        // Refresh relevant data based on intent
        await _refreshAfterConfirm(lastResult);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_confirmSnackBarText(lastResult))),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _refreshAfterConfirm(ParseResult result) async {
    final plannerCtrl = ref.read(plannerControllerProvider.notifier);
    switch (result.intent) {
      case 'create_event':
      case 'create_reminder':
        await plannerCtrl.loadDashboard();
      default:
        // meal/exercise/routine don't need dashboard refresh
        break;
    }
  }

  String _confirmSnackBarText(ParseResult r) {
    switch (r.intent) {
      case 'log_meal':
        return '已记录饮食';
      case 'log_exercise':
        return '已记录运动';
      case 'log_routine':
        return '已记录作息';
      case 'create_reminder':
        return '已创建提醒';
      default:
        return '已安排';
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentControllerProvider);
    final themeState = ref.watch(themeControllerProvider);
    final isZzz = themeState.preset == PlannerThemePreset.kamenRiderZzz;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screenHeight = MediaQuery.of(context).size.height;

    _scrollToBottom();

    return Container(
      height: screenHeight * 0.6,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(isZzz, colorScheme, theme),
          Expanded(
            child: agentState.messages.isEmpty &&
                    !_isLoadingStatus(agentState.status)
                ? _buildEmptyState(isZzz, theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: agentState.messages.length +
                        (_isLoadingStatus(agentState.status) ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == agentState.messages.length &&
                          _isLoadingStatus(agentState.status)) {
                        return ChatBubble(
                          message: ChatMessage(
                            id: '_loading_placeholder',
                            type: ChatMessageType.system,
                            text: _loadingText(agentState.status),
                            isParsing: true,
                          ),
                          isZzz: isZzz,
                        );
                      }

                      final msg = agentState.messages[index];
                      final isLastConfirm =
                          msg.type == ChatMessageType.confirmCard &&
                              agentState.status == AgentStatus.confirming &&
                              index == agentState.messages.length - 1;

                      return ChatBubble(
                        message: msg,
                        isZzz: isZzz,
                        onConfirm: isLastConfirm ? _handleConfirm : null,
                        onConfirmResult: msg.parseResult,
                      );
                    },
                  ),
          ),
          _buildInputArea(
            agentState,
            isZzz,
            theme,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isZzz, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 20,
            color: isZzz ? colorScheme.primary : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '贾维斯管家',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ref.read(agentControllerProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.keyboard_arrow_down,
                color: colorScheme.onSurfaceVariant),
            tooltip: '收起',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isZzz, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            '对我说一句话，日程就安排好了',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '比如："明天下午三点跟老王开会"',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    AgentState agentState,
    bool isZzz,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isListening = agentState.status == AgentStatus.listening;
    final isRecognizing = agentState.status == AgentStatus.recognizing;
    final isParsing = agentState.status == AgentStatus.parsing;
    final isConfirming = agentState.status == AgentStatus.confirming;
    final canInteract = !isRecognizing && !isParsing && !isConfirming;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: isListening ? _buildListeningBar(isZzz, theme, colorScheme) : Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: canInteract,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                cursorColor: isZzz ? colorScheme.primary : null,
                style: TextStyle(color: colorScheme.onSurface),
                onSubmitted: (_) => _handleSubmitText(),
                decoration: InputDecoration(
                  hintText: '打字输入你想做的...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MicButton(
              isListening: isListening,
              canInteract: canInteract,
              isZzz: isZzz,
              onTap: _handleMicPress,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: canInteract &&
                      _textController.text.trim().isNotEmpty
                  ? _handleSubmitText
                  : null,
              icon: const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningBar(bool isZzz, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(
                  '正在聆听...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _MicButton(
          isListening: true,
          canInteract: true,
          isZzz: isZzz,
          onTap: _handleMicPress,
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isListening,
    required this.canInteract,
    required this.isZzz,
    required this.onTap,
  });

  final bool isListening;
  final bool canInteract;
  final bool isZzz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: canInteract ? onTap : null,
      icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
          size: 22),
      style: IconButton.styleFrom(
        backgroundColor: isListening
            ? colorScheme.error
            : colorScheme.primary,
        foregroundColor: isListening
            ? colorScheme.onError
            : colorScheme.onPrimary,
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

