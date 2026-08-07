import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/memory_controller.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(memoryControllerProvider.notifier).load());
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空个人记忆？'),
        content: const Text('这会删除已学习的偏好和行为样本，但不会删除你的日程。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(memoryControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人记忆'),
        actions: [
          if (state.items.isNotEmpty)
            IconButton(onPressed: _clearAll, icon: const Icon(Icons.delete_sweep_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(memoryControllerProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                value: state.learningEnabled,
                onChanged: state.loading
                    ? null
                    : (value) => ref
                        .read(memoryControllerProvider.notifier)
                        .setLearningEnabled(value),
                title: const Text('允许学习我的行为习惯'),
                subtitle: const Text('只使用你确认、修改或完成的行为；关闭后不再新增个人记忆。'),
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 12),
            if (state.loading && state.items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (state.items.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('还没有学习到个人习惯。你确认几次日程、运动或饮食记录后，这里会出现可管理的记忆。')))
            else
              ...state.items.map(
                (memory) => Card(
                  child: ListTile(
                    title: Text(memory.summary),
                    subtitle: Text('${memory.category} · ${memory.evidenceCount} 次确认 · ${(memory.confidence * 100).round()}%'),
                    leading: Icon(memory.active ? Icons.auto_awesome_outlined : Icons.pause_circle_outline),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'toggle') {
                          ref.read(memoryControllerProvider.notifier).setActive(memory, !memory.active);
                        } else if (value == 'delete') {
                          ref.read(memoryControllerProvider.notifier).remove(memory.id);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(memory.active ? '停用' : '启用')),
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
