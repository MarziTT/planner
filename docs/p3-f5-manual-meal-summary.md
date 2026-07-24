# P3-F5: 手动添加餐食 — 开发总结

> 日期: 2026-07-24 | 开发者: Senior Developer

---

## 改动范围

| 层 | 文件 | 操作 | 行数 |
|---|------|------|------|
| Flutter | `meals/views/meal_entry_dialog.dart` | 新建 | 337 |
| Flutter | `meals/views/meal_page.dart` | 修改 | +20 / -7 |

---

## 核心交付

### meal_entry_dialog.dart — 完整录入弹窗

```
┌──────────────────────────────────────┐
│  🍳  手动添加餐食              [✕]  │
├──────────────────────────────────────┤
│  [🍳 早餐] [🍱 午餐] [🍲 晚餐] [🍎 加餐] │ ChoiceChip 餐次选择
├──────────────────────────────────────┤
│  菜品列表                      [+ 添加]│
│  ┌──────────────────────────────┐    │
│  │ ① [名称: 米饭] [千卡: 200] [主食 ▼] │ │ MealItem 行
│  │ ② [名称: 鸡蛋] [千卡: 150] [肉类 ▼] │ │ × N
│  └──────────────────────────────┘    │
│  ⏰ 用餐时间 [12:30]                  │ TimePicker
├──────────────────────────────────────┤
│         [✓ 确认添加]                  │ FilledButton
└──────────────────────────────────────┘
```

**功能特性**:
- 4 餐次 ChoiceChip 快速切换（默认根据当前时间推断）
- 动态菜品列表：名称 + 热量 + 分类下拉（10 种分类）
- 支持多项菜品（至少 1 项）、支持删除
- 用餐时间选择器
- 键盘弹出时自动上移（`viewInsets.bottom`）
- 拖拽手柄 + 关闭按钮

### meal_page.dart — 接入

原 `IconButton onPressed` 从 TODO SnackBar 占位：
```dart
onPressed: () {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('手动添加功能即将推出')),
  );
}
```

改为：
```dart
onPressed: () => _onManualAdd(type),
```

`_onManualAdd` 方法：show dialog → 调 `MealOcrService.addManual()` → 成功 SnackBar + `_refresh()` → 失败红色 SnackBar。

---

## 数据流

```
用户点击 + 按钮
  → MealEntryDialog.show(context, initialType: type)
    → 录入餐次 + 菜品列表 + 时间
    → 弹出 MealEntryResult{mealType, items, recordedAt}
  → MealOcrService.addManual(mealType, items, recordedAt)
    → POST /api/v1/meals/manual
    → 返回 MealRecord?
  → _refresh()  → GET /meals/summary → 更新 UI
```

---

## 质量验证

- Flutter analyze: **零 error**（全量 85 均为预存量）
- 后端 meals 测试: 18/18 零回归
