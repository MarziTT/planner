import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../fitness/presentation/fitness_panel.dart';
import '../../profile/state/profile_controller.dart';
import '../../updates/presentation/hot_update_image.dart';
import 'planner_calendar_panel.dart';
import '../domain/planner_models.dart';
import '../state/planner_controller.dart';

enum _TodoFilter { open, completed, all }

const _defaultEventDuration = Duration(hours: 1);
const _zzzGifSpecs = <_ZzzGifSpec>[
  _ZzzGifSpec(
      'zzz.transform', 'assets/themes/zzz/transform.gif', '\u53d8\u8eab'),
  _ZzzGifSpec('zzz.shield', 'assets/themes/zzz/shield.gif', '\u9632\u62a4'),
  _ZzzGifSpec(
      'zzz.equipment', 'assets/themes/zzz/equipment.gif', '\u88c5\u5907'),
  _ZzzGifSpec('zzz.flight', 'assets/themes/zzz/flight.gif', '\u51fa\u884c'),
  _ZzzGifSpec('zzz.rain', 'assets/themes/zzz/rain.gif', '\u96e8\u5929'),
];

_ZzzGifSpec _zzzSpecForEvent(PlannerEvent event) {
  final seed = Object.hash(event.id, event.title, event.startsAt.day);
  return _zzzGifSpecs[seed.abs() % _zzzGifSpecs.length];
}

_ZzzGifSpec _zzzSpecForTodo(PlannerTodo todo) {
  final seed = Object.hash(todo.id, todo.title, todo.completed);
  return _zzzGifSpecs[seed.abs() % _zzzGifSpecs.length];
}

class PlannerDashboard extends ConsumerStatefulWidget {
  const PlannerDashboard({super.key});

  @override
  ConsumerState<PlannerDashboard> createState() => _PlannerDashboardState();
}

