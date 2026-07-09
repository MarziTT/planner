import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/data/planner_repository.dart';
import '../../planner/state/planner_controller.dart';
import '../data/speech_capture_gateway.dart';
import '../domain/parsed_schedule_draft.dart';
import '../state/fast_capture_controller.dart';

final fastCaptureControllerProvider =
    StateNotifierProvider<FastCaptureController, FastCaptureState>(
  (ref) => FastCaptureController(
    repository: ref.watch(plannerRepositoryProvider),
    speechGateway: SpeechCaptureGateway(),
  ),
);

Future<void> showCaptureAmbiguitySheet(
  BuildContext context, {
  required ParsedScheduleDraft draft,
  required VoidCallback onMorning,
  required VoidCallback onAfternoon,
  required VoidCallback onCancel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这个时间需要确认一下',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              draft.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('早上 ${draft.ambiguousHour}:00'),
              onTap: () {
                Navigator.of(context).pop();
                onMorning();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('下午 ${draft.ambiguousHour}:00'),
              onTap: () {
                Navigator.of(context).pop();
                onAfternoon();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel();
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ),
  );
}

class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(fastCaptureControllerProvider.notifier).submitText(text);
    final state = ref.read(fastCaptureControllerProvider);
    if (state.pendingDraft == null && state.errorMessage == null) {
      _controller.clear();
      await ref.read(plannerControllerProvider.notifier).loadDashboard();
    }
  }

  Future<void> _toggleMic() async {
    final controller = ref.read(fastCaptureControllerProvider.notifier);
    if (ref.read(fastCaptureControllerProvider).isListening) {
      await controller.stopListening();
    } else {
      await controller.startListening();
      final state = ref.read(fastCaptureControllerProvider);
      if (state.pendingDraft == null && state.errorMessage == null) {
        await ref.read(plannerControllerProvider.notifier).loadDashboard();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fastCaptureControllerProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '比如：今天下午七点去健身',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: state.isListening ? '停止录音' : '语音录入',
              onPressed: _toggleMic,
              icon: Icon(state.isListening ? Icons.mic : Icons.mic_none_rounded),
              color: state.isListening
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            if (state.isListening)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '正在聆听...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _submit,
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }
}
