# P3-F3: 智能推送通知 — 开发总结

> 日期: 2026-07-24 | 开发者: Senior Developer
> 测试: 7/7 新增 + 166/166 全量零回归

---

## 一、设计决策

PixelPlanner 已有完善的 Flutter 本地通知基础设施（6 通道 / 3 级优先级 / 快捷操作 / 乔布斯规则），但没有智能化的推送内容。F3 的核心价值在于：**基于习惯引擎的检测结果，自动生成上下文感知的推送文案**。

架构：后端生成 insights → Flutter 轮询 → 本地调度。

---

## 二、新增文件

### 后端

| 文件 | 行数 | 说明 |
|------|------|------|
| `backend/app/services/smart_notify_service.py` | 370 | 智能通知内容引擎 — 5 种检测器 |
| `backend/app/api/notifications.py` | 74 | `GET /notify/insights` + `GET /notify/history` |
| `backend/tests/test_notify_api.py` | 136 | 7 个测试用例 |

### Flutter

| 文件 | 行数 | 说明 |
|------|------|------|
| `lib/features/notifications/domain/smart_notify_models.dart` | 157 | Insight / HistoryEntry / Results 模型 |
| `lib/features/notifications/data/smart_notify_repository.dart` | 52 | API Repository + Riverpod Provider |
| `lib/features/notifications/state/smart_notify_provider.dart` | 74 | SmartNotifyNotifier 状态管理 |
| `lib/features/notifications/presentation/notify_insights_page.dart` | 318 | 双 Tab 仪表板页面 |

### 修改

| 文件 | 改动 |
|------|------|
| `backend/app/__init__.py` | +2 行 — 注册 `notify_bp` 蓝图 |

---

## 三、后端引擎 — 5 种智能检测器

### 1. wake_deviation (起床偏差)
- **数据源**: UserPattern(wake_time) + 当日最早 ExerciseRecord
- **触发条件**: 实际起床时间与习惯偏差 ≥ 30 分钟
- **文案示例**: "今天起床晚了哦 ☀️ — 比平时晚了约 45 分钟，要不要调整下日程？"

### 2. standing_nudge (站立督促)
- **数据源**: UserPattern(standing_acceptance) + EventHistory 连续跳过统计
- **触发条件**: 连续 3 次跳过站立提醒
- **文案示例**: "该站起来动动了 🪑➡️🏃 — 已经连续 3 次跳过站立提醒了哦"

### 3. exercise_drop (运动下降)
- **数据源**: ExerciseRecord 本周 vs 上周 duration_minutes 对比
- **触发条件**: 下降 ≥ 30%
- **文案示例**: "运动量有点下降 📉 — 这周运动比上周少了约 40%，今天要不要跑个步？"

### 4. meal_sync (用餐规律)
- **数据源**: UserPattern(meal_time) — 早/午/晚餐
- **触发条件**: confidence ≥ 0.4 且未开启提醒
- **文案示例**: "🍱 午餐时间到了 — 你一般在 12:15 左右吃午餐，要开启用餐提醒吗？"

### 5. sleep_reminder (睡眠提醒)
- **数据源**: UserPattern(wake_time) 推算最佳入睡时间
- **触发条件**: 20:00-23:00 时段 + confidence ≥ 0.4
- **文案示例**: "🌙 该准备睡觉了 — 你一般在 07:30 起床，建议 23:00 前入睡"

---

## 四、API 端点

### `GET /api/v1/notify/insights`
- **认证**: Bearer JWT 必需
- **响应**: `{ ok, data: { user_id, generated_at, count, insights: [...] } }`
- **排序**: 按 priority (high → medium → low)

### `GET /api/v1/notify/history`
- **认证**: Bearer JWT 必需
- **参数**: `notify_type` (可选筛选), `days` (默认 7, 最大 30), `limit` (默认 50, 最大 200)
- **响应**: `{ ok, data: { user_id, total, skipped, completed, entries: [...] } }`

---

## 五、Flutter UI — 双 Tab 仪表板

```
┌─────────────────────────────────────┐
│  🔔 智能通知                         │
│  [智能建议]  [通知历史]               │
├─────────────────────────────────────┤
│  Tab 1: 智能建议                     │
│  ┌─────────────────────────────┐    │
│  │ ☀️ 今天起床晚了哦    [提醒]   │    │
│  │ 比平时晚了约45分钟...        │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 📉 运动量有点下降    [提醒]   │    │
│  │ 这周运动比上周少了40%...    │    │
│  └─────────────────────────────┘    │
│                                      │
│  Tab 2: 通知历史                     │
│  总计 23  已完成 15  已跳过 8        │
│  🧍 站立    07-24 14:30   已跳过    │
│  🍽️ 饮食    07-24 12:00   已完成    │
│  🚗 出行    07-24 08:45   已完成    │
└─────────────────────────────────────┘
```

特性:
- 按优先级颜色编码 (高=深橙 / 中=琥珀 / 低=主色)
- 每条 insight 带 icon + 类型标签
- 历史支持统计概览芯片 + 状态标签 (已完成/已跳过/待处理)
- 下拉刷新 + 错误重试

---

## 六、P3 进度

| # | 功能 | 状�� | 后端测试 | Flutter |
|---|------|------|----------|---------|
| F1 | AI 日程智能排程 | ✅ | 14/14 | ✅ |
| F2 | 健康数据中心 | ✅ | 9/9 | ✅ |
| F3 | 智能推送通知 | ✅ | 7/7 | ✅ |
| F4 | 语音全流程交互 | ⬜ | — | — |
