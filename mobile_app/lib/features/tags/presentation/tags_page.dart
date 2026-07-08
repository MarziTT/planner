import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tag_model.dart';
import '../state/tags_controller.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('标签管理', style: Theme.of(context).textTheme.titleLarge)),
            FilledButton.icon(
              onPressed: () => _showTagDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (state.tags.isEmpty && !state.loading)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('还没有标签，现在已经可以新增、编辑、删除。'))),
        ...state.tags.map((tag) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: _colorFromHex(tag.color), radius: 10),
                  title: Text(tag.name),
                  subtitle: Text(tag.color),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(onPressed: () => _showTagDialog(context, ref, tag: tag), icon: const Icon(Icons.edit_outlined)),
                      IconButton(onPressed: () => ref.read(tagsControllerProvider.notifier).remove(tag.id), icon: const Icon(Icons.delete_outline)),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _showTagDialog(BuildContext context, WidgetRef ref, {PlannerTag? tag}) async {
    final nameController = TextEditingController(text: tag?.name ?? '');
    final colorController = TextEditingController(text: tag?.color ?? '#5B8CFF');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? '新增标签' : '编辑标签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 12),
            TextField(controller: colorController, decoration: const InputDecoration(labelText: '颜色 HEX')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('保存')),
        ],
      ),
    );
    if (result != true) return;
    final name = nameController.text.trim();
    final color = colorController.text.trim().isEmpty ? '#5B8CFF' : colorController.text.trim();
    if (name.isEmpty) return;
    if (tag == null) {
      await ref.read(tagsControllerProvider.notifier).create(name, color);
    } else {
      await ref.read(tagsControllerProvider.notifier).update(tag, name, color);
    }
  }

  Color _colorFromHex(String value) {
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF5B8CFF);
  }
}
