import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../auth/state/auth_controller.dart';
import '../../fitness/presentation/fitness_panel.dart';
import '../../profile/state/profile_controller.dart';
import '../../tags/domain/tag_model.dart';
import '../../tags/state/tags_controller.dart';
import '../../updates/presentation/hot_update_image.dart';
import '../../weather/presentation/weather_card.dart';
import '../../weather/state/weather_controller.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import 'planner_calendar_panel.dart';
import '../domain/planner_models.dart';
import '../state/planner_controller.dart';

const _defaultEventDuration = Duration(hours: 1);

const _zzzBgColor = zzzBgColor;
const _zzzSurfaceColor = zzzSurfaceColor;
const _zzzRed = zzzRed;
const _zzzGreen = zzzGreen;
const _zzzTextColor = zzzTextColor;
const _zzzSilver = zzzSilver;

ZzzGifSpec _zzzSpecForEvent(PlannerEvent event) {
  final seed = Object.hash(event.id, event.title, event.startsAt.day);
  return zzzGifSpecs[seed.abs() % zzzGifSpecs.length];
}

ZzzGifSpec _zzzSpecForTodo(PlannerTodo todo) {
  final seed = Object.hash(todo.id, todo.title, todo.completed);
  return zzzGifSpecs[seed.abs() % zzzGifSpecs.length];
}

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
    final agendaItems = _buildAgendaItems(
      selectedDay: effectiveSelectedDay,
      today: normalizedToday,
      events: selectedDayEvents,
      todos: plannerState.todos,
      includeTodos: _isSameDay(effectiveSelectedDay, normalizedToday),
    );
    final upcomingItems = _buildAgendaItems(
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
            _ZzzLedMarquee(date: effectiveSelectedDay),
          if (plannerState.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (selectedEvent != null) ...[
            _ReminderReturnBanner(event: selectedEvent, isZzz: isZzzTheme),
            const SizedBox(height: 12),
          ],
          if (plannerState.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: plannerState.errorMessage!, isZzz: isZzzTheme),
          ],
          const WeatherCard(),
          const SizedBox(height: 14),
          _SectionHeader(
            title: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '今天安排'
                : '${effectiveSelectedDay.month}月${effectiveSelectedDay.day}日安排',
            caption: _isSameDay(effectiveSelectedDay, normalizedToday)
                ? '日程和待办混在一条时间线里，顶部速记就是新增入口。'
                : '这一天的日程集中显示，避免在页面里重复分栏。',
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: _zzzSilver.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_delete_outlined, size: 16, color: _zzzSilver),
                              const SizedBox(width: 6),
                              const Text(
                                '> CLEAR_COMPLETED',
                                style: TextStyle(
                                  color: _zzzSilver,
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
            _EmptyBand(
              title: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '今天还没有安排'
                  : '这一天还没有安排',
              message: _isSameDay(effectiveSelectedDay, normalizedToday)
                  ? '在上方速记里说一句或打一句，比如“晚上七点健身”。'
                  : '切回今天或在速记里说清日期，就能把事情放到这一天。',
            )
          else
            _AgendaList(
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
            _WorkModeQuickPanel(
              todos: plannerState.openTodos,
              onCreate: (title) => ref
                  .read(plannerControllerProvider.notifier)
                  .addQuickTodo(title: title),
              isZzz: isZzzTheme,
            ),
          ],
          const SizedBox(height: 18),
          _SectionHeader(
            title: '接下来',
            caption: '只放未来关键日程，不再重复展示待办。',
            isZzz: isZzzTheme,
          ),
          const SizedBox(height: 10),
          if (upcomingItems.isEmpty)
            _EmptyBand(
              title: '还没有后续节点',
              message: '如果有航班、训练或重要会议，可以在上方速记里直接记下。',
              isZzz: isZzzTheme,
            )
          else
            _AgendaList(
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
    var selectedTagId = event != null && event.tagIds.isNotEmpty ? event.tagIds.first : null;
    final isZzz = ref.read(themeControllerProvider).preset == PlannerThemePreset.kamenRiderZzz;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: isZzz ? _zzzSurfaceColor : null,
          shape: isZzz
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: _zzzGreen.withValues(alpha: 0.3), width: 1.5),
                )
              : null,
          title: Text(
            event == null ? '\u65b0\u589e\u884c\u7a0b' : '\u7f16\u8f91\u884c\u7a0b',
            style: isZzz
                ? const TextStyle(color: Color(0xFFE0F0E0))
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
                      ? const TextStyle(color: Color(0xFFE0F0E0))
                      : null,
                  decoration: isZzz
                      ? const InputDecoration(
                          labelText: '\u6807\u9898',
                          labelStyle: TextStyle(color: Color(0xFFA0A0B8)),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF00FF41)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF00FF41)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF00FF41)),
                          ),
                        )
                      : const InputDecoration(labelText: '\u6807\u9898'),
                ),
                const SizedBox(height: 14),
                _ModernTimePicker(
                  value: startsAt,
                  onChanged: (value) => setLocalState(() => startsAt = value),
                  isZzz: isZzz,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedTagId,
                    decoration: const InputDecoration(
                      labelText: '\u6807\u7b7e',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text('(\u65e0\u6807\u7b7e)',
                            style: isZzz
                                ? const TextStyle(color: Color(0xFFE0F0E0))
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
                                  color: _colorFromHex(tag.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(tag.name,
                                  style: isZzz
                                      ? const TextStyle(color: Color(0xFFE0F0E0))
                                      : null),
                              if (tag.isRecurring) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.repeat, size: 14,
                                    color: isZzz
                                        ? const Color(0xFFA0A0B8)
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
              _ZzzEditorButton(
                label: 'CANCEL',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 8),
              _ZzzEditorButton(
                label: 'SAVE',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('\u53d6\u6d88'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('\u4fdd\u5b58'),
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
    final isZzz = ref.read(themeControllerProvider).preset == PlannerThemePreset.kamenRiderZzz;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isZzz ? _zzzSurfaceColor : null,
        shape: isZzz
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: _zzzGreen.withValues(alpha: 0.3), width: 1.5),
              )
            : null,
        title: Text(todo == null
            ? '\u65b0\u589e\u5f85\u529e'
            : '\u7f16\u8f91\u5f85\u529e'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '\u8f93\u5165\u6807\u9898'),
        ),
        actions: isZzz
            ? [
                _ZzzEditorButton(
                  label: 'CANCEL',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                _ZzzEditorButton(
                  label: 'SAVE',
                  primary: true,
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                ),
              ]
            : [
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

class _ZzzLedMarquee extends StatelessWidget {
  const _ZzzLedMarquee({required this.date});

  final DateTime date;

  String get _weekday {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $_weekday';
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: _zzzGreen.withValues(alpha: 0.06),
            border: Border(
              top: BorderSide(color: _zzzGreen.withValues(alpha: 0.55), width: 1.5),
              bottom: BorderSide(color: _zzzGreen.withValues(alpha: 0.55), width: 1.5),
            ),
          ),
          child: Column(
            children: [
              // Belt buckle accent
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 20, height: 1, color: _zzzRed.withValues(alpha: 0.6)),
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _zzzRed.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: _zzzRed.withValues(alpha: 0.7), width: 1.5),
                    ),
                  ),
                  Container(width: 20, height: 1, color: _zzzRed.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ZEZ-TZDRIVER — $ds',
                style: const TextStyle(
                  color: _zzzGreen,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReminderReturnBanner extends StatelessWidget {
  const _ReminderReturnBanner({required this.event, required this.isZzz});

  final PlannerEvent event;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Container(
        decoration: BoxDecoration(
          color: _zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: _zzzGreen.withValues(alpha: 0.45),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 16, color: _zzzGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '> RETURN: ${_timeLabel(event.startsAt)}  ${event.title}',
                style: const TextStyle(
                  color: _zzzGreen,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
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
    this.isZzz = false,
  });

  final List<PlannerTodo> todos;
  final Future<void> Function(String title) onCreate;
  final bool isZzz;

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

    final bgColor = isZzz
        ? _zzzSurfaceColor
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.52);
    final borderColor = isZzz
        ? _zzzGreen.withValues(alpha: 0.2)
        : theme.colorScheme.primary.withValues(alpha: 0.14);
    final accentColor = isZzz ? _zzzGreen : theme.colorScheme.primary;
    final textDim = isZzz ? _zzzSilver : theme.colorScheme.onSurfaceVariant;
    final chipBg = isZzz ? _zzzBgColor : theme.colorScheme.surface;
    final chipDisabled = isZzz
        ? _zzzSurfaceColor.withValues(alpha: 0.78)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);
    final chipExistsBorder = isZzz
        ? _zzzSilver.withValues(alpha: 0.15)
        : theme.colorScheme.outlineVariant;
    final chipBorder = isZzz
        ? _zzzGreen.withValues(alpha: 0.3)
        : theme.colorScheme.primary.withValues(alpha: 0.24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isZzz ? 2 : 16),
        border: Border.all(color: borderColor),
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: _zzzGreen.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZzz ? '> WORK_MODE' : '上班模式',
                  style: (isZzz
                          ? const TextStyle(
                              color: _zzzGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            )
                          : theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '工作时间只保留几个高频动作，点一下就进入今天安排流。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textDim,
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
                backgroundColor: chipBg,
                disabledColor: chipDisabled,
                side: BorderSide(
                  color: exists ? chipExistsBorder : chipBorder,
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
    this.isZzz = false,
  });

  final String message;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _zzzRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: _zzzRed.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: _zzzRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '> ERROR: $message',
                style: const TextStyle(
                  color: _zzzRed,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
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
    this.isZzz = false,
  });

  final String title;
  final String caption;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '> $title',
              style: const TextStyle(
                color: _zzzGreen,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                color: _zzzSilver,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 1,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_zzzGreen, Color(0x0000FF41)],
                ),
              ),
            ),
          ],
        ),
      );
    }
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
      ],
    );
  }
}

