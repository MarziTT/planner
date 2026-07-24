import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../auth/state/auth_controller.dart';
import '../../fitness/presentation/fitness_panel.dart';
import '../../profile/state/profile_controller.dart';
import '../../tags/state/tags_controller.dart';
import '../../weather/presentation/weather_card.dart';
import '../../weather/state/weather_controller.dart';
import 'planner_calendar_panel.dart';
import 'widgets/planner_agenda_widgets.dart';
import 'widgets/planner_section_widgets.dart';
import 'widgets/planner_zzz_decoration.dart';
import '../domain/planner_models.dart';
import '../state/planner_controller.dart';

const _defaultEventDuration = Duration(hours: 1);

class PlannerDashboard extends ConsumerStatefulWidget {
  const PlannerDashboard({super.key});

  @override
  ConsumerState<PlannerDashboard> createState() => _PlannerDashboardState();
}

class _PlannerDashboardState extends ConsumerState<PlannerDashboard>
    with WidgetsBindingObserver {
  late DateTime _selectedDay;
  late DateTime _visibleMonth;
  bool _followToday = true;
  final Set<int> _deletingEventIds = <int>{};
  final Set<int> _deletingTodoIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _selectedDay = _normalizedDate(now);
    _visibleMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileState = ref.read(profileControllerProvider);
      if (profileState.profile == null && !profileState.loading) {
        ref.read(profileControllerProvider.notifier).load();
      }
      ref.read(weatherControllerProvider.notifier).loadWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      if (prev?.session == null && next.session != null) {
        ref.read(weatherControllerProvider.notifier).loadWeather();
      }
    });

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
    final agendaItems = buildAgendaItems(
      selectedDay: effectiveSelectedDay,
      today: normalizedToday,
      events: selectedDayEvents,
      todos: plannerState.todos,
      includeTodos: _isSameDay(effectiveSelectedDay, normalizedToday),
    );
    final upcomingItems = buildAgendaItems(
      selectedDay: normalizedToday,
      today: normalizedToday,
      events: upcomingEvents.take(6).toList(),
      todos: const [],
      includeTodos: false,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(plannerControllerProvider.notifier).loadDashboard();
        await ref.read(profileControllerProvider.notifier).load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (isZzzTheme)
            ZzzLedMarquee(date: effectiveSelectedDay),
          if (plannerState.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (selectedEvent != null) ...[
            ReminderReturnBanner(event: selectedEvent, isZzz: isZzzTheme),
            const SizedBox(height: 12),
          ],
          if (plannerState.errorMessage != null) ...[
            const SizedBox(height: 12),
            InlineError(
              message: plannerState.errorMessage!,
              isZzz: isZzzTheme,
              onRetry: () => ref.read(plannerControllerProvider.notifier).loadDashboard(),
            ),
          ],
          const WeatherCard(),
          const SizedBox(height: 14),
          SectionHeader(
            title: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '今天安排'
                : '${effectiveSelectedDay.month}月${effectiveSelectedDay.day}日安排',
            caption: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '日程和待办混在一条时间线里，顶部速记就是新增入口。'
                : '这一天的日程集中显示，避免在页面里重复分栏。',
            isZzz: isZzzTheme,
          ),
          const SizedBox(height: 14),
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
            isZzz: isZzzTheme,
          ),
          const SizedBox(height: 12),
          if (_hasCompletedTodos(plannerState.todos))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: isZzzTheme
                    ? InkWell(
                        onTap: _clearCompletedTodos,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: zzzSilver.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_delete_outlined,
                                  size: 16, color: zzzSilver),
                              SizedBox(width: 6),
                              Text(
                                '> CLEAR_COMPLETED',
                                style: TextStyle(
                                  color: zzzSilver,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _clearCompletedTodos,
                        icon: const Icon(Icons.auto_delete_outlined, size: 18),
                        label: const Text('清除已完成待办'),
                      ),
              ),
            ),
          if (agendaItems.isEmpty)
            EmptyBand(
              title: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '今天还没有安排'
                  : '这一天还没有安排',
              message: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '在上方速记里说一句或打一句，比如"晚上七点健身"。'
                  : '切回今天或在速记里说清日期，就能把事情放到这一天。',
              isZzz: isZzzTheme,
            )
          else
            AgendaList(
              items: agendaItems,
              selectedEventId: selectedEventId,
              isZzzTheme: isZzzTheme,
              deletingEventIds: _deletingEventIds,
              deletingTodoIds: _deletingTodoIds,
              onEditEvent: (event) =>
                  _showEventEditor(context: context, event: event),
              onDeleteEvent: _deleteEvent,
              onToggleEvent: _toggleEvent,
              onEditTodo: (todo) =>
                  _showTodoEditor(context: context, todo: todo),
              onDeleteTodo: _deleteTodo,
            ),
          if (isWorkModeActive) ...[
            const SizedBox(height: 12),
            WorkModeQuickPanel(
              todos: plannerState.openTodos,
              onCreate: (title) => ref
                  .read(plannerControllerProvider.notifier)
                  .addQuickTodo(title: title),
              isZzz: isZzzTheme,
            ),
          ],
          const SizedBox(height: 18),
          SectionHeader(
            title: '接下来',
            caption: '只放未来关键日程，不再重复展示待办。',
            isZzz: isZzzTheme,
          ),
          const SizedBox(height: 10),
          if (upcomingItems.isEmpty)
            EmptyBand(
              title: '还没有后续节点',
              message: '如果有航班、训练或重要会议，可以在上方速记里直接记下。',
              isZzz: isZzzTheme,
            )
          else
            AgendaList(
              items: upcomingItems,
              selectedEventId: selectedEventId,
              isZzzTheme: isZzzTheme,
              deletingEventIds: _deletingEventIds,
              deletingTodoIds: _deletingTodoIds,
              onEditEvent: (event) =>
                  _showEventEditor(context: context, event: event),
              onDeleteEvent: _deleteEvent,
              onToggleEvent: _toggleEvent,
              onEditTodo: (todo) =>
                  _showTodoEditor(context: context, todo: todo),
              onDeleteTodo: _deleteTodo,
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

  Future<void> _deleteEvent(PlannerEvent event) async {
    if (_deletingEventIds.contains(event.id)) {
      return;
    }
    setState(() => _deletingEventIds.add(event.id));
    try {
      await ref.read(plannerControllerProvider.notifier).removeEvent(event.id);
      final error = ref.read(plannerControllerProvider).errorMessage;
      if (!mounted || error != null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除行程：${event.title}')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingEventIds.remove(event.id));
      }
    }
  }

  Future<void> _deleteTodo(PlannerTodo todo) async {
    if (_deletingTodoIds.contains(todo.id)) {
      return;
    }
    setState(() => _deletingTodoIds.add(todo.id));
    try {
      await ref.read(plannerControllerProvider.notifier).removeTodo(todo.id);
      final error = ref.read(plannerControllerProvider).errorMessage;
      if (!mounted || error != null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除待办：${todo.title}')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingTodoIds.remove(todo.id));
      }
    }
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

  Future<void> _toggleEvent(PlannerEvent event) async {
    await ref.read(plannerControllerProvider.notifier).toggleEvent(event);
  }

  Future<void> _clearCompletedTodos() async {
    final controller = ref.read(plannerControllerProvider.notifier);
    await controller.clearCompletedTodos();
  }

  bool _hasCompletedTodos(List<PlannerTodo> todos) {
    return todos.any((t) => t.completed);
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
    final tags = ref.read(tagsControllerProvider).tags;
    final baseDay = initialDay ?? DateTime.now();
    var startsAt = event?.startsAt ??
        DateTime(baseDay.year, baseDay.month, baseDay.day, 9);
    var selectedTagId =
        event != null && event.tagIds.isNotEmpty ? event.tagIds.first : null;
    final isZzz = ref.read(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: isZzz ? zzzSurfaceColor : null,
          shape: isZzz
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                      color: zzzGreen.withValues(alpha: 0.3), width: 1.5),
                )
              : null,
          title: Text(
            event == null ? '新增行程' : '编辑行程',
            style: isZzz
                ? const TextStyle(color: zzzTextColor)
                : null,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: isZzz
                      ? const TextStyle(color: zzzTextColor)
                      : null,
                  decoration: isZzz
                      ? const InputDecoration(
                          labelText: '标题',
                          labelStyle: TextStyle(color: zzzSilver),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: zzzGreen),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: zzzGreen),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: zzzGreen),
                          ),
                        )
                      : const InputDecoration(labelText: '标题'),
                ),
                const SizedBox(height: 14),
                ModernTimePicker(
                  value: startsAt,
                  onChanged: (value) => setLocalState(() => startsAt = value),
                  isZzz: isZzz,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedTagId,
                    decoration: const InputDecoration(
                      labelText: '标签',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text('(无标签)',
                            style: isZzz
                                ? const TextStyle(color: zzzTextColor)
                                : null),
                      ),
                      ...tags.map(
                        (tag) => DropdownMenuItem<int>(
                          value: tag.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: colorFromHex(tag.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(tag.name,
                                  style: isZzz
                                      ? const TextStyle(color: zzzTextColor)
                                      : null),
                              if (tag.isRecurring) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.repeat,
                                    size: 14,
                                    color: isZzz
                                        ? zzzSilver
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => selectedTagId = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isZzz) ...[
              ZzzEditorButton(
                label: 'CANCEL',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 8),
              ZzzEditorButton(
                label: 'SAVE',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
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
        tagId: selectedTagId,
      );
      return;
    }

    await notifier.updateEventSchedule(
      event: event,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      tagId: selectedTagId,
    );
  }

  Future<void> _showTodoEditor({
    required BuildContext context,
    PlannerTodo? todo,
  }) async {
    final controller = TextEditingController(text: todo?.title ?? '');
    final isZzz = ref.read(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isZzz ? zzzSurfaceColor : null,
        shape: isZzz
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                    color: zzzGreen.withValues(alpha: 0.3), width: 1.5),
              )
            : null,
        title: Text(todo == null ? '新增待办' : '编辑待办'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入标题'),
        ),
        actions: isZzz
            ? [
                ZzzEditorButton(
                  label: 'CANCEL',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                ZzzEditorButton(
                  label: 'SAVE',
                  primary: true,
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('保存'),
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
