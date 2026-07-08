import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/import_export_controller.dart';

class ImportExportPanel extends ConsumerWidget {
  const ImportExportPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importExportControllerProvider);

    ref.listen(importExportControllerProvider, (previous, next) {
      final message = next.message;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导入导出', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('新架构会保留导出备份与导入恢复，但不再依赖旧 localStorage 结构。'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.loading ? null : () => ref.read(importExportControllerProvider.notifier).importSample(),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('导入示例'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.loading ? null : () => ref.read(importExportControllerProvider.notifier).exportData(),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(state.loading ? '处理中...' : '导出数据'),
                  ),
                ),
              ],
            ),
            if (state.snapshot != null) ...[
              const SizedBox(height: 12),
              Text('当前快照: ${state.snapshot!.eventCount} 行程 / ${state.snapshot!.todoCount} 待办 / ${state.snapshot!.tagCount} 标签'),
            ],
          ],
        ),
      ),
    );
  }
}
