import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/parse_result.dart';

class ConfirmCard extends StatelessWidget {
  const ConfirmCard({
    super.key,
    required this.result,
    required this.onConfirm,
    this.isZzz = false,
  });

  final ParseResult result;
  final VoidCallback onConfirm;
  final bool isZzz;

  String _formatDateTime(DateTime dt) {
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final fmt = DateFormat('M月d日');
    final weekday = weekdayNames[dt.weekday - 1];
    final time = DateFormat('HH:mm').format(dt);
    return '${fmt.format(dt)} $weekday $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final start = result.datetimeStart;
    final end = result.datetimeEnd;

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
          if (result.eventName != null) ...[
            Row(
              children: [
                Icon(Icons.event_note, size: 18,
                    color: isZzz ? colorScheme.primary : colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.eventName!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (start != null) ...[
            Row(
              children: [
                Icon(Icons.access_time, size: 18,
                    color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  end != null
                      ? '${_formatDateTime(start)} - ${DateFormat('HH:mm').format(end)}'
                      : _formatDateTime(start),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (result.person != null) ...[
            Row(
              children: [
                Icon(Icons.person_outline, size: 18,
                    color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  result.person!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (result.location != null) ...[
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18,
                    color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  result.location!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (result.isFuzzy) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16,
                    color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '时间已自动补全，可点击确认安排',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('确认安排'),
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
}
