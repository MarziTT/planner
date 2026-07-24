import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/state/profile_controller.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import '../domain/tag_model.dart';
import '../state/tags_controller.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagsControllerProvider);
    final profile = ref.watch(profileControllerProvider).profile;
    final presets = _presetTagsFor(profile?.identity ?? 'worker');
    final existingNames = state.tags.map((tag) => tag.name).toSet();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isZzz = ref.watch(themeControllerProvider).preset == PlannerThemePreset.kamenRiderZzz;

    return Stack(
      children: [
        Column(
          children: [
            // 操作加载指示器
            if (state.loading)
              LinearProgressIndicator(
                minHeight: 2,
                valueColor: AlwaysStoppedAnimation(
                  isZzz ? zzzGreen : scheme.primary,
                ),
                backgroundColor: isZzz
                    ? zzzGreen.withValues(alpha: 0.08)
                    : null,
              ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(tagsControllerProvider.notifier).load(),
              child: Container(
                color: isZzz ? zzzBgColor : null,
                child: state.loading && state.tags.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            SizedBox(height: 16),
                            Text('加载标签中...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  if (isZzz)
                    Container(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: zzzGreen,
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.sell_outlined, size: 22, color: zzzGreen),
                    )
                  else
                    Icon(Icons.sell_outlined, size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('标签管理',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isZzz ? zzzGreenLight : null,
                  ))),
              FilledButton.icon(
                onPressed: () => _showTagDialog(context, ref, isZzz: isZzz),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
                style: isZzz
                    ? FilledButton.styleFrom(
                        backgroundColor: zzzGreen,
                        foregroundColor: zzzBgColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ).copyWith(
                        shadowColor: WidgetStateProperty.all(zzzGreen),
                        elevation: WidgetStateProperty.all(6),
                      )
                    : FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '先用几枚顺手的标签就够了，不用一上来分很细。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isZzz ? zzzGreenLight : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          _SectionCard(
            isZzz: isZzz,
            title: '${_identityLabel(profile?.identity ?? 'worker')}常用标签',
            subtitle: '点一下就加到你的标签库里。',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((preset) {
                final added = existingNames.contains(preset.name);
                return ActionChip(
                  avatar: CircleAvatar(radius: 7, backgroundColor: _colorFromHex(preset.color)),
                  label: Text(
                    added ? '${preset.name} 已有' : preset.name,
                    style: TextStyle(fontSize: 13, color: added ? scheme.onSurfaceVariant : null),
                  ),
                  onPressed: added
                      ? null
                      : () => ref.read(tagsControllerProvider.notifier).create(preset.name, preset.color),
                  side: added
                      ? BorderSide(color: isZzz ? zzzGreen : scheme.outlineVariant)
                      : (isZzz ? const BorderSide(color: zzzGreen) : null),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isZzz
                      ? const [
                          BoxShadow(
                            color: zzzRed,
                            blurRadius: 10,
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(state.errorMessage!,
                          style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: () => ref.read(tagsControllerProvider.notifier).load(),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),

          if (state.tags.isEmpty && !state.loading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: isZzz ? zzzSurfaceColor : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: isZzz ? Border.all(color: zzzGreen) : null,
              ),
              child: Column(
                children: [
                  Icon(Icons.sell_outlined, size: 36,
                      color: isZzz
                          ? zzzGreen.withValues(alpha: 0.4)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 10),
                  Text('还没有标签，先加几个最常用的就行。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isZzz ? zzzGreenLight : scheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),

          ...state.tags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _TagRow(
                isZzz: isZzz,
                tag: tag,
                onEdit: () => _showTagDialog(context, ref, tag: tag, isZzz: isZzz),
                onDelete: () => ref.read(tagsControllerProvider.notifier).remove(tag.id),
              ),
            ),
          ),
                ], // ListView children
              ), // ListView / Center
            ), // Container
          ), // RefreshIndicator
        ), // Expanded
        ], // Column children
      ), // Column
      if (isZzz)
        Positioned(
          right: 0,
          bottom: 0,
          child: ZzzCornerArt(
            spec: zzzSpecFromSeed(DateTime.now().day + 5),
            size: 64,
            opacity: 0.28,
          ),
        ),
    ]);
  }

  Future<void> _showTagDialog(BuildContext context, WidgetRef ref, {PlannerTag? tag, bool isZzz = false}) async {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final colorController = TextEditingController(text: tag?.color ?? '#5B8CFF');
    var isRecurring = tag?.isRecurring ?? false;
    var recurrenceRule = tag?.recurrenceRule ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: isZzz ? zzzSurfaceColor : null,
          shape: isZzz
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: zzzGreen),
                )
              : null,
          title: Text(tag == null ? '新增标签' : '编辑标签',
              style: isZzz ? const TextStyle(color: zzzGreenLight) : null),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: isZzz ? const TextStyle(color: zzzGreenLight) : null,
                    decoration: isZzz
                        ? const InputDecoration(
                            labelText: '名称',
                            labelStyle: TextStyle(color: zzzGreen),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: zzzGreen),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: zzzGreen),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: zzzGreen),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          )
                        : const InputDecoration(
                            labelText: '名称',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController,
                          style: isZzz ? const TextStyle(color: zzzGreenLight) : null,
                          decoration: isZzz
                              ? const InputDecoration(
                                  labelText: '颜色 HEX',
                                  labelStyle: TextStyle(color: zzzGreen),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: zzzGreen),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: zzzGreen),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: zzzGreen),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                )
                              : const InputDecoration(
                                  labelText: '颜色 HEX',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _colorFromHex(
                            colorController.text.trim().isEmpty ? '#5B8CFF' : colorController.text.trim(),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isZzz
                                ? zzzGreen
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('长期日程',
                        style: isZzz
                            ? const TextStyle(color: zzzGreenLight)
                            : null),
                    subtitle: Text('每天重复的事件，可独立修改单次时间',
                        style: isZzz
                            ? const TextStyle(color: zzzGreen)
                            : null),
                    value: isRecurring,
                    onChanged: (value) => setLocalState(() => isRecurring = value),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: recurrenceRule.isEmpty ? 'daily' : recurrenceRule,
                      decoration: isZzz
                          ? const InputDecoration(
                              labelText: '重复规则',
                              labelStyle: TextStyle(color: zzzGreen),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: zzzGreen),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: zzzGreen),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: zzzGreen),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            )
                          : const InputDecoration(
                              labelText: '重复规则',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                      items: [
                        DropdownMenuItem(
                            value: 'daily',
                            child: Text('每天',
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null)),
                        DropdownMenuItem(
                            value: 'weekly',
                            child: Text('每周',
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null)),
                        DropdownMenuItem(
                            value: 'monthly',
                            child: Text('每月',
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null)),
                        DropdownMenuItem(
                            value: 'weekday',
                            child: Text('工作日',
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null)),
                      ],
                      onChanged: (value) => setLocalState(() => recurrenceRule = value ?? 'daily'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消',
                  style: isZzz ? const TextStyle(color: zzzGreen) : null),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isZzz
                  ? FilledButton.styleFrom(
                      backgroundColor: zzzGreen,
                      foregroundColor: zzzBgColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ).copyWith(
                      shadowColor: WidgetStateProperty.all(zzzGreen),
                      elevation: WidgetStateProperty.all(6),
                    )
                  : null,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final name = nameController.text.trim();
    final color = colorController.text.trim().isEmpty ? '#5B8CFF' : colorController.text.trim();
    if (name.isEmpty) return;
    if (tag == null) {
      await ref.read(tagsControllerProvider.notifier).create(
            name, color,
            isRecurring: isRecurring, recurrenceRule: recurrenceRule,
          );
    } else {
      await ref.read(tagsControllerProvider.notifier).update(
            tag, name, color,
            isRecurring: isRecurring, recurrenceRule: recurrenceRule,
          );
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child, this.isZzz = false});
  final String title;
  final String? subtitle;
  final Widget child;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isZzz ? zzzSurfaceColor : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isZzz ? zzzGreen : theme.colorScheme.outlineVariant,
        ),
        boxShadow: isZzz
            ? const [
                BoxShadow(
                  color: zzzGreen,
                  blurRadius: 8,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: isZzz
                  ? theme.textTheme.titleSmall?.copyWith(color: zzzGreen)
                  : theme.textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isZzz ? zzzGreenLight : theme.colorScheme.onSurfaceVariant,
                )),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, required this.onEdit, required this.onDelete, this.isZzz = false});
  final PlannerTag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFromHex(tag.color);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isZzz ? zzzSurfaceColor : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isZzz ? zzzGreen : scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isZzz
                  ? [
                      BoxShadow(
                        color: color,
                        blurRadius: 6,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isZzz ? zzzGreenLight : null,
                    )),
                Text(tag.color,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isZzz ? zzzGreenLight.withValues(alpha: 0.6) : scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    )),
              ],
            ),
          ),
          if (tag.isRecurring)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_recurrenceLabel(tag.recurrenceRule),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
          _CompactIconButton(icon: Icons.edit_outlined, onPressed: onEdit, isZzz: isZzz),
          _CompactIconButton(icon: Icons.delete_outline_rounded, onPressed: onDelete, isDestructive: true, isZzz: isZzz),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({required this.icon, required this.onPressed, this.isDestructive = false, this.isZzz = false});
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isZzz
        ? zzzGreen
        : (isDestructive ? scheme.error : scheme.onSurfaceVariant);
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: color,
        ),
      ),
    );
  }
}

