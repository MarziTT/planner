import 'package:flutter/material.dart';

class FitnessPanel extends StatelessWidget {
  const FitnessPanel({
    super.key,
    required this.modeLabel,
    required this.goal,
  });

  final String modeLabel;
  final String goal;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('训练方式', modeLabel),
      ('执行重点', goal.isEmpty ? '先把每周固定训练节奏跑起来。' : goal),
      ('训练提醒', '训练前热身、训练后拉伸和饮水提醒会在这里承接。'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('训练模块', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('你已经在资料页开启了健身安排，这里会按你的训练方式展示更贴近的模块。'),
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
