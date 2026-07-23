---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: fe7e0515290b04070c7aa137e3bf58e6_c72c48fb865e11f18766525400f8a581
    ReservedCode1: eh9egjFlWHz7nTZv8NNYgnukXbD99UDrxYT2UJMtYVcgCu5kr1Xax90no85KfxOmWeDwYm89GVAE/QHAdHcDgAyS3NNqkRLqHqQQ6mv2NO5Cf23U7qJ6K89wpkO1rbSC8LpCEaUo6l5YpqLTJODe4qQG9gsIuUFh8OUyksK2maqH8MJ8R4ZyZh42CxA=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: fe7e0515290b04070c7aa137e3bf58e6_c72c48fb865e11f18766525400f8a581
    ReservedCode2: eh9egjFlWHz7nTZv8NNYgnukXbD99UDrxYT2UJMtYVcgCu5kr1Xax90no85KfxOmWeDwYm89GVAE/QHAdHcDgAyS3NNqkRLqHqQQ6mv2NO5Cf23U7qJ6K89wpkO1rbSC8LpCEaUo6l5YpqLTJODe4qQG9gsIuUFh8OUyksK2maqH8MJ8R4ZyZh42CxA=
---



# Phase 1: 贾维斯式日程管家 — 规格文档

> 版本：v1.0 | 日期：2026-07-23 | 状态：Draft

## 一句话定义

**对你的手机说一句话，日程就安排好了。**

## 设计原则

1. **对话即界面**：用户用自然语言描述意图，系统以对话气泡确认结果
2. **渐进式确认**：有歧义时间才问，用户指定具体时间则直接排程
3. **零摩擦入口**：首页底部常驻麦克风按钮，一行代码即可唤醒对话

---

## 核心交互流

```
用户说 "后天下午跟老张喝咖啡"
        ↓
    语音转文字（已有 ASR）
        ↓
    LLM 语义解析 → { intent: "create_event", datetime, person, event_name }
        ↓
    时间模糊？→ 是 → 对话确认 "后天下午是指 14:00-17:00 吗？"
                → 否（用户已给具体时间）→ 跳过确认
        ↓
    后端冲突检测 → GET /api/v1/events?start=...&end=...
        ↓
    有冲突？→ 是 → 提示冲突，建议下一空闲时段
              → 否 → 对话气泡展示确认卡片
        ↓
    用户确认 → POST /api/v1/events → 创建日程 + 提醒
        ↓
    卡片收拢为日程条目，落位到当前日历面板
```

## 对话确认规则

| 场景 | 行为 |
|------|------|
| 时间模糊（"下午"、"晚上"、"周末"） | 反问精确时间范围 |
| 时间明确（"明天15:00"） | 直接排程，只展示确认卡片 |
| 有冲突 | 提示冲突 + 建议空闲时段 |
| 无冲突 | 展示确认卡片，用户点头即存 |
| 解析失败 | "没太理解，能再说一遍吗？" |

---

## 技术架构

### 模块拆分

| 模块 | 类型 | 位置 | 职责 |
|------|------|------|------|
| `agent_voice` | 复用 | `voice/` | 语音输入 + 腾讯云 ASR 转文字 |
| `agent_parser` | **新增** | `backend/app/services/agent.py` | LLM 语义解析 → 结构化日程 |
| `agent_conflict` | 复用 | `planner/` GET /events | 时段冲突检测 |
| `agent_dialog` | **新增** | `lib/features/agent/presentation/` | 对话气泡 UI + 确认卡片 |
| `agent_schedule` | 复用 | `planner/` POST /events | 日程写入 + 提醒设置 |

### 新增后端端点

```
POST /api/v1/agent/parse
  入参: { "text": "后天下午跟老张喝咖啡" }
  出参: {
    "intent": "create_event",
    "event_name": "跟老张喝咖啡",
    "person": "老张",
    "datetime_range": { "start": "2026-07-25T14:00:00", "end": "2026-07-25T17:00:00" },
    "confidence": 0.92
  }

POST /api/v1/agent/schedule
  入参: { "event_name": "...", "start": "...", "end": "...", "reminder_minutes": 30 }
  出参: { "event_id": 123, "status": "created" }
```

