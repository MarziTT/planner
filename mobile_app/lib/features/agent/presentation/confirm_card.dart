import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../scheduler/domain/scheduler_models.dart';
import '../domain/parse_result.dart';

/// Multi-intent confirmation card — handles all agent intents.
///
/// Renders different UI based on result.intent:
/// - create_event: full schedule card (person, location, time, conflict check)
/// - log_meal/log_exercise/log_routine/create_reminder: compact confirm card
class ConfirmCard extends StatelessWidget {
  const ConfirmCard({
    super.key,
    required this.result,
    required this.onConfirm,
    this.onCancel,
    this.onEdit,
    this.isZzz = false,
    this.conflicts,
    this.suggestions,
    this.isCheckingConflicts = false,
  });

  final ParseResult result;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final ValueChanged<ParseResult>? onEdit;
  final bool isZzz;
  final ConflictCheck? conflicts;
  final List<TimeSuggestion>? suggestions;
  final bool isCheckingConflicts;

  @override
  Widget build(BuildContext context) {
    switch (result.intent) {
      case 'create_event':
        return _buildEventCard(context);
      case 'log_meal':
        return _buildSimpleCard(
            context, Icons.restaurant, '记录饮食', _mealSummary());
      case 'log_exercise':
        return _buildSimpleCard(
            context, Icons.fitness_center, '记录运动', _exerciseSummary());
      case 'log_routine':
        return _buildSimpleCard(
            context, Icons.bedtime, '记录作息', _routineSummary());
      case 'create_reminder':
        return _buildSimpleCard(
            context, Icons.notifications, '创建提醒', _reminderSummary());
      default:
        return _buildSimpleCard(
            context, Icons.check, '确认', result.eventName ?? '确认执行此操作？');
    }
  }

  // -----------------------------------------------------------------------
  //  create_event card (existing logic, unchanged)
  // -----------------------------------------------------------------------

  String _formatDateTime(DateTime dt) {
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final fmt = DateFormat('M月d日');
    final weekday = weekdayNames[dt.weekday - 1];
    final time = DateFormat('HH:mm').format(dt);
    return '${fmt.format(dt)} $weekday $time';
  }

