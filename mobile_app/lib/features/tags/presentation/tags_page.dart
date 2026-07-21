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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('标签管理', style: Theme.of(context).textTheme.titleLarge),
            ),
            FilledButton.icon(
              onPressed: () => _showTagDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '先用几枚顺手的标签就够了，不用一上来分很细。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_identityLabel(profile?.identity ?? 'worker')}常用标签',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '点一下就加到你的标签库里。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) {
                  final added = existingNames.contains(preset.name);
                  return ActionChip(
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: _colorFromHex(preset.color),
                    ),
                    label: Text(added ? '${preset.name} 已有' : preset.name),
                    onPressed: added
                        ? null
                        : () => ref
                            .read(tagsControllerProvider.notifier)
                            .create(preset.name, preset.color),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (state.tags.isEmpty && !state.loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有标签，先加几个最常用的就行。'),
            ),
          ),
        ...state.tags.map(
          (tag) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorFromHex(tag.color),
                  radius: 10,
                ),
                title: Text(tag.name),
                subtitle: Text(tag.color),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: () => _showTagDialog(context, ref, tag: tag),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.read(tagsControllerProvider.notifier).remove(tag.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTagDialog(BuildContext context, WidgetRef ref,
      {PlannerTag? tag}) async {
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
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: colorController,
                    decoration: const InputDecoration(labelText: '颜色 HEX'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('长期日程'),
                    subtitle: const Text('每天重复的事件，可独立修改单次时间'),
                    value: isRecurring,
                    onChanged: (value) =>
                        setLocalState(() => isRecurring = value),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: recurrenceRule.isEmpty ? 'daily' : recurrenceRule,
                      decoration: const InputDecoration(labelText: '重复规则'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('每天')),
                        DropdownMenuItem(value: 'weekly', child: Text('每周')),
                        DropdownMenuItem(value: 'monthly', child: Text('每月')),
                        DropdownMenuItem(value: 'weekday', child: Text('工作日')),
                      ],
                      onChanged: (value) => setLocalState(
                          () => recurrenceRule = value ?? 'daily'),
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
    final color =
        colorController.text.trim().isEmpty ? '#5B8CFF' : colorController.text.trim();
    if (name.isEmpty) return;
    if (tag == null) {
      await ref.read(tagsControllerProvider.notifier).create(
        name,
        color,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule,
      );
    } else {
      await ref.read(tagsControllerProvider.notifier).update(
        tag,
        name,
        color,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule,
      );
    }
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
        _PresetTag('上课', '#4F46E5'),
        _PresetTag('自习', '#2563EB'),
        _PresetTag('作业', '#7C3AED'),
        _PresetTag('社团', '#0F766E'),
        _PresetTag('考试', '#DC2626'),
      ];
    case 'caregiver':
      return const [
        _PresetTag('买菜', '#16A34A'),
        _PresetTag('接送', '#2563EB'),
        _PresetTag('家务', '#EA580C'),
        _PresetTag('家庭', '#DB2777'),
        _PresetTag('休息', '#64748B'),
      ];
    case 'freelancer':
      return const [
        _PresetTag('客户', '#2563EB'),
        _PresetTag('交付', '#7C3AED'),
        _PresetTag('创作', '#D97706'),
        _PresetTag('沟通', '#0F766E'),
        _PresetTag('运动', '#DC2626'),
      ];
    case 'worker':
    default:
      return const [
        _PresetTag('站会', '#2563EB'),
        _PresetTag('开发', '#4F46E5'),
        _PresetTag('通勤', '#0F766E'),
        _PresetTag('复盘', '#D97706'),
        _PresetTag('健身', '#DC2626'),
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