import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scheduler/data/scheduler_repository.dart';
import '../../scheduler/domain/scheduler_models.dart';
import '../domain/parse_result.dart';
import '../state/agent_notifier.dart';
import 'confirm_card.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.isZzz = false,
    this.onConfirm,
    this.onCancel,
    this.onEdit,
    this.onConfirmResult,
  });

  final ChatMessage message;
  final bool isZzz;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final ValueChanged<ParseResult>? onEdit;
  final ParseResult? onConfirmResult;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case ChatMessageType.user:
        return _UserBubble(text: message.text, isZzz: isZzz);
      case ChatMessageType.system:
        return _SystemBubble(
          text: message.text,
          isZzz: isZzz,
          isLoading: message.isParsing,
        );
      case ChatMessageType.confirmCard:
        return _ConfirmCardBubble(
          result: onConfirmResult ?? message.parseResult,
          isZzz: isZzz,
          onConfirm: onConfirm,
          onCancel: onCancel,
          onEdit: onEdit,
        );
      case ChatMessageType.answerCard:
        return _AnswerCardBubble(
          result: onConfirmResult ?? message.parseResult,
          text: message.text,
          isZzz: isZzz,
        );
      case ChatMessageType.error:
        return _ErrorBubble(text: message.text, isZzz: isZzz);
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, this.isZzz = false});

  final String text;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({
    required this.text,
    this.isZzz = false,
    this.isLoading = false,
  });

  final String text;
  final bool isZzz;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCardBubble extends ConsumerStatefulWidget {
  const _ConfirmCardBubble({
    required this.result,
    this.isZzz = false,
    this.onConfirm,
    this.onCancel,
    this.onEdit,
  });

  final ParseResult? result;
  final bool isZzz;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final ValueChanged<ParseResult>? onEdit;

  @override
  ConsumerState<_ConfirmCardBubble> createState() => _ConfirmCardBubbleState();
}

class _ConfirmCardBubbleState extends ConsumerState<_ConfirmCardBubble> {
  ConflictCheck? _conflicts;
  List<TimeSuggestion>? _suggestions;
  bool _isChecking = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkConflicts();
  }

  @override
  void didUpdateWidget(covariant _ConfirmCardBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _conflicts = null;
      _suggestions = null;
      _checked = false;
      _checkConflicts();
    }
  }

  Future<void> _checkConflicts() async {
    final result = widget.result;
    if (result == null ||
        result.intent != 'create_event' ||
        result.datetimeStart == null ||
        result.datetimeEnd == null ||
        _checked) {
      return;
    }
    _checked = true;

    if (!mounted) return;
    setState(() => _isChecking = true);

    try {
      final repo = ref.read(schedulerRepositoryProvider);

      // Check conflicts for the parsed time range
      final conflicts = await repo.checkConflicts(
        startsAt: result.datetimeStart!.toIso8601String(),
        endsAt: result.datetimeEnd!.toIso8601String(),
      );

      if (!mounted) return;

      // If conflicts found, also get suggestions
      List<TimeSuggestion>? suggestions;
      if (conflicts.hasConflicts) {
        final duration =
            result.datetimeEnd!.difference(result.datetimeStart!).inMinutes;
        try {
          final suggestion = await repo.suggest(
            date: _dateStr(result.datetimeStart!),
            durationMinutes: duration.clamp(15, 480),
          );
          suggestions = suggestion.suggestions;
        } catch (_) {
          // Suggestions are best-effort
        }
      }

      if (!mounted) return;
      setState(() {
        _conflicts = conflicts;
        _suggestions = suggestions;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChecking = false);
    }
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    if (result == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConfirmCard(
            result: result,
            isZzz: widget.isZzz,
            onConfirm: widget.onConfirm ?? () {},
            onCancel: widget.onCancel,
            onEdit: widget.onEdit,
            conflicts: _conflicts,
            suggestions: _suggestions,
            isCheckingConflicts: _isChecking,
          ),
        ],
      ),
    );
  }
}

class _AnswerCardBubble extends StatelessWidget {
  const _AnswerCardBubble({
    required this.result,
    required this.text,
    this.isZzz = false,
  });

  final ParseResult? result;
  final String text;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('管家回复',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text(text,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text, this.isZzz = false});

  final String text;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