String _recurrenceLabel(String rule) {
  switch (rule) {
    case 'daily': return '每天';
    case 'weekly': return '每周';
    case 'monthly': return '每月';
    case 'weekday': return '工作日';
    default: return '重复';
  }
}

class _PresetTag {
  const _PresetTag(this.name, this.color);
  final String name;
  final String color;
}

List<_PresetTag> _presetTagsFor(String identity) {
  switch (identity) {
    case 'student':
      return const [
        _PresetTag('上课', '#4F46E5'), _PresetTag('自习', '#2563EB'), _PresetTag('作业', '#7C3AED'),
        _PresetTag('社团', '#0F766E'), _PresetTag('考试', '#DC2626'),
      ];
    case 'caregiver':
      return const [
        _PresetTag('买菜', '#16A34A'), _PresetTag('接送', '#2563EB'), _PresetTag('家务', '#EA580C'),
        _PresetTag('家庭', '#DB2777'), _PresetTag('休息', '#64748B'),
      ];
    case 'freelancer':
      return const [
        _PresetTag('客户', '#2563EB'), _PresetTag('交付', '#7C3AED'), _PresetTag('创作', '#D97706'),
        _PresetTag('沟通', '#0F766E'), _PresetTag('运动', '#DC2626'),
      ];
    case 'worker':
    default:
      return const [
        _PresetTag('站会', '#2563EB'), _PresetTag('开发', '#4F46E5'), _PresetTag('通勤', '#0F766E'),
        _PresetTag('复盘', '#D97706'), _PresetTag('健身', '#DC2626'),
      ];
  }
}

String _identityLabel(String identity) {
  return UserProfile.identityLabels[identity] ?? '上班族';
}

Color _colorFromHex(String value) {
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.tryParse(normalized, radix: 16) ?? 0xFF5B8CFF);
}
