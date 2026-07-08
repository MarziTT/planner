import 'package:flutter/material.dart';

class FitnessPanel extends StatelessWidget {
  const FitnessPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('力量训练', '胸背腿分化、器械记录、组间休息'),
      ('有氧恢复', '步行、慢跑、骑行与恢复提醒'),
      ('饮食执行', '蛋白、饮水、补剂和打卡节奏'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('训练模块', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('这里会承接旧版健身模板和训练流程，但用原生卡片和状态管理重写。'),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(item.$2),
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
