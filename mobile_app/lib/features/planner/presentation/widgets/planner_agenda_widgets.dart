import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tags/state/tags_controller.dart';
import '../../domain/planner_models.dart';
import '../../state/planner_controller.dart';
import 'planner_section_widgets.dart';
import 'planner_zzz_decoration.dart';

// ── Agenda Item Model ──────────────────────────────────────────────────────
enum AgendaItemKind { event, todo }

class AgendaItem {
  const AgendaItem.event(PlannerEvent this.event)
      : todo = null,
        kind = AgendaItemKind.event;

  const AgendaItem.todo(PlannerTodo this.todo)
      : event = null,
        kind = AgendaItemKind.todo;

  final AgendaItemKind kind;
  final PlannerEvent? event;
  final PlannerTodo? todo;
}

List<AgendaItem> buildAgendaItems({
  required DateTime selectedDay,
  required DateTime today,
  required List<PlannerEvent> events,
  required List<PlannerTodo> todos,
  required bool includeTodos,
}) {
  final items = <AgendaItem>[
    ...events.map(AgendaItem.event),
    if (includeTodos) ...todos.map(AgendaItem.todo),
  ];
  items.sort((left, right) {
    final leftDone = left.kind == AgendaItemKind.event
        ? left.event!.status == 'done'
        : left.todo!.completed;
    final rightDone = right.kind == AgendaItemKind.event
        ? right.event!.status == 'done'
        : right.todo!.completed;
    if (leftDone != rightDone) return leftDone ? 1 : -1;
    if (left.event != null && right.event != null) {
      return left.event!.startsAt.compareTo(right.event!.startsAt);
    }
    return 0;
  });
  return items;
}

// ── Agenda List ───────────────────────────────────────────────────────────
class AgendaList extends StatelessWidget {
  const AgendaList({
    super.key,
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

  final List<AgendaItem> items;
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
          return EventTile(
            event: event,
            highlighted: selectedEventId == event.id,
            zzzBackground: isZzzTheme ? zzzSpecForEvent(event) : null,
            isDeleting: deletingEventIds.contains(event.id),
            onEdit: () => onEditEvent(event),
            onDelete: () => onDeleteEvent(event),
            onToggle: () => onToggleEvent(event),
          );
        }
        final todo = item.todo!;
        return TodoTile(
          todo: todo,
          zzzBackground: isZzzTheme ? zzzSpecForTodo(todo) : null,
          isDeleting: deletingTodoIds.contains(todo.id),
          onEdit: () => onEditTodo(todo),
          onDelete: () => onDeleteTodo(todo),
        );
      }).toList(),
    );
  }
}

// ── Event Tile ────────────────────────────────────────────────────────────
class EventTile extends ConsumerWidget {
  const EventTile({
    super.key,
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
                          timeLabel(event.startsAt),
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
                                    horizontal: 8, vertical: 4),
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
                                    horizontal: 8, vertical: 4),
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
                          TagChips(
                            tagIds: event.tagIds,
                            tags: ref.watch(tagsControllerProvider).tags,
                            isZzz: isZzz,
                          ),
                        ],
                        Text(
                          timeLabel(event.startsAt),
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
                                          strokeWidth: 2),
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
        clipper: ZzzCapsuleClipper(chamfer: 12),
        child: Container(
          decoration: BoxDecoration(
            color: zzzSurfaceColor,
            border: Border.all(
              color: zzzGreen.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: zzzGreen.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [zzzGreen, Color(0x3300FF41)],
                    ),
                  ),
                ),
              ),
              if (zzzBackground != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 104,
                  child: Opacity(
                    opacity: 0.58,
                    child: ZzzSideArt(spec: zzzBackground!, opacity: 0.58),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(painter: ZzzScanlinePainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                            color: zzzGreen.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            timeLabel(event.startsAt),
                            style: const TextStyle(
                              color: zzzGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${event.startsAt.month}/${event.startsAt.day}',
                            style: TextStyle(
                              color: zzzGreen.withValues(alpha: 0.7),
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
                                    color: zzzTextColor,
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
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: zzzRed.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                        color: zzzRed.withValues(alpha: 0.6)),
                                  ),
                                  child: const Text(
                                    '当前提醒',
                                    style: TextStyle(
                                      color: zzzRed,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              if (_isDone && !highlighted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: zzzSilver.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    '已完成',
                                    style: TextStyle(
                                      color: zzzSilver,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (event.tagIds.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TagChips(
                              tagIds: event.tagIds,
                              tags: ref.watch(tagsControllerProvider).tags,
                              isZzz: true,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            timeLabel(event.startsAt),
                            style: const TextStyle(
                              color: zzzSilver,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ZzzActionButton(
                                icon: _isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                label: _isDone ? 'UNDO' : 'DONE',
                                isLoading: isDeleting,
                                onPressed: onToggle,
                              ),
                              const SizedBox(width: 8),
                              ZzzActionButton(
                                icon: Icons.edit_outlined,
                                label: 'EDIT',
                                onPressed: onEdit,
                              ),
                              const SizedBox(width: 8),
                              ZzzActionButton(
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

// ── Todo Tile ─────────────────────────────────────────────────────────────
class TodoTile extends ConsumerWidget {
  const TodoTile({
    super.key,
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
          clipper: ZzzCapsuleClipper(chamfer: 10),
          child: Container(
            decoration: BoxDecoration(
              color: zzzSurfaceColor,
              border: Border.all(
                color: todo.completed
                    ? zzzSilver.withValues(alpha: 0.3)
                    : zzzGreen.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (todo.completed ? zzzSilver : zzzGreen)
                      .withValues(alpha: 0.08),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: todo.completed
                            ? [zzzSilver, const Color(0x33A0A0B8)]
                            : [zzzRed, const Color(0x33FF1744)],
                      ),
                    ),
                  ),
                ),
                if (zzzBackground != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 88,
                    child: ZzzSideArt(spec: zzzBackground!, opacity: 0.36),
                  ),
                Positioned.fill(
                  child: CustomPaint(painter: ZzzScanlinePainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isDeleting
                            ? null
                            : () {
                                ref
                                    .read(plannerControllerProvider.notifier)
                                    .toggleTodo(todo, !todo.completed);
                              },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: todo.completed
                                ? zzzGreen.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: todo.completed
                                  ? zzzGreen.withValues(alpha: 0.6)
                                  : zzzSilver.withValues(alpha: 0.4),
                            ),
                          ),
                          child: todo.completed
                              ? const Icon(
                                  Icons.check, size: 14, color: zzzGreen)
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
                                color:
                                    todo.completed ? zzzSilver : zzzTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: 'monospace',
                                decoration: todo.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                ZzzActionButton(
                                  icon: Icons.edit_outlined,
                                  label: 'EDIT',
                                  onPressed: isDeleting ? null : onEdit,
                                ),
                                const SizedBox(width: 8),
                                ZzzActionButton(
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
                        if (value == null) return;
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
                        decoration:
                            todo.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todo.completed ? '已完成' : '待处理',
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
