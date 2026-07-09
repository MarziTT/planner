import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fitness/presentation/fitness_panel.dart';
import '../../profile/state/profile_controller.dart';
import '../domain/planner_models.dart';
import '../state/planner_controller.dart';

enum _TodoFilter { open, completed, all }

class PlannerDashboard extends ConsumerStatefulWidget {
  const PlannerDashboard({super.key});

  @override
  ConsumerState<PlannerDashboard> createState() => _PlannerDashboardState();
}

class _PlannerDashboardState extends ConsumerState<PlannerDashboard> {
  _TodoFilter _todoFilter = _TodoFilter.open;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final profileState = ref.read(profileControllerProvider);
      if (profileState.profile == null && !profileState.loading) {
        ref.read(profileControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final selectedEventId = ref.watch(selectedPlannerEventIdProvider);
    final profile = profileState.profile;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayEvents = state.eventsForDay(now);
    final upcomingEvents = state.upcomingEvents(now);
    final todos = switch (_todoFilter) {
      _TodoFilter.open => state.openTodos,
      _TodoFilter.completed => state.completedTodos,
      _TodoFilter.all => state.todos,
    };
    final workModeActive = profile?.identity == 'worker' &&
        (profile?.isScheduleActiveAt(now) ?? false);

    final highlightedEvent = selectedEventId != null
        ? todayEvents.cast<PlannerEvent?>().firstWhere(
              (e) => e!.id == selectedEventId,
              orElse: () => null,
            )
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(plannerControllerProvider.notifier).loadDashboard();
        await ref.read(profileControllerProvider.notifier).load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(),
            ),
          if (highlightedEvent != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('从提醒返回', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      highlightedEvent.title,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日总览', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    '把今天的行程、待办和阶段重点收在同一个工作台里。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(label: '今日行程', value: '${todayEvents.length}'),
                      _MetricChip(label: '待办', value: '${state.openTodos.length}'),
                      _MetricChip(label: '已完成', value: '${state.completedTodos.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (profile != null) ...[
            const SizedBox(height: 16),
            _ProfileRhythmCard(profile: profile),
          ],
          if (workModeActive) ...[
            const SizedBox(height: 16),
            _WorkModeCard(todos: state.openTodos.take(3).toList()),
          ],
          if (profile?.wantsFitness ?? false) ...[
            const SizedBox(height: 16),
            FitnessPanel(
              modeLabel: profile!.fitnessModeLabel,
              goal: profile.fitnessGoal,
            ),
          ],
          const SizedBox(height: 16),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          _SectionHeader(
            title: '今日日程',
            actionLabel: '新增',
            onAction: () => _showEventEditor(context: context),
          ),
          const SizedBox(height: 8),
          if (todayEvents.isEmpty)
            const _EmptyCard(message: '今天还没有安排，先把最重要的一件事放进来。'),
          ...todayEvents.map(
            (event) => _EventTile(
              event: event,
              onEdit: () => _showEventEditor(context: context, event: event),
              onDelete: () => ref.read(plannerControllerProvider.notifier).removeEvent(event.id),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: '后续安排',
            actionLabel: '刷新',
            onAction: () => ref.read(plannerControllerProvider.notifier).loadDashboard(),
          ),
          const SizedBox(height: 8),
          if (upcomingEvents.isEmpty)
            const _EmptyCard(message: '后续安排还是空的，适合把这周的关键节点先排进去。'),
          ...upcomingEvents.map(
            (event) => _EventTile(
              event: event,
              onEdit: () => _showEventEditor(context: context, event: event),
              onDelete: () => ref.read(plannerControllerProvider.notifier).removeEvent(event.id),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('待办', style: theme.textTheme.titleMedium),
              ),
              SegmentedButton<_TodoFilter>(
                segments: const [
                  ButtonSegment(value: _TodoFilter.open, label: Text('待处理')),
                  ButtonSegment(value: _TodoFilter.completed, label: Text('已完成')),
                  ButtonSegment(value: _TodoFilter.all, label: Text('全部')),
                ],
                selected: {_todoFilter},
                onSelectionChanged: (value) => setState(() => _todoFilter = value.first),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showTodoEditor(context: context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (todos.isEmpty)
            const _EmptyCard(message: '这个分组里还没有待办，先加一条最具体的动作。'),
          ...todos.map(
            (todo) => _TodoTile(
              todo: todo,
              onEdit: () => _showTodoEditor(context: context, todo: todo),
              onDelete: () => ref.read(plannerControllerProvider.notifier).removeTodo(todo.id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEventEditor({
    required BuildContext context,
    PlannerEvent? event,
  }) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    var startsAt = event?.startsAt ?? DateTime.now().add(const Duration(minutes: 30));
    var endsAt = event?.endsAt ?? startsAt.add(const Duration(hours: 1));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(event == null ? '新增行程' : '编辑行程'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                const SizedBox(height: 12),
                _DateTimeField(
                  label: '开始时间',
                  value: startsAt,
                  onChanged: (value) => setLocalState(() => startsAt = value),
                ),
                const SizedBox(height: 12),
                _DateTimeField(
                  label: '结束时间',
                  value: endsAt,
                  onChanged: (value) => setLocalState(() => endsAt = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    final title = titleController.text.trim();
    if (saved != true || title.isEmpty || !endsAt.isAfter(startsAt)) return;

    final notifier = ref.read(plannerControllerProvider.notifier);
    if (event == null) {
      await notifier.addQuickEvent(
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      return;
    }

    await notifier.updateEventSchedule(
      event: event,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  Future<void> _showTodoEditor({
    required BuildContext context,
    PlannerTodo? todo,
  }) async {
    final controller = TextEditingController(text: todo?.title ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(todo == null ? '新增待办' : '编辑待办'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final notifier = ref.read(plannerControllerProvider.notifier);
    if (todo == null) {
      await notifier.addQuickTodo(title: result);
      return;
    }
    await notifier.updateTodoTitle(todo, result);
  }
}

class _ProfileRhythmCard extends StatelessWidget {
  const _ProfileRhythmCard({required this.profile});

  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前节奏', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${profile.identityLabel} · ${profile.routineStart} - ${profile.routineEnd}'),
            if ((profile.focusArea as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('重点：${profile.focusArea}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkModeCard extends StatelessWidget {
  const _WorkModeCard({required this.todos});

  final List<PlannerTodo> todos;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('上班模式进行中', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('当前时段优先把安排收成可执行的待办，减少频繁切换。'),
            const SizedBox(height: 12),
            if (todos.isEmpty)
              const Text('你现在没有待处理任务，适合补一条最清晰的下一步。')
            else
              ...todos.map(
                (todo) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(todo.title)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerEvent event;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          title: Text(event.title),
          subtitle: Text('${_fmt(event.startsAt)} - ${_fmt(event.endsAt)}'),
          trailing: SizedBox(
            width: 108,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTodo todo;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Checkbox(
            value: todo.completed,
            onChanged: (value) {
              if (value == null) return;
              ref.read(plannerControllerProvider.notifier).toggleTodo(todo, value);
            },
          ),
          title: Text(todo.title),
          subtitle: Text(todo.completed ? '已完成' : '待处理'),
          trailing: SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) return;
        onChanged(
          DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        );
      },
      icon: const Icon(Icons.schedule_outlined),
      label: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(_fmt(value)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

String _fmt(DateTime dt) =>
    '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
