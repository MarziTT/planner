import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../services/routine_service.dart';

/// Routine page — shows wake time distribution, today's routine timeline,
/// standing reminder toggle, and a manual wake-time entry.
class RoutinePage extends ConsumerStatefulWidget {
  const RoutinePage({super.key});

  @override
  ConsumerState<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends ConsumerState<RoutinePage> {
  bool _refreshing = false;
  bool _recordingWake = false;
  bool _settingWakeTime = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final service = ref.read(routineServiceProvider);
      await service.refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _onWakeTap() async {
    setState(() => _recordingWake = true);
    try {
      final service = ref.read(routineServiceProvider);
      final result = await service.recordWake();
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已记录起床 ${result['hour']}:${result['minute'].toString().padLeft(2, '0')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recordingWake = false);
    }
  }

  Future<void> _pickWakeTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5),
    );
    if (picked == null) return;

    setState(() => _settingWakeTime = true);
    try {
      final service = ref.read(routineServiceProvider);
      final ok = await service.setWakeTime(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('起床时间已设为 ${picked.format(context)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _settingWakeTime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(routineServiceProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_refreshing)
          LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Wake time card ---
        _SectionTitle(title: '起床时间', theme: theme),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${service.wakeHour.toString().padLeft(2, '0')}:${service.wakeMinute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '来源: ${_sourceLabel(service.wakeSource)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _recordingWake ? null : _onWakeTap,
                          icon: _recordingWake
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wb_sunny_outlined, size: 18),
                          label: Text(_recordingWake ? '记录中...' : '起床'),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: _settingWakeTime ? null : _pickWakeTime,
                          tooltip: '手动设置',
                          icon: _settingWakeTime
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.edit_calendar_outlined, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Today's timeline ---
        _SectionTitle(title: '今日作息', theme: theme),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _TimelineWidget(
          wakeHour: service.wakeHour,
          wakeMinute: service.wakeMinute,
          sleepHour: service.sleepHour,
          sleepMinute: service.sleepMinute,
          sleepRemindHour: service.sleepRemindHour,
          sleepRemindMinute: service.sleepRemindMinute,
        ),
          ),
        ),

        const SizedBox(height: 20),

        // --- Standing reminder ---
        _SectionTitle(title: '站立提醒', theme: theme),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  value: service.standingEnabled,
                  onChanged: (v) => service.toggleStanding(v),
                  title: const Text('每45分钟提醒站立'),
                  subtitle: Text(
                    service.standingAutoStopped
                        ? '已自动暂停（连续跳过5次）'
                        : '09:00 ~ 18:00',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                if (service.standingAutoStopped)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '连续跳过 ${service.consecutiveSkips} 次，已自动停止。'
                              '手动开启即可恢复。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '今日: 提醒 ${service.standingTotalToday} 次，跳过 ${service.standingSkippedToday} 次',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
            ), // ListView
          ), // RefreshIndicator
        ), // Expanded
      ], // Column children
    ); // Column
  }

  static String _sourceLabel(String source) {
    switch (source) {
      case 'learned':
        return 'AI 学习';
      case 'manual':
        return '手动设置';
      default:
        return '默认';
    }
  }
}

// ---------------------------------------------------------------------------
//  Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.theme});
  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Timeline widget
// ---------------------------------------------------------------------------

class _TimelineWidget extends StatelessWidget {
  const _TimelineWidget({
    required this.wakeHour,
    required this.wakeMinute,
    required this.sleepHour,
    required this.sleepMinute,
    required this.sleepRemindHour,
    required this.sleepRemindMinute,
  });

  final int wakeHour;
  final int wakeMinute;
  final int sleepHour;
  final int sleepMinute;
  final int sleepRemindHour;
  final int sleepRemindMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      _TimelineEntry(
        time: '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}',
        label: '起床',
        icon: Icons.wb_sunny_outlined,
        color: Colors.orange,
        isActive: true,
      ),
      _TimelineEntry(
        time: '${sleepRemindHour.toString().padLeft(2, '0')}:${sleepRemindMinute.toString().padLeft(2, '0')}',
        label: '入睡提醒',
        icon: Icons.nightlight_outlined,
        color: Colors.indigo,
        isActive: true,
      ),
      _TimelineEntry(
        time: '${sleepHour.toString().padLeft(2, '0')}:${sleepMinute.toString().padLeft(2, '0')}',
        label: '预计入睡',
        icon: Icons.bed_outlined,
        color: Colors.blueGrey,
        isActive: true,
      ),
    ];

    return Column(
      children: List.generate(items.length, (i) {
        final entry = items[i];
        final isLast = i == items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time column
              SizedBox(
                width: 64,
                child: Text(
                  entry.time,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              // Dot + line column
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: entry.color,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: entry.color.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
              // Label column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Icon(entry.icon, size: 18, color: entry.color),
                      const SizedBox(width: 8),
                      Text(
                        entry.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineEntry {
  final String time;
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _TimelineEntry({
    required this.time,
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
  });
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final routineServiceProvider = ChangeNotifierProvider<RoutineService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return RoutineService(dio: dio);
});