enum _AgendaItemKind { event, todo }

class _AgendaItem {
  const _AgendaItem.event(this.event)
      : todo = null,
        kind = _AgendaItemKind.event;

  const _AgendaItem.todo(this.todo)
      : event = null,
        kind = _AgendaItemKind.todo;

  final _AgendaItemKind kind;
  final PlannerEvent? event;
  final PlannerTodo? todo;
}

List<_AgendaItem> _buildAgendaItems({
  required DateTime selectedDay,
  required DateTime today,
  required List<PlannerEvent> events,
  required List<PlannerTodo> todos,
  required bool includeTodos,
}) {
  final items = <_AgendaItem>[
    ...events.map(_AgendaItem.event),
    if (includeTodos) ...todos.map(_AgendaItem.todo),
  ];
  items.sort((left, right) {
    // completed items always at the bottom
    final leftDone = left.kind == _AgendaItemKind.event
        ? left.event!.status == 'done'
        : left.todo!.completed;
    final rightDone = right.kind == _AgendaItemKind.event
        ? right.event!.status == 'done'
        : right.todo!.completed;
    if (leftDone != rightDone) return leftDone ? 1 : -1;
    // within same completion state, sort by time
    if (left.event != null && right.event != null) {
      return left.event!.startsAt.compareTo(right.event!.startsAt);
    }
    return 0;
  });
  return items;
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    required this.items,
    required this.selectedEventId,
    required this.isZzzTheme,
    required this.deletingEventIds,
    required this.deletingTodoIds,
    required this.onEditEvent,
    required this.onDeleteEvent,
    required this.onToggleEvent,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  final List<_AgendaItem> items;
  final int? selectedEventId;
  final bool isZzzTheme;
  final Set<int> deletingEventIds;
  final Set<int> deletingTodoIds;
  final ValueChanged<PlannerEvent> onEditEvent;
  final Future<void> Function(PlannerEvent event) onDeleteEvent;
  final Future<void> Function(PlannerEvent event) onToggleEvent;
  final ValueChanged<PlannerTodo> onEditTodo;
  final Future<void> Function(PlannerTodo todo) onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final event = item.event;
        if (event != null) {
          return _EventTile(
            event: event,
            highlighted: selectedEventId == event.id,
            zzzBackground: isZzzTheme ? _zzzSpecForEvent(event) : null,
            isDeleting: deletingEventIds.contains(event.id),
            onEdit: () => onEditEvent(event),
            onDelete: () => onDeleteEvent(event),
            onToggle: () => onToggleEvent(event),
          );
        }
        final todo = item.todo!;
        return _TodoTile(
          todo: todo,
          zzzBackground: isZzzTheme ? _zzzSpecForTodo(todo) : null,
          isDeleting: deletingTodoIds.contains(todo.id),
          onEdit: () => onEditTodo(todo),
          onDelete: () => onDeleteTodo(todo),
        );
      }).toList(),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({
    required this.event,
    required this.highlighted,
    this.zzzBackground,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final PlannerEvent event;
  final bool highlighted;
  final ZzzGifSpec? zzzBackground;
  final bool isDeleting;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onToggle;

  bool get _isDone => event.status == 'done';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isZzz = zzzBackground != null;
    if (isZzz) return _buildZzzTile(context, ref, theme);

    final foreground = _isDone
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : theme.colorScheme.onSurface;
    final muted = _isDone
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.40)
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: highlighted
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
              : _isDone
                  ? theme.colorScheme.surfaceContainerLowest
                  : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.42)
                : _isDone
                    ? theme.colorScheme.outlineVariant.withValues(alpha: 0.20)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _timeLabel(event.startsAt),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                            decoration:
                                _isDone ? TextDecoration.lineThrough : null,
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
                                  decoration: _isDone
                                      ? TextDecoration.lineThrough
                                      : null,
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
                                  '当前提醒',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            if (_isDone && !highlighted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '已完成',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (event.tagIds.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _TagChips(
                            tagIds: event.tagIds,
                            tags: ref.watch(tagsControllerProvider).tags,
                            isZzz: isZzz,
                          ),
                        ],
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
                              onPressed: isDeleting ? null : onToggle,
                              icon: Icon(_isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked),
                              tooltip: _isDone ? '标记未完成' : '标记完成',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: foreground,
                              onPressed: isDeleting ? null : onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: foreground,
                              onPressed: isDeleting ? null : onDelete,
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
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

  Widget _buildZzzTile(BuildContext context, WidgetRef ref, ThemeData theme) {
    final titlePrefix = event.id > 0 ? 'Z-${event.id} ' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipPath(
        clipper: _ZzzCapsuleClipper(chamfer: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _zzzSurfaceColor,
            border: Border.all(
              color: _zzzGreen.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _zzzGreen.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_zzzGreen, Color(0x3300FF41)],
                    ),
                  ),
                ),
              ),
              if (zzzBackground != null)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  width: 104,
                  child: Opacity(
                    opacity: 0.58,
                    child: _ZzzSideArt(spec: zzzBackground!, opacity: 0.58),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(painter: _ZzzScanlinePainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: _zzzGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _timeLabel(event.startsAt),
                            style: const TextStyle(
                              color: _zzzGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.startsAt.month}/${event.startsAt.day}',
                            style: TextStyle(
                              color: _zzzGreen.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontFamily: 'monospace',
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
                                  '$titlePrefix${event.title}',
                                  style: const TextStyle(
                                    color: _zzzTextColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              if (highlighted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _zzzRed.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: _zzzRed.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: const Text(
                                    '当前提醒',
                                    style: TextStyle(
                                      color: _zzzRed,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              if (_isDone && !highlighted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _zzzSilver.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    '已完成',
                                    style: TextStyle(
                                      color: _zzzSilver,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (event.tagIds.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _TagChips(
                              tagIds: event.tagIds,
                              tags: ref.watch(tagsControllerProvider).tags,
                              isZzz: true,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _timeLabel(event.startsAt),
                            style: TextStyle(
                              color: _zzzSilver,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _ZzzActionButton(
                                icon: _isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                label: _isDone ? 'UNDO' : 'DONE',
                                isLoading: isDeleting,
                                onPressed: onToggle,
                              ),
                              const SizedBox(width: 8),
                              _ZzzActionButton(
                                icon: Icons.edit_outlined,
                                label: 'EDIT',
                                onPressed: onEdit,
                              ),
                              const SizedBox(width: 8),
                              _ZzzActionButton(
                                icon: Icons.delete_outline,
                                label: 'DEL',
                                isLoading: isDeleting,
                                onPressed: onDelete,
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
      ),
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    this.zzzBackground,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTodo todo;
  final ZzzGifSpec? zzzBackground;
  final bool isDeleting;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isZzz = zzzBackground != null;

    if (isZzz) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ClipPath(
          clipper: _ZzzCapsuleClipper(chamfer: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _zzzSurfaceColor,
              border: Border.all(
                color: todo.completed
                    ? _zzzSilver.withValues(alpha: 0.3)
                    : _zzzGreen.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (todo.completed ? _zzzSilver : _zzzGreen).withValues(alpha: 0.08),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: todo.completed
                            ? [_zzzSilver, const Color(0x33A0A0B8)]
                            : [_zzzRed, const Color(0x33FF1744)],
                      ),
                    ),
                  ),
                ),
                if (zzzBackground != null)
                  Positioned(
                    right: 0, top: 0, bottom: 0,
                    width: 88,
                    child: _ZzzSideArt(spec: zzzBackground!, opacity: 0.36),
                  ),
                Positioned.fill(
                  child: CustomPaint(painter: _ZzzScanlinePainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isDeleting ? null : () {
                          ref.read(plannerControllerProvider.notifier).toggleTodo(todo, !todo.completed);
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: todo.completed
                                ? _zzzGreen.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: todo.completed
                                  ? _zzzGreen.withValues(alpha: 0.6)
                                  : _zzzSilver.withValues(alpha: 0.4),
                            ),
                          ),
                          child: todo.completed
                              ? const Icon(Icons.check, size: 14, color: _zzzGreen)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todo.title,
                              style: TextStyle(
                                color: todo.completed ? _zzzSilver : _zzzTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: 'monospace',
                                decoration: todo.completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _ZzzActionButton(
                                  icon: Icons.edit_outlined,
                                  label: 'EDIT',
                                  onPressed: isDeleting ? null : onEdit,
                                ),
                                const SizedBox(width: 8),
                                _ZzzActionButton(
                                  icon: Icons.delete_outline,
                                  label: 'DEL',
                                  isLoading: isDeleting,
                                  onPressed: isDeleting ? null : onDelete,
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Checkbox(
                value: todo.completed,
                onChanged: isDeleting
                    ? null
                    : (value) {
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
                        color: theme.colorScheme.onSurface,
                        decoration: todo.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todo.completed
                          ? '已完成'
                          : '待处理',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurface,
                onPressed: isDeleting ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurface,
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZzzSideArt extends StatelessWidget {
  const _ZzzSideArt({required this.spec, required this.opacity});

  final ZzzGifSpec spec;
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
                  _zzzBgColor,
                  Color(0x990A0A0F),
                  Color(0x000A0A0F),
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

class _ZzzActionButton extends StatelessWidget {
  const _ZzzActionButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _zzzGreen.withValues(alpha: 0.13),
              _zzzGreen.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _zzzGreen.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _zzzGreen.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _zzzGreen.withValues(alpha: 0.85)),
            const SizedBox(width: 4),
            if (isLoading)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _zzzGreen,
                ),
              )
            else
              Text(
                '> $label',
                style: const TextStyle(
                  color: _zzzGreen,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZzzEditorButton extends StatelessWidget {
  const _ZzzEditorButton({
    required this.label,
    this.primary = false,
    this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? _zzzRed.withValues(alpha: 0.18)
              : _zzzGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: primary
                ? _zzzRed.withValues(alpha: 0.55)
                : _zzzGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          '> $label',
          style: TextStyle(
            color: primary ? _zzzRed : _zzzGreen,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ModernTimePicker extends StatelessWidget {
  const _ModernTimePicker({
    required this.value,
    required this.onChanged,
    this.isZzz = false,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool isZzz;

  String _timeLabel() {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dateLabel() {
    final y = value.year;
    final mo = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$mo-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      final tl = _timeLabel();
      final dl = _dateLabel();
      return Container(
        decoration: BoxDecoration(
          color: _zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: _zzzGreen.withValues(alpha: 0.45),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 16, color: _zzzGreen),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value),
                  );
                  if (time == null || !context.mounted) return;
                  onChanged(DateTime(value.year, value.month, value.day,
                      time.hour, time.minute));
                },
                child: Text(
                  '> SET_TIME: $tl  > SET_DATE: $dl',
                  style: const TextStyle(
                    color: _zzzGreen,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (date == null || !context.mounted) return;
                onChanged(DateTime(date.year, date.month, date.day,
                    value.hour, value.minute));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_dateLabel(),
                        style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(value),
                );
                if (time == null || !context.mounted) return;
                onChanged(DateTime(value.year, value.month, value.day,
                    time.hour, time.minute));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_timeLabel(),
                        style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBand extends StatelessWidget {
  const _EmptyBand({
    required this.title,
    required this.message,
    this.isZzz = false,
  });

  final String title;
  final String message;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: _zzzGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 18, color: _zzzSilver),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> NO_DATA: $title',
                    style: const TextStyle(
                      color: _zzzSilver,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: _zzzSilver,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
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

Color _colorFromHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class _ZzzCapsuleClipper extends CustomClipper<Path> {
  const _ZzzCapsuleClipper({required this.chamfer});

  final double chamfer;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(chamfer, 0);
    path.lineTo(w - chamfer, 0);
    path.lineTo(w, chamfer);
    path.lineTo(w, h - chamfer);
    path.lineTo(w - chamfer, h);
    path.lineTo(chamfer, h);
    path.lineTo(0, h - chamfer);
    path.lineTo(0, chamfer);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ZzzScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0D00FF41)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TagChips extends StatelessWidget {
  const _TagChips({
    required this.tagIds,
    required this.tags,
    required this.isZzz,
  });

  final List<int> tagIds;
  final List<PlannerTag> tags;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final matched = tags.where((t) => tagIds.contains(t.id)).toList();
    if (matched.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: matched.map((tag) {
        final color = _colorFromHex(tag.color);
        if (isZzz) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  tag.name,
                  style: const TextStyle(
                    color: _zzzTextColor,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                tag.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
