import 'package:flutter/material.dart';

import '../domain/parse_result.dart';
import '../state/agent_notifier.dart';
import 'confirm_card.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.isZzz = false,
    this.onConfirm,
    this.onConfirmResult,
  });

  final ChatMessage message;
  final bool isZzz;
  final VoidCallback? onConfirm;
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

class _ConfirmCardBubble extends StatelessWidget {
  const _ConfirmCardBubble({
    required this.result,
    this.isZzz = false,
    this.onConfirm,
  });

  final ParseResult? result;
  final bool isZzz;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConfirmCard(
            result: result!,
            isZzz: isZzz,
            onConfirm: onConfirm ?? () {},
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
