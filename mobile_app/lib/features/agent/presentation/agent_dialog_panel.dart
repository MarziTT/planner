import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/butler/butler_name_provider.dart';
import '../../../core/butler/butler_persona.dart';
import '../../../core/theme/theme_controller.dart';
import '../../planner/state/planner_controller.dart';
import '../domain/parse_result.dart';
import '../state/agent_notifier.dart';
import 'chat_bubble.dart';

class AgentDialogPanel extends ConsumerStatefulWidget {
  const AgentDialogPanel({
    super.key,
    this.embedded = false,
    this.onOpenModules,
  });

  final bool embedded;
  final VoidCallback? onOpenModules;

  @override
  ConsumerState<AgentDialogPanel> createState() => _AgentDialogPanelState();
}

class _AgentDialogPanelState extends ConsumerState<AgentDialogPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _confirming = false;
  final List<_QuickCommand> _quickCommands = [
    _QuickCommand(Icons.calendar_month_outlined, '明天有什么安排', '明天有什么安排'),
    _QuickCommand(Icons.restaurant_outlined, '记录早餐', '记录早餐'),
    _QuickCommand(Icons.fitness_center_outlined, '记一笔运动', '记一笔运动'),
    _QuickCommand(Icons.bedtime_outlined, '记录昨晚作息', '记录昨晚作息'),
    _QuickCommand(Icons.notifications_outlined, '提醒我喝水', '每小时提醒我喝水'),
    _QuickCommand(Icons.add_task_outlined, '安排一个日程', '明天下午三点开会'),
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleInputChanged);
    _loadQuickCommands();
  }

  static const _quickCommandsKey = 'agent.quick_commands.v1';

  Future<void> _loadQuickCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_quickCommandsKey);
    if (!mounted || raw == null) return;
    final loaded = raw
        .where((value) => value.trim().isNotEmpty)
        .map((value) => _QuickCommand(Icons.bolt_outlined, value, value))
        .toList();
    if (loaded.isNotEmpty) setState(() { _quickCommands..clear()..addAll(loaded); });
  }

  @override
  void dispose() {
    _textController.removeListener(_handleInputChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
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
    final topRadius = widget.embedded ? Radius.zero : const Radius.circular(20);

    _scrollToBottom();

    return Container(
      height: widget.embedded ? null : screenHeight * 0.6,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: topRadius,
          topRight: topRadius,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        borderRadius: BorderRadius.only(
          topLeft: widget.embedded ? Radius.zero : const Radius.circular(20),
          topRight: widget.embedded ? Radius.zero : const Radius.circular(20),
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
            '对话',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (!widget.embedded)
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

  Future<void> _handleQuickCommand(String text) async {
    final state = ref.read(agentControllerProvider);
    if (state.status == AgentStatus.recognizing ||
        state.status == AgentStatus.parsing ||
        state.status == AgentStatus.confirming) {
      return;
    }
    await ref.read(agentControllerProvider.notifier).submitText(text);
    _scrollToBottom();
  }

  Widget _buildEmptyState(bool isZzz, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final primary = isZzz ? colorScheme.primary : colorScheme.primary;
    final persona = ButlerPersona.forTheme(
      ref.watch(themeControllerProvider).preset,
    );
    final savedName = ref.watch(butlerNameProvider);
    final butlerName =
        savedName == kDefaultButlerName ? persona.displayName : savedName;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.psychology_outlined, size: 36, color: primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${persona.greeting} 我是$butlerName',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '日程、饮食、运动、作息、提醒，一句话交给我。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                '快捷指令',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '编辑快捷指令',
              onPressed: _editQuickCommands,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final command in _quickCommands)
              _QuickCommandChip(
                icon: command.icon,
                label: command.label,
                onTap: () => _handleQuickCommand(command.prompt),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '点一下快捷指令，或直接用语音告诉我',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _editQuickCommands() async {
    final updated = await showDialog<List<_QuickCommand>>(
      context: context,
      builder: (context) => _QuickCommandEditor(commands: _quickCommands),
    );
    if (updated != null && mounted) {
      setState(() { _quickCommands..clear()..addAll(updated); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _quickCommandsKey,
        _quickCommands.map((command) => command.prompt).toList(),
      );
    }
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
        child: isListening
            ? _buildListeningBar(isZzz, theme, colorScheme)
            : Row(
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
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
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
                    onPressed:
                        canInteract && _textController.text.trim().isNotEmpty
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

  Widget _buildListeningBar(
      bool isZzz, ThemeData theme, ColorScheme colorScheme) {
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
        backgroundColor: isListening ? colorScheme.error : colorScheme.primary,
        foregroundColor:
            isListening ? colorScheme.onError : colorScheme.onPrimary,
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _QuickCommandChip extends StatelessWidget {
  const _QuickCommandChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCommand {
  const _QuickCommand(this.icon, this.label, this.prompt);
  final IconData icon;
  final String label;
  final String prompt;
}

class _QuickCommandEditor extends StatefulWidget {
  const _QuickCommandEditor({required this.commands});
  final List<_QuickCommand> commands;

  @override
  State<_QuickCommandEditor> createState() => _QuickCommandEditorState();
}

class _QuickCommandEditorState extends State<_QuickCommandEditor> {
  late final List<_QuickCommand> _commands = [...widget.commands];

  Future<void> _add() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增快捷指令'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: '输入要执行的指令')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('添加'))],
      ),
    );
    if (value != null && value.isNotEmpty) setState(() => _commands.add(_QuickCommand(Icons.bolt_outlined, value, value)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑快捷指令'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: _commands.isEmpty
            ? const Center(child: Text('还没有快捷指令'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _commands.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  leading: Icon(_commands[index].icon),
                  title: Text(_commands[index].label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _commands.removeAt(index)),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _add, child: const Text('新增')),
        FilledButton(onPressed: () => Navigator.pop(context, _commands), child: const Text('完成')),
      ],
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