class _PlannerDashboardState extends ConsumerState<PlannerDashboard>
    with WidgetsBindingObserver {
  _TodoFilter _todoFilter = _TodoFilter.open;
  late DateTime _selectedDay;
  late DateTime _visibleMonth;
  bool _followToday = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _selectedDay = _normalizedDate(now);
    _visibleMonth = DateTime(now.year, now.month);
    Future.microtask(() {
      final profileState = ref.read(profileControllerProvider);
      if (profileState.profile == null && !profileState.loading) {
        ref.read(profileControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plannerState = ref.watch(plannerControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final themeState = ref.watch(themeControllerProvider);
    final selectedEventId = ref.watch(selectedPlannerEventIdProvider);
    final profile = profileState.profile;
    final now = DateTime.now();
    final normalizedToday = _normalizedDate(now);
    final effectiveSelectedDay = _resolvedSelectedDay(normalizedToday);
    final effectiveVisibleMonth = _resolvedVisibleMonth(normalizedToday);
    final selectedDayEvents = plannerState.eventsForDay(effectiveSelectedDay);
    final upcomingEvents = plannerState.upcomingEvents(normalizedToday);
    final selectedEvent =
        _findSelectedEvent(plannerState.events, selectedEventId);
    final isWorkModeActive = profile?.identity == 'worker' &&
        (profile?.isScheduleActiveAt(now) ?? false);
    final isZzzTheme = themeState.preset == PlannerThemePreset.kamenRiderZzz;
    final filteredTodos = switch (_todoFilter) {
      _TodoFilter.open => plannerState.openTodos,
      _TodoFilter.completed => plannerState.completedTodos,
      _TodoFilter.all => plannerState.todos,
    };

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(plannerControllerProvider.notifier).loadDashboard();
        await ref.read(profileControllerProvider.notifier).load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (plannerState.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (selectedEvent != null) ...[
            _ReminderReturnBanner(event: selectedEvent),
            const SizedBox(height: 12),
          ],
          if (plannerState.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: plannerState.errorMessage!),
          ],
          _SectionHeader(
            title: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '\u4eca\u5929\u65f6\u95f4\u7ebf'
                : '\u6708\u65e5\u884c\u7a0b',
            caption: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '\u5148\u770b\u63a5\u4e0b\u6765\u7684\u884c\u7a0b\uff0c\u76f4\u63a5\u518d\u8865\u4e00\u6761\u3002'
                : '\u4ece\u6708\u5386\u91cc\u70b9\u9009\u7684\u8fd9\u4e00\u5929\uff0c\u65e5\u7a0b\u4f1a\u5168\u90e8\u5217\u5728\u8fd9\u91cc\u3002',
            actionLabel: '\u65b0\u589e\u884c\u7a0b',
            onAction: () => _showEventEditor(
                context: context, initialDay: effectiveSelectedDay),
          ),
          const SizedBox(height: 18),
          PlannerCalendarPanel(
            visibleMonth: effectiveVisibleMonth,
            selectedDay: effectiveSelectedDay,
            today: now,
            events: plannerState.events,
            onPreviousMonth: () => setState(() {
              _followToday = false;
              _visibleMonth = DateTime(
                  effectiveVisibleMonth.year, effectiveVisibleMonth.month - 1);
            }),
            onNextMonth: () => setState(() {
              _followToday = false;
              _visibleMonth = DateTime(
                  effectiveVisibleMonth.year, effectiveVisibleMonth.month + 1);
            }),
            onSelectDay: (day) => setState(() {
              final normalizedDay = _normalizedDate(day);
              _selectedDay = normalizedDay;
              _visibleMonth = DateTime(day.year, day.month);
              _followToday = _isSameDay(normalizedDay, normalizedToday);
            }),
          ),
          const SizedBox(height: 10),
          if (selectedDayEvents.isEmpty)
            _EmptyBand(
              title: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '\u4eca\u5929\u8fd8\u662f\u7a7a\u7684'
                  : '\u6708\u65e5\u8fd8\u6ca1\u6709\u5b89\u6392',
              message: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '\u5148\u653e\u8fdb\u4eca\u5929\u6700\u91cd\u8981\u7684\u4e00\u4ef6\u4e8b\uff0c\u4f60\u7684\u8282\u594f\u5c31\u51fa\u6765\u4e86\u3002'
                  : '\u8fd9\u4e00\u5929\u76ee\u524d\u8fd8\u662f\u7a7a\u767d\uff0c\u53ef\u4ee5\u5148\u628a\u8fd9\u5929\u6700\u91cd\u8981\u7684\u4e00\u6761\u8bb0\u4e0b\u6765\u3002',
            )
          else
            ...selectedDayEvents.map(
              (event) => _EventTile(
                event: event,
                highlighted: selectedEventId == event.id,
                zzzBackground: isZzzTheme ? _zzzSpecForEvent(event) : null,
                onEdit: () => _showEventEditor(context: context, event: event),
                onDelete: () => ref
                    .read(plannerControllerProvider.notifier)
                    .removeEvent(event.id),
              ),
            ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: '\u63a5\u4e0b\u6765',
            caption:
                '\u628a\u660e\u5929\u548c\u4e4b\u540e\u7684\u5173\u952e\u8282\u70b9\u63d0\u524d\u6392\u597d\u3002',
            actionLabel: '\u5237\u65b0',
            onAction: () =>
                ref.read(plannerControllerProvider.notifier).loadDashboard(),
          ),
          const SizedBox(height: 10),
          if (upcomingEvents.isEmpty)
            const _EmptyBand(
              title: '\u8fd8\u6ca1\u6709\u540e\u7eed\u8282\u70b9',
              message:
                  '\u5982\u679c\u6709\u822a\u73ed\u3001\u8bad\u7ec3\u6216\u91cd\u8981\u4f1a\u8bae\uff0c\u53ef\u4ee5\u73b0\u5728\u5c31\u8bb0\u4e0b\u6765\u3002',
            )
          else
            ...upcomingEvents.take(6).map(
                  (event) => _EventTile(
                    event: event,
                    highlighted: selectedEventId == event.id,
                    zzzBackground: isZzzTheme ? _zzzSpecForEvent(event) : null,
                    onEdit: () =>
                        _showEventEditor(context: context, event: event),
                    onDelete: () => ref
                        .read(plannerControllerProvider.notifier)
                        .removeEvent(event.id),
                  ),
                ),
          if (isWorkModeActive) ...[
            const SizedBox(height: 16),
            _WorkModeQuickPanel(
              todos: plannerState.openTodos,
              onCreate: (title) => ref
                  .read(plannerControllerProvider.notifier)
                  .addQuickTodo(title: title),
            ),
          ],
          const SizedBox(height: 16),
          _TodoHeader(
            filter: _todoFilter,
            onFilterChanged: (value) => setState(() => _todoFilter = value),
            onCreate: () => _showTodoEditor(context: context),
          ),
          const SizedBox(height: 10),
          if (filteredTodos.isEmpty)
            _EmptyBand(
              title: _todoFilter == _TodoFilter.completed
                  ? '\u8fd8\u6ca1\u6709\u5b8c\u6210\u8bb0\u5f55'
                  : '\u8fd9\u4e00\u680f\u8fd8\u6ca1\u6709\u5f85\u529e',
              message: _todoFilter == _TodoFilter.completed
                  ? '\u4e00\u6761\u4e5f\u597d\uff0c\u5148\u505a\u5b8c\u518d\u56de\u6765\u770b\u8fd9\u91cc\u3002'
                  : '\u5de5\u4f5c\u65f6\u95f4\u53ef\u4ee5\u8bb0\u5177\u4f53\u52a8\u4f5c\uff0c\u751f\u6d3b\u65f6\u95f4\u53ef\u4ee5\u8bb0\u8981\u51fa\u95e8\u7684\u4e8b\u3002',
            )
          else
            ...filteredTodos.map(
              (todo) => _TodoTile(
                todo: todo,
                zzzBackground: isZzzTheme ? _zzzSpecForTodo(todo) : null,
                onEdit: () => _showTodoEditor(context: context, todo: todo),
                onDelete: () => ref
                    .read(plannerControllerProvider.notifier)
                    .removeTodo(todo.id),
              ),
            ),
          if (profile?.wantsFitness ?? false) ...[
            const SizedBox(height: 18),
            FitnessPanel(
              modeLabel: profile!.fitnessModeLabel,
              goal: profile.fitnessGoal,
            ),
          ],
        ],
      ),
    );
  }

  PlannerEvent? _findSelectedEvent(
      List<PlannerEvent> events, int? selectedEventId) {
    if (selectedEventId == null) {
      return null;
    }
    for (final event in events) {
      if (event.id == selectedEventId) {
        return event;
      }
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime _resolvedSelectedDay(DateTime today) {
    return _followToday ? today : _selectedDay;
  }

  DateTime _resolvedVisibleMonth(DateTime today) {
    return _followToday ? DateTime(today.year, today.month) : _visibleMonth;
  }

  DateTime _normalizedDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _showEventEditor({
    required BuildContext context,
    PlannerEvent? event,
    DateTime? initialDay,
  }) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    final baseDay = initialDay ?? DateTime.now();
    var startsAt = event?.startsAt ??
        DateTime(baseDay.year, baseDay.month, baseDay.day, 9);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(event == null
              ? '\u65b0\u589e\u884c\u7a0b'
              : '\u7f16\u8f91\u884c\u7a0b'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '\u6807\u9898'),
                ),
                const SizedBox(height: 12),
                _DateTimeField(
                  label: '\u5f00\u59cb\u65f6\u95f4',
                  value: startsAt,
                  onChanged: (value) => setLocalState(() => startsAt = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('\u53d6\u6d88'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('\u4fdd\u5b58'),
            ),
          ],
        ),
      ),
    );

    final title = titleController.text.trim();
    if (saved != true || title.isEmpty) {
      return;
    }

    final endsAt = startsAt.add(_defaultEventDuration);

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
        title: Text(todo == null
            ? '\u65b0\u589e\u5f85\u529e'
            : '\u7f16\u8f91\u5f85\u529e'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '\u8f93\u5165\u6807\u9898'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('\u4fdd\u5b58'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final notifier = ref.read(plannerControllerProvider.notifier);
    if (todo == null) {
      await notifier.addQuickTodo(title: result);
      return;
    }

    await notifier.updateTodoTitle(todo, result);
  }
}

class _ReminderReturnBanner extends StatelessWidget {
  const _ReminderReturnBanner({required this.event});

  final PlannerEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined,
              color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('从提醒返回', style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${_timeLabel(event.startsAt)} ${event.title}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkModeQuickPanel extends StatelessWidget {
  const _WorkModeQuickPanel({
    required this.todos,
    required this.onCreate,
  });

  final List<PlannerTodo> todos;
  final Future<void> Function(String title) onCreate;

  static const _actions = [
    _WorkQuickAction('开发', Icons.code_rounded),
    _WorkQuickAction('开会', Icons.groups_rounded),
    _WorkQuickAction('沟通', Icons.chat_bubble_outline_rounded),
    _WorkQuickAction('复盘', Icons.fact_check_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTitles = todos
        .where((todo) => !todo.completed)
        .map((todo) => todo.title.trim())
        .toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '上班快捷动作',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '点一下生成短待办，工作时间只追下一个动作。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions.map((action) {
              final exists = activeTitles.contains(action.title);
              return ActionChip(
                avatar: Icon(action.icon, size: 17),
                label: Text(exists ? '${action.title} 已加' : action.title),
                onPressed: exists ? null : () => onCreate(action.title),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.surface,
                disabledColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.78),
                side: BorderSide(
                  color: exists
                      ? theme.colorScheme.outlineVariant
                      : theme.colorScheme.primary.withValues(alpha: 0.24),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _WorkQuickAction {
  const _WorkQuickAction(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.caption,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String caption;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
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

class _TodoHeader extends StatelessWidget {
  const _TodoHeader({
    required this.filter,
    required this.onFilterChanged,
    required this.onCreate,
  });

  final _TodoFilter filter;
  final ValueChanged<_TodoFilter> onFilterChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '待办动作',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: '新增',
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_TodoFilter>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
            ),
            segments: const [
              ButtonSegment(
                value: _TodoFilter.open,
                label: Text('待办'),
              ),
              ButtonSegment(
                value: _TodoFilter.completed,
                label: Text('完成'),
              ),
              ButtonSegment(
                value: _TodoFilter.all,
                label: Text('全部'),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (value) => onFilterChanged(value.first),
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.highlighted,
    this.zzzBackground,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerEvent event;
  final bool highlighted;
  final _ZzzGifSpec? zzzBackground;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZzz = zzzBackground != null;
    final foreground = isZzz ? Colors.white : theme.colorScheme.onSurface;
    final muted = isZzz
        ? Colors.white.withValues(alpha: 0.76)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isZzz
              ? const Color(0xFF0A0B10)
              : highlighted
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
                  : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : isZzz
                    ? Colors.white.withValues(alpha: 0.18)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Stack(
          children: [
            if (zzzBackground != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 104,
                child: _ZzzSideArt(spec: zzzBackground!, opacity: 0.58),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 14, isZzz ? 92 : 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isZzz
                          ? Colors.black.withValues(alpha: 0.48)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: isZzz
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _timeLabel(event.startsAt),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.startsAt.month}/${event.startsAt.day}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (highlighted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '\u5f53\u524d\u63d0\u9192',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isZzz
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeLabel(event.startsAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: foreground,
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: foreground,
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
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

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    this.zzzBackground,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTodo todo;
  final _ZzzGifSpec? zzzBackground;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isZzz = zzzBackground != null;
    final foreground = isZzz ? Colors.white : theme.colorScheme.onSurface;
    final muted = isZzz
        ? Colors.white.withValues(alpha: 0.70)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isZzz
              ? const Color(0xFF0A0B10)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: isZzz
              ? Border.all(color: Colors.white.withValues(alpha: 0.14))
              : null,
        ),
        child: Stack(
          children: [
            if (zzzBackground != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 88,
                child: _ZzzSideArt(spec: zzzBackground!, opacity: 0.36),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, isZzz ? 70 : 12, 10),
              child: Row(
                children: [
                  Checkbox(
                    value: todo.completed,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      ref
                          .read(plannerControllerProvider.notifier)
                          .toggleTodo(todo, value);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: foreground,
                            decoration: todo.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todo.completed
                              ? '\u5df2\u5b8c\u6210'
                              : '\u5f85\u5904\u7406',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: foreground,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: foreground,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
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

class _ZzzSideArt extends StatelessWidget {
  const _ZzzSideArt({required this.spec, required this.opacity});

  final _ZzzGifSpec spec;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: opacity,
            child: HotUpdateImage(
              resourceId: spec.resourceId,
              fallbackAsset: spec.asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF0A0B10),
                  Color(0x990A0B10),
                  Color(0x000A0B10),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZzzGifSpec {
  const _ZzzGifSpec(this.resourceId, this.asset, this.label);

  final String resourceId;
  final String asset;
  final String label;
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
        if (date == null || !context.mounted) {
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) {
          return;
        }
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
          Text(_fullDateTimeLabel(value)),
        ],
      ),
    );
  }
}

class _EmptyBand extends StatelessWidget {
  const _EmptyBand({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _fullDateTimeLabel(DateTime dt) =>
    '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${_timeLabel(dt)}';
