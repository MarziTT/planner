# Jarvis Agent Phase 2：全方位生活管家 — 设计规格

> 状态：Draft  
> 日期：2026-07-23  
> 依赖：Phase 1（语音对话日程管理）

---

## 1. 概述

### 1.1 Phase 2 目标

从"对它说话它安排好"（Phase 1）扩展到"到点提醒 + 全方位生活管家"。管家不依赖用户主动记录，通过**被动感知 + 最低成本交互**覆盖六大领域。

### 1.2 六大领域

| 领域 | 数据来源 | 用户动作 |
|------|----------|----------|
| 天气 | 和风 API | 无 |
| 日程 | 语音/打字录入 | 说一句 / 打一行字 |
| 作息 | 步数传感器 + 屏幕/电量信号 | 无 |
| 饮食 | 拍照识别 / 到点弹窗点一下 | 拍照 / 点一下 ✓ |
| 运动 | 步数 + 活动识别 + 手动切换模式 | 说一次切换模式 |
| 出行 | 语音 + 截图 OCR + Deep link | 说一句 / 发截图 |

### 1.3 不入 Phase 2 的范围

- 智能叫车下单（仅 deep link 跳转）
- 打车实时跟踪 / 高铁晚点 / 共享单车自动检测
- 外卖点单 / 餐厅预订
- 社交提醒（"该给妈妈打电话了"）
- iOS 小组件

---

## 2. 整体架构

```
┌──────────────────────────────────────────────────┐
│                   后端 (Railway)                   │
│                                                   │
│  /api/v1/agent/parse       Phase 1 语音+文字解析   │
│  /api/v1/agent/schedule    Phase 1 日程管理        │
│  /api/v1/habits/*          Phase 2 习惯引擎        │
│  /api/v1/notify/*          Phase 2 提醒策略         │
│  /api/v1/transit/*         Phase 2 出行            │
│                                                   │
│  habits_engine.py          用户行为分析 + 策略生成   │
│  notify_plan.py            动态提醒时间计算         │
│  transit_planner.py        地铁路线 + 出行方案      │
│  ocr_service.py            本地 OCR（不传中转站）    │
│                                                   │
│  数据表 (PostgreSQL):                              │
│    schedule_events         Phase 1 已有             │
│    event_history           新增 事件实际时间戳       │
│    user_patterns           新增 学习到的习惯         │
│    notify_preferences      新增 提醒偏好             │
│    ocr_cache               新增 OCR 结果缓存         │
│    meal_records            新增 饮食记录             │
│    exercise_records        新增 运动记录             │
└──────────────────────────────────────────────────┘
                         ↕ REST API
┌──────────────────────────────────────────────────┐
│               Flutter App (Android)               │
│                                                   │
│  lib/features/agent/       Phase 1 语音交互        │
│  lib/features/widgets/     Phase 2 小组件桥接       │
│  lib/features/habits/      Phase 2 习惯展示         │
│  lib/features/transit/     Phase 2 出行 UI          │
│  lib/features/meals/       Phase 2 饮食拍照          │
│                                                   │
│  原生 Android 层:                                  │
│    JarvisWidgetProvider.kt   AppWidgetProvider     │
│    widget_refresh_worker.kt  WorkManager 定时刷新   │
│    StepCounterService.kt     步数读取               │
│    ActivityRecognition.kt    活动识别               │
│    SleepDetector.kt          作息检测               │
└──────────────────────────────────────────────────┘
```

### 2.1 隐私防护（中转站保护）

- OCR 在本地完成后端处理，仅传文字到中转站 API
- 不传原始截图到任何第三方服务
- `ocr_cache` 表只存图片哈希（SHA-256），不存原图

### 2.2 鸿蒙适配路径

- 后端 API 完全不变（REST 接口通用）
- Flutter 业务层代码不变
- 仅替换原生 Android 壳为 HarmonyOS `FormComponent`（小组件）+ 传感器 API
- 鸿蒙当前 Flutter 生态不成熟，Phase 2 预留接口但 Android 先行

---

## 3. 小组件设计

### 3.1 三段式布局

`3×2` 通用尺寸，按时间段自适应内容。

```
┌──────────────────────────────────┐
│  🌤 12° · 多云 · 深圳              │  ← 天气条
│                                   │
│  「今天周三，工作日」                │  ← 模式条
│  ──────────────────────────────── │
│                                   │
│  ⏳ 13:30 · 约了牙医               │  ← 提醒条（1-2条）
│  ⏳ 30 分钟后 · 起来走走             │
│                                   │
└──────────────────────────────────┘
```

### 3.2 时间自适应