  Widget _buildEventCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final start = result.datetimeStart;
    final end = result.datetimeEnd;
    final conflicts = this.conflicts;
    final suggestions = this.suggestions;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isZzz
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.eventName != null) ...[
            Row(
              children: [
                Icon(Icons.event_note, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.eventName!,
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (start != null) ...[
            Row(children: [
              Icon(Icons.access_time,
                  size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                end != null
                    ? '${_formatDateTime(start)} - ${DateFormat('HH:mm').format(end)}'
                    : _formatDateTime(start),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ]),
            const SizedBox(height: 6),
          ],
          if (result.person != null) ...[
            Row(children: [
              Icon(Icons.person_outline,
                  size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(result.person!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
          ],
          if (result.location != null) ...[
            Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(result.location!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ]),
          ],
          if (result.isFuzzy) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Text('时间已自动补全��可点击确认安排',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.secondary)),
            ]),
          ],
          if (isCheckingConflicts) ...[
            const SizedBox(height: 12),
            _buildCheckingRow(theme),
          ],
          if (!isCheckingConflicts &&
              conflicts != null &&
              conflicts.hasConflicts) ...[
            const SizedBox(height: 12),
            _buildConflictSection(theme, colorScheme, conflicts),
          ],
          if (!isCheckingConflicts &&
              conflicts != null &&
              conflicts.hasConflicts &&
              suggestions != null &&
              suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSuggestionsSection(theme, colorScheme, suggestions),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: '修改日程',
                onPressed: onEdit == null ? null : () => _editEvent(context),
                icon: const Icon(Icons.edit_outlined),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: Icon(
                    conflicts != null && conflicts.hasConflicts
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    conflicts != null && conflicts.hasConflicts
                        ? '仍然安排'
                        : '确认安排',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isZzz ? colorScheme.primary : null,
                    foregroundColor: isZzz ? colorScheme.onPrimary : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editEvent(BuildContext context) async {
    final start = result.datetimeStart;
    if (start == null || onEdit == null) return;

    final end = result.datetimeEnd ?? start.add(const Duration(hours: 1));
    final titleController = TextEditingController(text: result.eventName ?? '');
    final startController = TextEditingController(text: _dateTimeText(start));
    final endController = TextEditingController(text: _dateTimeText(end));

    try {
      final updated = await showDialog<ParseResult>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('修改日程'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '事项'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(
                  labelText: '开始时间',
                  helperText: '格式：2026-08-05 19:00',
                ),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: '结束时间'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final editedStart = _parseDateTime(startController.text);
                final editedEnd = _parseDateTime(endController.text);
                if (title.isEmpty ||
                    editedStart == null ||
                    editedEnd == null ||
                    !editedEnd.isAfter(editedStart)) {
                  return;
                }
                Navigator.pop(
                  context,
                  result.copyWith(
                    eventName: title,
                    datetimeStart: editedStart,
                    datetimeEnd: editedEnd,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (updated != null) onEdit!(updated);
    } finally {
      titleController.dispose();
      startController.dispose();
      endController.dispose();
    }
  }

  String _dateTimeText(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  DateTime? _parseDateTime(String value) {
    return DateTime.tryParse(value.trim().replaceFirst(' ', 'T'));
  }

  // -----------------------------------------------------------------------
  //  Simple card for meal / exercise / routine / reminder
  // -----------------------------------------------------------------------

  Widget _buildSimpleCard(
      BuildContext context, IconData icon, String title, String detail) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isZzz
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(title,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          ]),
          const SizedBox(height: 10),
          Text(detail,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('确认'),
              style: FilledButton.styleFrom(
                backgroundColor: isZzz ? colorScheme.primary : null,
                foregroundColor: isZzz ? colorScheme.onPrimary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  //  Intent → summary string
  // -----------------------------------------------------------------------

  String _mealSummary() {
    final meal = result.mealType ?? '餐食';
    final food = result.foodName ?? '';
    final cal = result.caloriesEstimate;
    final parts = <String>['类型: $meal'];
    if (food.isNotEmpty) parts.add('内容: $food');
    if (cal != null) parts.add('约 ${cal}kcal');
    return parts.join('\n');
  }

  String _exerciseSummary() {
    final type = result.exerciseType ?? '运动';
    final mins = result.durationMinutes;
    final intensity = result.intensity ?? '中';
    final parts = <String>['类型: $type'];
    if (mins != null) parts.add('时长: $mins分钟');
    parts.add('强度: $intensity');
    return parts.join('\n');
  }

  String _routineSummary() {
    final rtype = result.routineType ?? '';
    final rval = result.routineValue ?? '';
    switch (rtype) {
      case 'wake':
        return '起床时间: $rval';
      case 'sleep':
        return '入睡时间: $rval';
      case 'standing':
        return '站立完成';
      default:
        return '$rtype: $rval';
    }
  }

  String _reminderSummary() {
    final text = result.reminderText ?? '';
    final start = result.datetimeStart;
    if (start != null) {
      return '提醒内容: $text\n时间: ${DateFormat('M月d日 HH:mm').format(start)}';
    }
    return '提醒内容: $text';
  }

  // -----------------------------------------------------------------------
  //  Conflict / suggestion helpers (unchanged)
  // -----------------------------------------------------------------------

  Widget _buildCheckingRow(ThemeData theme) {
    return Row(children: [
      const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2)),
      const SizedBox(width: 8),
      Text('正在检查日程冲突...',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }

  Widget _buildConflictSection(
      ThemeData theme, ColorScheme colorScheme, ConflictCheck conflicts) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Text('检测到 ${conflicts.conflicts.length} 个时间冲突',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
        ]),
        const SizedBox(height: 6),
        ...conflicts.conflicts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const SizedBox(width: 22),
                Expanded(
                    child: Text('${c.title}  ${c.timeRangeLabel}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.orange.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
            )),
      ]),
    );
  }

  Widget _buildSuggestionsSection(ThemeData theme, ColorScheme colorScheme,
      List<TimeSuggestion>? suggestions) {
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final top = suggestions.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text('建议时段',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.green.shade800)),
        ]),
        const SizedBox(height: 6),
        ...top.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const SizedBox(width: 22),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s.timeRangeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800)),
                ),
                const SizedBox(width: 6),
                Text(s.periodLabel,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const Spacer(),
                Icon(Icons.thumb_up_outlined,
                    size: 14, color: Colors.green.shade600),
                const SizedBox(width: 2),
                Text('${s.score}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700)),
              ]),
            )),
      ]),
    );
  }
}
