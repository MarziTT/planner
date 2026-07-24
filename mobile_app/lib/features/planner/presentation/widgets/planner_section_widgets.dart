import 'package:flutter/material.dart';

import '../../domain/planner_models.dart';
import '../../../tags/domain/tag_model.dart';
import 'planner_zzz_decoration.dart';

// ── Reminder Return Banner ────────────────────────────────────────────────
class ReminderReturnBanner extends StatelessWidget {
  const ReminderReturnBanner({
    super.key,
    required this.event,
    required this.isZzz,
  });

  final PlannerEvent event;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Container(
        decoration: BoxDecoration(
          color: zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: zzzGreen.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 16, color: zzzGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '> RETURN: ${timeLabel(event.startsAt)}  ${event.title}',
                style: const TextStyle(
                  color: zzzGreen,
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
                  '${timeLabel(event.startsAt)} ${event.title}',
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

// ── Work Mode Quick Panel ─────────────────────────────────────────────────
class WorkQuickAction {
  const WorkQuickAction(this.title, this.icon);

  final String title;
  final IconData icon;
}

class WorkModeQuickPanel extends StatelessWidget {
  const WorkModeQuickPanel({
    super.key,
    required this.todos,
    required this.onCreate,
    this.isZzz = false,
  });

  final List<PlannerTodo> todos;
  final Future<void> Function(String title) onCreate;
  final bool isZzz;

  static const _actions = [
    WorkQuickAction('开发', Icons.code_rounded),
    WorkQuickAction('开会', Icons.groups_rounded),
    WorkQuickAction('沟通', Icons.chat_bubble_outline_rounded),
    WorkQuickAction('复盘', Icons.fact_check_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTitles = todos
        .where((todo) => !todo.completed)
        .map((todo) => todo.title.trim())
        .toSet();

    final bgColor = isZzz
        ? zzzSurfaceColor
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.52);
    final borderColor = isZzz
        ? zzzGreen.withValues(alpha: 0.2)
        : theme.colorScheme.primary.withValues(alpha: 0.14);
    final accentColor = isZzz ? zzzGreen : theme.colorScheme.primary;
    final textDim = isZzz ? zzzSilver : theme.colorScheme.onSurfaceVariant;
    final chipBg = isZzz ? zzzBgColor : theme.colorScheme.surface;
    final chipDisabled = isZzz
        ? zzzSurfaceColor.withValues(alpha: 0.78)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);
    final chipExistsBorder = isZzz
        ? zzzSilver.withValues(alpha: 0.15)
        : theme.colorScheme.outlineVariant;
    final chipBorder = isZzz
        ? zzzGreen.withValues(alpha: 0.3)
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
                  color: zzzGreen.withValues(alpha: 0.04),
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
              Icon(Icons.bolt_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZzz ? '> WORK_MODE' : '上班模式',
                  style: (isZzz
                      ? const TextStyle(
                          color: zzzGreen,
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

// ── Inline Error ──────────────────────────────────────────────────────────
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.isZzz = false,
    this.onRetry,
  });

  final String message;
  final bool isZzz;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isZzz) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: zzzRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: zzzRed.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: zzzRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '> ERROR: $message',
                style: const TextStyle(
                  color: zzzRed,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: zzzRed,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  child: const Text('[ RETRY ]'),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18,
            color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onErrorContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
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
                color: zzzGreen,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                color: zzzSilver,
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
                  colors: [zzzGreen, Color(0x0000FF41)],
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

// ── Modern Time Picker ────────────────────────────────────────────────────
class ModernTimePicker extends StatelessWidget {
  const ModernTimePicker({
    super.key,
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
          color: zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: zzzGreen.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 16, color: zzzGreen),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value),
                  );
                  if (time == null || !context.mounted) return;
                  onChanged(DateTime(
                      value.year, value.month, value.day, time.hour, time.minute));
                },
                child: Text(
                  '> SET_TIME: $tl  > SET_DATE: $dl',
                  style: const TextStyle(
                    color: zzzGreen,
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
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
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
                onChanged(DateTime(
                    date.year, date.month, date.day, value.hour, value.minute));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_dateLabel(), style: theme.textTheme.bodyLarge),
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
                onChanged(DateTime(
                    value.year, value.month, value.day, time.hour, time.minute));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_timeLabel(), style: theme.textTheme.bodyLarge),
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

// ── Empty Band ────────────────────────────────────────────────────────────
class EmptyBand extends StatelessWidget {
  const EmptyBand({
    super.key,
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
          color: zzzSurfaceColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: zzzGreen.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 18, color: zzzSilver),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> NO_DATA: $title',
                    style: const TextStyle(
                      color: zzzSilver,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: zzzSilver,
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

// ── Tag Chips ─────────────────────────────────────────────────────────────
class TagChips extends StatelessWidget {
  const TagChips({
    super.key,
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
        final color = colorFromHex(tag.color);
        if (isZzz) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  tag.name,
                  style: const TextStyle(
                    color: zzzTextColor,
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