| 时段 | 天气条 | 模式条 | 提醒条 |
|------|--------|--------|--------|
| 06:00-08:00 | 温度+天气+"记得带伞"（如降雨） | 「早安，今天周三」 | 今天第一件事+预计结束 |
| 08:00-10:00 | 温度+天气 | 「工作日」/「休息日」 | 当前/下一件事 |
| 10:00-18:00 | 温度+天气 | 同上 | 当前+下一条+管家建议 |
| 18:00-22:00 | 夜间温度 | 「一天快结束了」 | 未完成+"还有N件事没做" |
| 22:00-06:00 | 明天天气 | 「晚安」 | "明天8:00闹钟·预计7h睡眠" |

### 3.3 模式自动判断

| 模式 | 触发条件 | 行为 |
|------|----------|------|
| 🌞 工作日 | 周一~周五（除非日历标"休息"） | 到点提醒：站起来、喝水、午餐 |
| 🌿 休息日 | 周末/节假日/日历标"休息" | 天气好→建议出门；下雨→建议在家 |
| 🏃 出行日 | 当天有地点类行程 | 提前提醒出发+小组件显示倒计时 |
| 🎯 密集日 | 今天日程≥4条 | 顶部「今天很满，撑住」，提醒精简 |

### 3.4 配色

- 浅色背景：`#F5F0EB`（暖米白）
- 深色背景：`#1A1A1A`（暖黑）
- 倒计时/强调色：`#D4A574`（暖铜色，"管家的温度"）
- 字体：系统默认 `sans-serif-medium`

### 3.5 更新策略

- WorkManager `PeriodicWorkRequest` 每 15 分钟从后端拉日程
- `onUpdate` 时触发刷新（小组件被系统渲染时）
- 离线时显示 SharedPreferences 最后缓存

---

## 4. 锁屏通知

### 4.1 三级通知

| 等级 | 类型 | 锁屏行为 | 示例 |
|------|------|----------|------|
| 🔴 紧急 | 行程/出行 | 弹窗+顶部常驻+5分钟未读再弹 | "牙医预约还有30分钟，该出门了" |
| 🟡 重要 | 作息/饮食 | 弹窗+通知栏静默 | "12:00了，该吃午饭了" |
| 🟢 日常 | 天气/建议/总结 | 仅通知栏，不弹窗 | "明天有雨，记得带伞" |

### 4.2 通知快捷操作

所有通知两个按钮：

| 按钮 | 行为 |
|------|------|
| ✅ 完成 | 标记完成，习惯引擎记录时间 |
| ⏰ 15分钟后 | 推迟，习惯引擎记录"第N次推迟" |

### 4.3 逾期处理

- 🟡 饮食：15 分钟未处理 → 再弹 → 30 分钟后最后弹 "还没吃？帮你记下了"
- 🔴 行程：5 分钟未处理 → 再弹 → "真的要迟到了"

### 4.4 静默时段

22:00 ~ 06:00：🟢 级静默，🟡/🔴 仍弹出

---

## 5. 数据模型

### 5.1 新增表

```sql
-- 事件历史（习惯引擎原料）
CREATE TABLE event_history (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES schedule_events(id),
    user_id INT NOT NULL,
    planned_time TIMESTAMP NOT NULL,
    reminded_at TIMESTAMP,
    completed_at TIMESTAMP,
    delayed_count INT DEFAULT 0,
    skipped BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 用户习惯
CREATE TABLE user_patterns (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    pattern_type VARCHAR(50),        -- 'wake_time', 'meal_time', 'transit_mode'
    pattern_key VARCHAR(100),
    pattern_value JSONB,
    confidence FLOAT,
    sample_count INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 提醒偏好（动态可被习惯引擎覆盖）
CREATE TABLE notify_preferences (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    notify_type VARCHAR(50),
    lead_minutes INT,
    enabled BOOLEAN DEFAULT TRUE,
    quiet_hours_start TIME,
    quiet_hours_end TIME
);

-- OCR 缓存（不存原图）
CREATE TABLE ocr_cache (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    image_hash VARCHAR(64),          -- SHA-256
    raw_text TEXT,
    parsed JSONB,
    processed_at TIMESTAMP DEFAULT NOW()
);

-- 饮食记录
CREATE TABLE meal_records (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    meal_type VARCHAR(20),           -- 'breakfast', 'lunch', 'dinner', 'snack'
    items JSONB,                     -- [{"name": "牛肉面", "portion": "large"}]
    recorded_at TIMESTAMP DEFAULT NOW(),
    source VARCHAR(20) DEFAULT 'photo'  -- 'photo' / 'tap' / 'voice'
);

-- 运动记录
CREATE TABLE exercise_records (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    exercise_type VARCHAR(50),
    duration_minutes INT,
    recorded_at TIMESTAMP DEFAULT NOW(),
    source VARCHAR(20) DEFAULT 'auto'   -- 'auto' / 'manual'
);
```

