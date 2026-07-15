import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../planner/data/planner_repository.dart';
import '../../planner/state/planner_controller.dart';
import '../data/speech_capture_gateway.dart';
import '../domain/capture_enums.dart';
import '../domain/parsed_schedule_draft.dart';
import '../state/fast_capture_controller.dart';

const _sheetTitle =
    '\u8fd9\u4e2a\u65f6\u95f4\u9700\u8981\u786e\u8ba4\u4e00\u4e0b';
const _morningPrefix = '\u65e9\u4e0a';
const _afternoonPrefix = '\u4e0b\u5348';
const _cancelLabel = '\u53d6\u6d88';
const _missingMorningChoice = '上午 9:00';
const _missingAfternoonChoice = '下午 3:00';
const _missingEveningChoice = '晚上 7:00';
const _missingAllDayChoice = '全天提醒';
const _pendingLabel = '\u8bf7\u5148\u786e\u8ba4\u65f6\u95f4';
const _composerTitle = '\u5feb\u901f\u8bb0\u4e00\u6761\u884c\u7a0b';
const _clearTooltip = '\u6e05\u7a7a';
const _hintText =
    '\u6bd4\u5982\uff1a\u4eca\u5929\u4e03\u70b9\u53bb\u5065\u8eab / \u660e\u5929\u4e94\u70b9\u7684\u98de\u673a';
const _stopRecording = '\u505c\u6b62\u5f55\u97f3';
const _startRecording = '\u8bed\u97f3\u5f55\u5165';
const _confirmLabel = '\u786e\u8ba4';
const _listeningHint = '正在录音，说完点一下停止，系统会自动识别并写入速记。';
const _recognizingHint = '正在识别语音并整理行程...';
const _ambiguousHint =
    '\u68c0\u6d4b\u5230\u65f6\u95f4\u6709\u6b67\u4e49\uff0c\u5148\u786e\u8ba4\u65e9\u4e0a\u8fd8\u662f\u4e0b\u5348\u3002';
const _defaultHint =
    '\u4e00\u53e5\u8bdd\u5c31\u80fd\u8bb0\u4e0b\u6765\uff0c\u7cfb\u7edf\u4f1a\u5c3d\u91cf\u5e2e\u4f60\u8865\u9f50\u65f6\u95f4\u3002';

final fastCaptureControllerProvider =
    StateNotifierProvider<FastCaptureController, FastCaptureState>(
  (ref) => FastCaptureController(
    repository: ref.watch(plannerRepositoryProvider),
    speechGateway: SpeechCaptureGateway(
      remoteAsrClient: RemoteAsrClient(ref.watch(apiClientProvider)),
    ),
  ),
);

Future<void> showCaptureAmbiguitySheet(
  BuildContext context, {
  required ParsedScheduleDraft draft,
  required VoidCallback onMorning,
  required VoidCallback onAfternoon,
  required VoidCallback onCancel,
  VoidCallback? onMissingMorning,
  VoidCallback? onMissingAfternoon,
  VoidCallback? onMissingEvening,
  VoidCallback? onMissingAllDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                draft.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (draft.ambiguityKind == TimeAmbiguityKind.missingTime) ...[
                _PeriodChoiceTile(
                  label: _missingMorningChoice,
                  recommended: draft.suggestedPeriod == TimePeriod.morning,
                  onTap: onMissingMorning,
                ),
                _PeriodChoiceTile(
                  label: _missingAfternoonChoice,
                  recommended: draft.suggestedPeriod == TimePeriod.afternoon,
                  onTap: onMissingAfternoon,
                ),
                _PeriodChoiceTile(
                  label: _missingEveningChoice,
                  recommended: draft.suggestedPeriod == TimePeriod.evening,
                  onTap: onMissingEvening,
                ),
                _PeriodChoiceTile(
                  label: _missingAllDayChoice,
                  recommended: draft.suggestedPeriod == TimePeriod.allDay,
                  onTap: onMissingAllDay,
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('$_morningPrefix ${draft.ambiguousHour}:00'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onMorning();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('$_afternoonPrefix ${draft.ambiguousHour}:00'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onAfternoon();
                  },
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel();
                },
                child: const Text(_cancelLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PeriodChoiceTile extends StatelessWidget {
  const _PeriodChoiceTile({
    required this.label,
    required this.recommended,
    required this.onTap,
  });

  final String label;
  final bool recommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: recommended ? const Text('推荐') : null,
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
    );
  }
}

class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleComposerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final state = ref.read(fastCaptureControllerProvider);
    if (text.isEmpty || state.isSubmitting || state.pendingDraft != null) {
      return;
    }
    await ref.read(fastCaptureControllerProvider.notifier).submitText(text);
  }

  Future<void> _toggleMic() async {
    final state = ref.read(fastCaptureControllerProvider);
    final controller = ref.read(fastCaptureControllerProvider.notifier);
    if (state.pendingDraft != null ||
        state.isSubmitting ||
        state.isRecognizing) {
      return;
    }
    if (state.isListening) {
      await controller.stopListening();
    } else {
      await controller.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FastCaptureState>(fastCaptureControllerProvider,
        (previous, next) {
      final resolvedPending = previous?.pendingDraft != null &&
          next.pendingDraft == null &&
          next.errorMessage == null;
      final completedDirectSubmit = previous?.isSubmitting == true &&
          next.isSubmitting == false &&
          next.pendingDraft == null &&
          next.errorMessage == null;

      if (resolvedPending || completedDirectSubmit) {
        final message = completedDirectSubmit ? '已添加到日程' : '已保存行程';
        _controller.clear();
        _focusNode.unfocus();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        Future.microtask(
          () => ref.read(plannerControllerProvider.notifier).loadDashboard(),
        );
      }
    });

    final state = ref.watch(fastCaptureControllerProvider);
    final theme = Theme.of(context);
    final canInteract = !state.isSubmitting &&
        !state.isRecognizing &&
        state.pendingDraft == null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: state.pendingDraft != null
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.pendingDraft != null ? _pendingLabel : _composerTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (_controller.text.trim().isNotEmpty)
                IconButton(
                  tooltip: _clearTooltip,
                  onPressed: state.isSubmitting ? null : _controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: canInteract,
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: _hintText,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: state.isRecognizing
                    ? _recognizingHint
                    : state.isListening
                        ? _stopRecording
                        : _startRecording,
                style: IconButton.styleFrom(
                  backgroundColor: state.isListening
                      ? theme.colorScheme.error
                      : state.isRecognizing
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.secondaryContainer,
                  foregroundColor: state.isListening
                      ? theme.colorScheme.onError
                      : state.isRecognizing
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                ),
                onPressed: state.isRecognizing
                    ? null
                    : canInteract || state.isListening
                        ? _toggleMic
                        : null,
                icon: state.isRecognizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        state.isListening
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                      ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canInteract ? _submit : null,
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
                label: const Text(_confirmLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.isRecognizing
                ? _recognizingHint
                : state.isListening
                    ? _listeningHint
                    : state.pendingDraft != null
                        ? state.pendingDraft!.ambiguityKind ==
                                TimeAmbiguityKind.missingTime
                            ? '还没听到具体时间，选一个大概时段就能保存。'
                            : _ambiguousHint
                        : _defaultHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.isRecognizing) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ],
          if (state.recognizedText != null &&
              state.recognizedText!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '识别到：${state.recognizedText}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
