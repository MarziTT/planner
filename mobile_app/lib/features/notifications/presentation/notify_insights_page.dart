import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/smart_notify_models.dart';
import '../state/smart_notify_provider.dart';

/// Smart notification dashboard — P3-F3.
///
/// Tab 1: Insights — AI-generated notification suggestions
/// Tab 2: History — past notification events
class NotifyInsightsPage extends ConsumerStatefulWidget {
  const NotifyInsightsPage({super.key});

  @override
  ConsumerState<NotifyInsightsPage> createState() => _NotifyInsightsPageState();
}

class _NotifyInsightsPageState extends ConsumerState<NotifyInsightsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(smartNotifyProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartNotifyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能通知'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '智能建议', icon: Icon(Icons.lightbulb_outline, size: 20)),
            Tab(text: '通知历史', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InsightsTab(state: state, theme: theme),
          _HistoryTab(state: state, theme: theme),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tab 1: Insights
// ═══════════════════════════════════════════════════════════════════════════

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab({required this.state, required this.theme});

  final SmartNotifyState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingInsights && state.insights == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.insights == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(state.errorMessage!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                ref.read(smartNotifyProvider.notifier).loadInsights();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final insights = state.insights;
    if (insights == null || insights.insights.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('一切正常', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('当前没有需要关注的智能建议',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                )),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(smartNotifyProvider.notifier).loadInsights();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: insights.insights.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '共 ${insights.count} 条建议',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            );
          }
          return _InsightCard(
            insight: insights.insights[index - 1],
            theme: theme,
          );
        },
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.theme});

  final NotifyInsight insight;
  final ThemeData theme;

  Color _priorityColor() {
    switch (insight.priority) {
      case 'high':
        return Colors.deepOrange;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(insight.icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          insight.priorityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: priorityColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tab 2: History
// ═══════════════════════════════════════════════════════════════════════════

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.state, required this.theme});

  final SmartNotifyState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingHistory && state.history == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.history == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                ref.read(smartNotifyProvider.notifier).loadHistory();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final history = state.history;
    if (history == null || history.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64,
                color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('暂无通知记录', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(smartNotifyProvider.notifier).loadHistory();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _StatChip(label: '总计', value: '${history.total}', color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  _StatChip(label: '已完成', value: '${history.completed}', color: Colors.green),
                  const SizedBox(width: 8),
                  _StatChip(label: '已跳过', value: '${history.skipped}', color: Colors.orange),
                ],
              ),
            );
          }
          return _HistoryEntryTile(
            entry: history.entries[index - 1],
            theme: theme,
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry, required this.theme});

  final NotifyHistoryEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.skipped
                ? Colors.orange.withValues(alpha: 0.12)
                : Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(entry.typeIcon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          entry.typeLabel,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatTime(entry.plannedTime),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: entry.skipped
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('已跳过',
                    style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              )
            : entry.completedAt != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('已完成',
                        style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                  )
                : const Text('待处理',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '--';
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '$month-$day $h:$m';
    } catch (_) {
      return iso;
    }
  }
}