### 5.2 用户配置扩展（已有表新增字段）

```sql
ALTER TABLE users ADD COLUMN exercise_mode VARCHAR(20) DEFAULT 'self';
-- 'self' = 自主运动, 'trainer' = 私教练模式
ALTER TABLE users ADD COLUMN trainer_end_date DATE;
-- 私教结束日期，到期自动切换 exercise_mode 为 'self'
```

---

## 6. API 端点

| Method | Path | 用途 | Phase |
|---|---|---|---|
| GET | `/api/v1/habits/summary` | 管家学到的用户习惯摘要 | 2 |
| POST | `/api/v1/habits/skip/{event_id}` | 用户跳过某提醒，习惯引擎学习 | 2 |
| PUT | `/api/v1/notify/preferences` | 调整提醒偏好 | 2 |
| POST | `/api/v1/transit/parse-ticket` | 高铁票 OCR → 结构化 | 2 |
| POST | `/api/v1/transit/route` | 地铁路线查询 | 2 |
| POST | `/api/v1/agent/parse-transit` | 语音/文字录入出行意图 | 2 |
| POST | `/api/v1/meals/parse-photo` | 饮食拍照识别 | 2 |
| POST | `/api/v1/meals/log` | 手动记录用餐（拍照/点确认） | 2 |
| GET | `/api/v1/exercise/summary` | 运动周报/月报 | 2 |
| PUT | `/api/v1/user/exercise-mode` | 切换运动模式（自主/私教） | 2 |

---

## 7. 习惯引擎

### 7.1 核心逻辑

滑动窗口统计（近 30 天），非 ML 模型：

```python
class HabitsEngine:
    def adjust_lead_minutes(self, notify_type: str, user_id: int) -> int | None:
        history = get_history(user_id, notify_type, days=30)
        
        if notify_type == 'transit':
            avg = avg_min(history, lambda h: h.planned_time - h.reminded_at)
            return int(avg)
        
        if notify_type == 'standing':
            if count_recent(history, days=5, skipped=True) >= 5:
                return None  # 取消该时段站立提醒
            return 0
        
        if notify_type == 'meal':
            actual_times = extract(history, lambda h: h.completed_at.time())
            return compute_typical_lead(actual_times)
```

### 7.2 学习项清单

| 学习项 | 数据源 | 产出 |
|--------|--------|------|
| 起床时间 | 步数传感器首次活动 | 工作日/休息日平均起床时间 |
| 午/晚餐时间 | 饮食记录 `completed_at` | 各餐典型时间 |
| 迟到行为 | `completed_at - planned_time` | 某类事件平均迟到分钟数 |
| 站立提醒接受度 | `skipped` 频率 | 是否取消某时段提醒 |
| 出行方式 | `transit` 历史 | 去某地首选地铁还是打车 |
| 运动低谷日 | 步数 + 运动记录 | 周三通常不动 → 不推提醒 |

---

## 8. 饮食模块

### 8.1 被动录入策略

1. **到点弹窗**：12:00 弹「午饭时间」→ [✓已吃] [跳过]。点已吃记时间戳，跳过则 15 分钟后重问。
2. **拍照识别**：拍照 → 本地 OCR → 视觉 LLM 识别食物 → 记入 `meal_records`。不存原图。
3. **语音录入**（可选）："中午吃了碗牛肉面" → 解析记入。
4. **连续不理**：到点弹 3 次都不点 → 记"今天没吃午饭"。

### 8.2 输出

- 不输出营养分析（无强制目标）
- 周报："这周午餐有 2 天没吃，注意规律饮食"

---

## 9. 运动模块

### 9.1 双模式

| 模式 | 触发 | 行为 |
|------|------|------|
| 🏋️ 私教 | 用户说"我在私教，还有X天" | 静默读步数，不推任何运动提醒 |
| 🏃 自主 | 私教到期/用户说"自己练" | 推运动建议，追踪步数+活动 |

切换指令：
- 「我找了个私教，大概练 3 个月」→ `exercise_mode='trainer'`, `trainer_end_date=今天+90天`
- 「私教到期了，自己练」→ `exercise_mode='self'`
- 到期自动切换，切换到自主期时通知：「私教期结束了，以后我帮你盯着运动」

### 9.2 自主期数据源

| 传感器 | 拿到的数据 |
|--------|-----------|
| Step Counter | 每日步数 |
| Activity Recognition | 走路/跑步/骑车/静止 |
| Google Fit / Health Connect | 汇总运动时长（如用户授权） |

### 9.3 提醒策略

