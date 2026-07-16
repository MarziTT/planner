import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../fast_capture/domain/capture_enums.dart';
import '../../fast_capture/presentation/quick_capture_bar.dart';
import '../../fast_capture/state/fast_capture_controller.dart';
import '../../notifications/data/reminder_gateway.dart';
import '../../notifications/domain/notification_tap_event.dart';
import '../../planner/presentation/planner_dashboard.dart';
import '../../planner/state/planner_controller.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/domain/settings_model.dart';
import '../../settings/presentation/settings_page.dart';
import '../../settings/state/settings_controller.dart';
import '../../tags/presentation/tags_page.dart';
import '../../updates/presentation/update_banner.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  StreamSubscription<NotificationTapEvent>? _tapSubscription;
  bool _initialDashboardLoadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() {
      final settingsState = ref.read(settingsControllerProvider);
      if (settingsState.settings == null && !settingsState.loading) {
        ref.read(settingsControllerProvider.notifier).load();
      }
      _ensureDashboardLoadedForSession();

      final gateway = ref.read(reminderGatewayProvider);
      _tapSubscription = gateway.taps.listen(_onNotificationTap);

      gateway.getLaunchTap().then((tap) {
        if (tap != null) {
          _onNotificationTap(tap);
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncReminderSchedules(
        ref.read(plannerControllerProvider),
        ref.read(settingsControllerProvider).settings,
      );
    }
  }

  void _onNotificationTap(NotificationTapEvent event) {
    if (event.eventId != null) {
      ref.read(selectedPlannerEventIdProvider.notifier).state = event.eventId;
    }
    if (mounted) {
      setState(() => currentIndex = 0);
      if (event.openQuickCapture) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已打开速记，可以直接新增行程')),
        );
      }
    }
  }

  void _ensureDashboardLoadedForSession() {
    if (_initialDashboardLoadRequested) return;
    final authState = ref.read(authControllerProvider);
    if (authState.session == null || authState.restoring) return;
    _initialDashboardLoadRequested = true;
    ref.read(plannerControllerProvider.notifier).loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.session;
      final nextSession = next.session;
      if (previousSession == null && nextSession != null) {
        _initialDashboardLoadRequested = true;
        ref.read(plannerControllerProvider.notifier).loadDashboard();
      }
      if (previousSession != null && nextSession == null) {
        _initialDashboardLoadRequested = false;
        ref.read(plannerControllerProvider.notifier).markLoggedOut();
      }
    });

    ref.listen(fastCaptureControllerProvider, (previous, next) {
      final pendingDraft = next.pendingDraft;
      if (pendingDraft != null && previous?.pendingDraft != pendingDraft) {
        showCaptureAmbiguitySheet(
          context,
          draft: pendingDraft,
          onMorning: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmAmbiguousHour(
                  pendingDraft.ambiguousHour ?? pendingDraft.startsAt.hour,
                );
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onAfternoon: () async {
            final hour =
                pendingDraft.ambiguousHour ?? pendingDraft.startsAt.hour;
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmAmbiguousHour(hour < 12 ? hour + 12 : hour);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onCancel: () {
            ref
                .read(fastCaptureControllerProvider.notifier)
                .cancelPendingDraft();
          },
          onMissingMorning: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.morning);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingAfternoon: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.afternoon);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingEvening: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.evening);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
          onMissingAllDay: () async {
            await ref
                .read(fastCaptureControllerProvider.notifier)
                .confirmMissingTime(TimePeriod.allDay);
            await ref.read(plannerControllerProvider.notifier).loadDashboard();
          },
        );
      }

      final errorMessage = next.errorMessage;
      if (errorMessage != null &&
          errorMessage != previous?.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    });

    ref.listen(plannerControllerProvider, (previous, next) {
      _syncReminderSchedules(
          next, ref.read(settingsControllerProvider).settings);
    });

    ref.listen(settingsControllerProvider, (previous, next) {
      _syncReminderSchedules(
          ref.read(plannerControllerProvider), next.settings);
    });

    const pages = [
      PlannerDashboard(),
      TagsPage(),
      ProfilePage(),
      SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowDay 日程'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          if (currentIndex == 0) const QuickCaptureBar(),
          Expanded(child: pages[currentIndex]),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickCaptureSheet(context),
        onLongPress: () => _onFabLongPress(),
        tooltip: '快速速记',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.bolt),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) => setState(() => currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: '计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            label: '标签',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '账号',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _syncReminderSchedules(
      PlannerState plannerState, PlannerSettings? settings) {
    if (settings == null) return;
    ref.read(reminderCoordinatorProvider).sync(
          events: plannerState.events,
          settings: settings,
        );
  }

  void _onFabLongPress() {
    final state = ref.read(fastCaptureControllerProvider);
    if (state.isListening || state.isSubmitting || state.isRecognizing) {
      return;
    }
    ref.read(fastCaptureControllerProvider.notifier).startListening();
  }

  void _showQuickCaptureSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _QuickCaptureSheet(),
    );
  }
}

class _QuickCaptureSheet extends ConsumerStatefulWidget {
  const _QuickCaptureSheet();

  @override
  ConsumerState<_QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<_QuickCaptureSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final state = ref.read(fastCaptureControllerProvider);
    if (text.isEmpty ||
        state.isSubmitting ||
        state.isRecognizing ||
        state.pendingDraft != null) {
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
        _controller.clear();
        _focusNode.unfocus();
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(completedDirectSubmit ? '已添加到日程' : '已保存行程')),
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    state.pendingDraft != null ? '请先确认时间' : '快速记一条行程',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_controller.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: '清空',
                    onPressed: state.isSubmitting ? null : _controller.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.isListening)
              _SheetListeningIndicator(
                partialText: state.partialText,
                onStop: _toggleMic,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: canInteract,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: '比如：今天七点去健身 / 明天五点的飞机',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: state.isRecognizing
                        ? '正在识别语音并整理行程...'
                        : state.isListening
                            ? '停止录音'
                            : '语音录入',
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
                    label: const Text('确认'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              state.isRecognizing
                  ? '正在识别语音并整理行程...'
                  : state.isListening
                      ? '正在录音，说完点一下停止，系统会自动识别并写入速记。'
                      : state.pendingDraft != null
                          ? state.pendingDraft!.ambiguityKind ==
                                  TimeAmbiguityKind.missingTime
                              ? '还没听到具体时间，选一个大概时段就能保存。'
                              : '检测到时间有歧义，先确认早上还是下午。'
                          : '一句话就能记下来，系统会尽量帮你补齐时间。',
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
      ),
    );
  }
}

class _SheetListeningIndicator extends StatelessWidget {
  const _SheetListeningIndicator({
    required this.partialText,
    required this.onStop,
  });

  final String? partialText;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partialText != null && partialText!.trim().isNotEmpty
                    ? partialText!
                    : '正在录音，说完点一下停止，系统会自动识别并写入速记。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: partialText != null && partialText!.trim().isNotEmpty
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontStyle: partialText != null && partialText!.trim().isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const _SheetAudioWaveform(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: '停止录音',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
        ),
      ],
    );
  }
}

class _SheetAudioWaveform extends StatefulWidget {
  const _SheetAudioWaveform();

  @override
  State<_SheetAudioWaveform> createState() => _SheetAudioWaveformState();
}

class _SheetAudioWaveformState extends State<_SheetAudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final t = (_animController.value + i * 0.2) % 1.0;
            final height = 6.0 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 14;
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

