import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/profile_model.dart';
import '../../profile/state/profile_controller.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.sell_outlined, size: 22, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('标签管理', style: theme.textTheme.titleLarge)),
            FilledButton.icon(
              onPressed: () => _showTagDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '先用几枚顺手的标签就够了，不用一上来分很细。',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        _SectionCard(
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
                side: added ? BorderSide(color: scheme.outlineVariant) : null,
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
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.errorMessage!,
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

        if (state.tags.isEmpty && !state.loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.sell_outlined, size: 36,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 10),
                Text('还没有标签，先加几个最常用的就行。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),

        ...state.tags.map(
          (tag) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _TagRow(
              tag: tag,
              onEdit: () => _showTagDialog(context, ref, tag: tag),
              onDelete: () => ref.read(tagsControllerProvider.notifier).remove(tag.id),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTagDialog(BuildContext context, WidgetRef ref, {PlannerTag? tag}) async {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final colorController = TextEditingController(text: tag?.color ?? '#5B8CFF');
    var isRecurring = tag?.isRecurring ?? false;
    var recurrenceRule = tag?.recurrenceRule ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(tag == null ? '新增标签' : '编辑标签'),
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
                    decoration: const InputDecoration(
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
                          decoration: const InputDecoration(
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
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('长期日程'),
                    subtitle: const Text('每天重复的事件，可独立修改单次时间'),
                    value: isRecurring,
                    onChanged: (value) => setLocalState(() => isRecurring = value),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: recurrenceRule.isEmpty ? 'daily' : recurrenceRule,
                      decoration: const InputDecoration(
                        labelText: '重复规则',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('每天')),
                        DropdownMenuItem(value: 'weekly', child: Text('每周')),
                        DropdownMenuItem(value: 'monthly', child: Text('每月')),
                        DropdownMenuItem(value: 'weekday', child: Text('工作日')),
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
  const _SectionCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
  const _TagRow({required this.tag, required this.onEdit, required this.onDelete});
  final PlannerTag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFromHex(tag.color);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tag.name, style: theme.textTheme.bodyMedium),
                Text(tag.color, style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, fontSize: 11, fontFamily: 'monospace',
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
          _CompactIconButton(icon: Icons.edit_outlined, onPressed: onEdit),
          _CompactIconButton(icon: Icons.delete_outline_rounded, onPressed: onDelete, isDestructive: true),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({required this.icon, required this.onPressed, this.isDestructive = false});
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: isDestructive ? scheme.error : scheme.onSurfaceVariant,
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