- 步数 < 2000 + 非训练日 → "今天没怎么动，要不要出去散个步？"
- 连续 3 天不动 → "你已经 3 天没运动了，今天练一下？"
- 星期三（历史低谷日）→ 不推运动提醒

---

## 10. 出行模块

### 10.1 高铁票 OCR

```
截图 → 本地 OCR（不传中转站）
    → 提取：车次、日期、发车时间、出发站、到达站、车厢号、座位号
    → 创建出行日程
    → 查当前位置 → 预估地铁/打车时间
    → 推提前提醒
```

### 10.2 出行时间线

```
前一天 21:00  「明天早上8:15高铁去长沙，建议23:00前睡」
当天 06:30    「早安。高铁8:15，7:30前出门来得及」
当天 07:00    「该准备出门了。地铁45分钟，打车30分钟。你选哪个？」
              快捷选项：🚇地铁 / 🚗打车
  ├─ 🚇 → 地铁路线+换乘提醒
  └─ 🚗 → deep link 拉起滴滴/高德预填"深圳北站"
当天 07:45    「还有30分钟发车，时间充足」
当天 08:00    「G1234 开始检票，08车12A，A12检票口」
当天 08:15    自动标记完成
当天 10:30    「快到长沙了。长沙32°晴。」
```

### 10.3 地铁换乘提醒

- 用户说"坐地铁去车公庙"
- 后端查路线 → 返回换乘站列表
- 按站间距估算时间 → 到换乘站前推提醒
- "会展中心还有2站，准备换4号线"
- 不依赖 GPS（地铁下定位漂移），靠时间估算

### 10.4 Deep link 跳转

| 场景 | Scheme | 备注 |
|------|--------|------|
| 打车（滴滴） | `diditaxi://` | 预填目的地 |
| 打车（高德） | `amapuri://` | 预填目的地 |
| 共享单车 | 美团/哈啰 scheme | 打开扫码页 |

---

## 11. 天气模块

- 和风 API（免费版），根据用户位置查询
- 每天早上 6:30 推天气通知
- 小组件天气条实时展示当前温度 + 天气
- 降雨/高温等极端天气自动追加提醒

---

## 12. 作息模块

### 12.1 起床检测

- 步数传感器首次检测到步数（早晨 4:00-10:00）
- 结合屏幕首次亮起时间
- 自动记入 `event_history`（`event_type='wake_up'`）

### 12.2 久坐提醒

- 默认 10:00 / 14:00 / 16:00 各一次
- 活动识别检测到连续坐 ≥ 1 小时 → 推提醒
- 连续 5 次跳过某时段 → 习惯引擎取消该时段

### 12.3 睡眠时间推算

- 夜间屏幕最后关闭时间 → 睡眠开始
- 早晨首次步数/屏幕亮起 → 醒来
- 小组件底部显示 "预计 7 小时睡眠"

---

## 13. 打字输入

Phase 1 语音面板底部加文字输入栏：

```
┌──────────────────────────────────┐
│  🎤 按住说话                      │
│  ────────────────────────────────│
│  📝 明天下午三点去办护照            │  ← 打字输入
│                              ➤   │
└──────────────────────────────────┘
```

同 `/api/v1/agent/parse`，`source: "text"` 标记。

---

## 14. Habits Dashboard

Planner 页面新增标签页，三块面板：

1. **今日摘要**："早上 6:53 起床 · 睡了 7h12m · 今天 3 件事"
2. **我学到了什么**："工作日平均起床 7:00 · 午饭 12:30 · 周三最易不吃午饭"
3. **周报**：步数趋势线、运动天数、饮食记录天数

---

## 15. 实现顺序（Phase 2 内部优先级）

| 顺序 | 模块 | 理由 |
|------|------|------|
| 1 | 后端数据表 + 习惯引擎框架 | 所有模块的基础 |
| 2 | 小组件（Android 原生） | 核心体验，"每天第一句话" |
| 3 | 锁屏通知增强 | 到点提醒升级 |
| 4 | 出行（高铁 OCR + 地铁 + deep link） | 高频高价值 |
| 5 | 饮食（拍照 + 到点弹窗） | 中频 |
| 6 | 运动（传感器 + 双模式） | 传感器接入复杂 |
| 7 | 天气 + 作息 | 低实现成本 |
| 8 | Habits Dashboard + 打字输入 | 信息展示 + 交互补全 |

---

## 16. 规格自审

- [x] 无 TBD / TODO
- [x] 架构与功能描述一致
- [x] 范围明确（Phase 2 内外清晰界限）
- [x] 无歧义（所有交互行为有明确定义）
- [x] 隐私防护方案明确（OCR 本地处理、不传原始截图）
- [x] 鸿蒙适配路径清晰
