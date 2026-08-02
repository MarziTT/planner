import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zzz_theme_extension.dart';

class FitnessPanel extends ConsumerWidget {
  const FitnessPanel({
    super.key,
    required this.modeLabel,
    required this.goal,
  });

  final String modeLabel;
  final String goal;

  IconData _modeIcon() {
    switch (modeLabel) {
      case '挂训':
        return Icons.sports_martial_arts;
      case '跟课':
        return Icons.play_circle_outline;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final isZzz = ref.watch(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;

    final bgColor =
        isZzz ? zzz?.surfaceLow : theme.colorScheme.surfaceContainerLow;
    final borderColor = isZzz
        ? zzz?.borderGlow ?? theme.colorScheme.outlineVariant
        : theme.colorScheme.outlineVariant;
    final accentColor = isZzz
        ? zzz?.accent ?? theme.colorScheme.primary
        : theme.colorScheme.primary;
    final textColor = isZzz ? zzz?.textPrimary : null;
    final dimTextColor =
        isZzz ? zzz?.textSecondary : theme.colorScheme.onSurfaceVariant;
    final surfaceColor = isZzz ? zzz?.surface : theme.colorScheme.surface;

    final items = [
      _FitnessDetail(
        icon: _modeIcon(),
        label: '训练方式',
        value: modeLabel,
        accent: accentColor,
      ),
      _FitnessDetail(
        icon: Icons.track_changes_outlined,
        label: '执行重点',
        value: goal.isEmpty ? '先把每周固定训练节奏跑起来。' : goal,
        accent: accentColor,
      ),
      _FitnessDetail(
        icon: Icons.notifications_active_outlined,
        label: '训练提醒',
        value: '训练前热身、训练后拉伸和饮水提醒会在这里承接。',
        accent: accentColor,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isZzz ? 8 : 16),
        border: Border.all(color: borderColor),
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZzz ? '> TRAINING_MODULE' : '训练模块',
                  style: isZzz
                      ? TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: zzz?.terminalFontFamily,
                        )
                      : theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '你已经在资料页开启了健身安排，这里会按你的训练方式展示更贴近的模块。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: dimTextColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(isZzz ? 8 : 10),
                  border: isZzz
                      ? Border.all(
                          color: zzz?.borderColor ??
                              accentColor.withValues(alpha: 0.12))
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 16, color: item.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: dimTextColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FitnessDetail {
  const _FitnessDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
}
