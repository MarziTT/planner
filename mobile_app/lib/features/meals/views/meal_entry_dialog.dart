import 'package:flutter/material.dart';

import '../models/meal.dart';

/// 手动录入餐食的底部弹窗。
///
/// 用户可选择餐次、添加多项菜品（名称+热量+分类）、设置用餐时间。
class MealEntryDialog extends StatefulWidget {
  final MealType? initialType;

  const MealEntryDialog({super.key, this.initialType});

  /// 弹出并返回用户录入的完整结果，取消则返回 null。
  static Future<MealEntryResult?> show(
    BuildContext context, {
    MealType? initialType,
  }) {
    return showModalBottomSheet<MealEntryResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MealEntryDialog(initialType: initialType),
    );
  }

  @override
  State<MealEntryDialog> createState() => _MealEntryDialogState();
}

class _MealEntryDialogState extends State<MealEntryDialog> {
  late MealType _mealType;
  final List<_MealItemEntry> _items = [];
  DateTime _recordedAt = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialType ?? MealType.inferFromTime(DateTime.now());
    _items.add(_MealItemEntry());
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ---- handlers ----

  void _addItem() => setState(() => _items.add(_MealItemEntry()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (picked == null) return;
    setState(() {
      _recordedAt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;

    final items = <MealItem>[];
    for (final entry in _items) {
      final name = entry.nameController.text.trim();
      if (name.isEmpty) continue;
      items.add(MealItem(
        name: name,
        calories: int.tryParse(entry.caloriesController.text.trim()),
        category: entry.category,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个菜品')),
      );
      return;
    }

    Navigator.of(context).pop(MealEntryResult(
      mealType: _mealType,
      items: items,
      recordedAt: _recordedAt,
    ));
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHandle(),
                const SizedBox(height: 12),
                _buildHeader(theme),
                const SizedBox(height: 16),
                _buildMealTypeSelector(theme),
                const SizedBox(height: 20),
                _buildItemsSection(theme),
                const SizedBox(height: 16),
                _buildTimeRow(theme),
                const SizedBox(height: 20),
                _buildConfirmButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(_mealType.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '手动添加餐食',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMealTypeSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MealType.values.map((type) {
        final selected = _mealType == type;
        return ChoiceChip(
          label: Text('${type.emoji} ${type.label}'),
          selected: selected,
          onSelected: (_) => setState(() => _mealType = type),
          selectedColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '菜品列表',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...List.generate(_items.length, (i) => _buildItemRow(theme, i)),
      ],
    );
  }

  Widget _buildItemRow(ThemeData theme, int index) {
    final entry = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 名称
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: entry.nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '如: 米饭',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                // 至少有一个菜品有名称即可，在 _confirm 中做整体校验
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          // 热量
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: entry.caloriesController,
              decoration: const InputDecoration(
                labelText: '千卡',
                hintText: '200',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(width: 8),
          // 分类下拉
          SizedBox(
            width: 72,
            child: DropdownButtonFormField<String>(
              value: entry.category,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              isExpanded: true,
              items: _categoryOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => entry.category = v),
            ),
          ),
          // 删除按钮
          if (_items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    color: theme.colorScheme.error, size: 20),
                onPressed: () => _removeItem(index),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(ThemeData theme) {
    final timeStr =
        '${_recordedAt.hour.toString().padLeft(2, '0')}:${_recordedAt.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Icon(Icons.access_time, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text('用餐时间', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              timeStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildConfirmButton(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: _confirm,
        icon: const Icon(Icons.check, size: 20),
        label: const Text('确认添加', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static const _categoryOptions = [
    '主食', '蔬菜', '肉类', '海鲜', '豆制品',
    '汤品', '水果', '饮料', '零食', '其他',
  ];
}

/// 录入弹窗的返回结果。
class MealEntryResult {
  final MealType mealType;
  final List<MealItem> items;
  final DateTime recordedAt;

  const MealEntryResult({
    required this.mealType,
    required this.items,
    required this.recordedAt,
  });
}

/// 单个菜品输入行的控制器。
class _MealItemEntry {
  final nameController = TextEditingController();
  final caloriesController = TextEditingController();
  String? category;

  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
  }
}