### LLM 接入策略

- **优先方案**：接入 OpenAI 兼容 API（可切换 DeepSeek / 阿里通义 / 本地模型）
- **Prompt 设计**：Few-shot 格式，输出固定 JSON schema
- **降级方案**：LLM 不可用时，退化为关键词匹配（正则提取"明天"/"15:00"等模式）

### 数据流

```
Frontend (Flutter)                    Backend (Flask)
─────────────────                    ────────────────
MicButton (按下)
  → voice_service.startListening()
  → ASR 返回 text
  → POST /api/v1/agent/parse          → agent.parse(text) → LLM
                                      ← { intent, event_name, datetime_range, confidence }
  → DialogPanel.showConfirmCard()
  → 用户点击确认
  → POST /api/v1/agent/schedule       → planner.create_event(data)
                                      ← { event_id, status }
  → 刷新日历面板 + Toast "已安排"
```

---

## UI 规格

### 首页变更

- 现有底部导航栏不变
- Planner 页面右下角新增浮动操作按钮（FAB）：圆形麦克风图标
- 点击后页面从底部滑入对话面板（占屏幕 60%）

### 对话面板布局

```
┌──────────────────────────────┐
│  ← 收起                       │  顶部栏
├──────────────────────────────┤
│                              │
│  💬 "后天下午跟老张喝咖啡"       │  用户消息（右对齐）
│                              │
│  🤖 解析中...                  │  系统消息（左对齐，loading）
│                              │
│  ┌────────────────────────┐  │
│  │ 📅 跟老张喝咖啡          │  │
│  │ 🕐 7月25日 周六 15:00    │  │  确认卡片
│  │ 👤 老张                 │  │
│  │ [  确认安排  ]          │  │
│  └────────────────────────┘  │
│                              │
├──────────────────────────────┤
│  [🎤 按住说话]  [⌨️ 打字]    │  输入区
└──────────────────────────────┘
```

- 对话面板背景：沿用当前主题色
- 确认卡片：圆角 12px，半透明背景，左对齐
- 输入区：底部固定，Flex 布局，键盘弹出时自动上移
- 动画：面板从底部 slide up (300ms, ease-out)

### 对话气泡样式

| 类型 | 对齐 | 背景 |
|------|------|------|
| 用户消息 | 右对齐 | 主题主色 |
| 系统消息 | 左对齐 | 卡片背景 |
| 确认卡片 | 左对齐 | 卡片背景 + 边框 |
| 错误消息 | 左对齐 | 错误色浅底 |

---

## 错误处理

| 场景 | 处理 |
|------|------|
| ASR 超时（10s 无声音） | 提示"没有听到声音，再试一次？" |
| ASR 识别失败 | 提示"没听清，可以打字输入" |
| LLM 解析失败（confidence < 0.5） | 展示原始文字 + "没太理解，请补充时间信息" |
| 冲突检测网络超时 | 本地简单排重（当日已有日程列表），降级创建 |
| 日程创建失败 | Toast "创建失败，请重试"，保留输入文字 |
| LLM 服务不可用 | 降级为关键词匹配模式 + 提示"智能解析暂不可用" |

---

## 验收标准

- [ ] 首页 Planner 页可见麦克风 FAB
- [ ] 点击麦克风 → 对话面板滑入 → 开始录音
- [ ] 说出日程 → ASR 转文字显示 → 卡片确认
- [ ] 确认后日程出现在日历中
- [ ] 时间模糊时正确追问
- [ ] 有冲突时正确提示
- [ ] 打字输入方式可用
- [ ] dart analyze 零新增 error
- [ ] 后端所有新端点返回正确 JSON

---

## 不做的事（Phase 1 边界）

- 不做小组件 / 锁屏通知（Phase 2）
- 不做首页全面重构为对话界面（Phase 3）
- 不做多轮复杂对话（一轮对话 + 一卡确认足够）
- 不做语音合成播报（仅文字对话）
- 不做人物关系图谱 / 地点推荐
- 不支持修改/删除已有日程（仅创建）
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
