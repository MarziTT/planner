---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: fe7e0515290b04070c7aa137e3bf58e6_feed77b1896911f18108525400287e28
    ReservedCode1: bysfuDXAKHA9UI/3PalbU0+SD++FMtOH8Tx/mZntz8Keacw1EoYsqQ5IEjNh+BE5/jVGybkQ7P91Hwc8ik2xB8bzgQtbMWd6uSEH1hxXmKdvhKLmReA43EQbvRHKES04uHLJVA1WWamdqJkQsYvwY+h9wP0zrVO+jlIgKZTrMbDJveQLf0Fed2grWRw=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: fe7e0515290b04070c7aa137e3bf58e6_feed77b1896911f18108525400287e28
    ReservedCode2: bysfuDXAKHA9UI/3PalbU0+SD++FMtOH8Tx/mZntz8Keacw1EoYsqQ5IEjNh+BE5/jVGybkQ7P91Hwc8ik2xB8bzgQtbMWd6uSEH1hxXmKdvhKLmReA43EQbvRHKES04uHLJVA1WWamdqJkQsYvwY+h9wP0zrVO+jlIgKZTrMbDJveQLf0Fed2grWRw=
---

# PixelPlanner 天气智能管家 · 设计文档

> 日期：2026-07-27 | 状态：设计稿 | 优先级：P1

## 概述

天气模块全面重构，从"显示天气数据"升级为"全天规划辅助管家"。核心定位：PixelPlanner 是用户的私人生活管家，天气功能以自然语言建议的形式，结合日程事件，在恰到好处的时机推送给用户。

## 架构

```
用户 → 桌面小组件 + 智能通知 → Flutter WeatherProvider (Riverpod) → Flask /api/v1/weather/smart-advisory → 数据聚合层 (Open-Meteo + OpenAQ) → LLM 合成 (gpt-4o-mini) → 用户
```

## 数据源

- **天气**：Open-Meteo (免费免密钥) — 温度、体感温、降水概率、天气现象、风力、湿度、紫外线、能见度
- **空气质量**：OpenAQ — PM2.5、PM10、O₃、NO₂
- **fallback**：任意源超时/失败时使用上次缓存数据，标记 stale

## API 设计

```
GET /api/v1/weather/smart-advisory?lat=xx&lon=xx&date=YYYY-MM-DD
```

返回 JSON：
- `timeline[]`：每个时段包含 time_slot / event / weather(全量) / advisory
- `summary`：一句当日总结
- `generated_at`：生成时间戳

## 前端实现

### 小组件 (桌面)
- 3-4 个关键时段时间线卡片
- 高优先级事件(运动/户外)自动高亮
- 极端天气红色预警标记（体感>38°C / 降水>50%）
- 点击跳转 App 对应日程详情
- 每 30 分钟静默刷新

### 智能通知
1. 早上 7:00 — 当日摘要推送，一句总结
2. 事件前 30 分钟 — 结合天气的行动建议
3. 天气突变 — 非预期降水/气温骤降，实时推送

## LLM 合成规范

### 管家语气规则
- 称用户为"你"
- 建议而非播报："建议你…"、"我帮你看了下…"
- 关心语气："今天下午有点热，你的骑行要不要推迟？"
- 禁止气象台腔："预计降水概率70%"

### Prompt 模板 (PIXELPLANNER_WEATHER_PROMPT)
```
你是 PixelPlanner，用户的私人生活管家。
用户日程：{events}
当前天气数据：{weather_data}
请对每个日程时段给出简短的一条行动建议（不超过 20 字），格式：
[时段] [事件] [建议]
最后加一句当日总结。
要求：用中文，用"你"称呼用户，建议代替播报，关心语气。
```

## 后端文件改动

```
backend/app/api/weather.py — 新增端点
backend/app/services/weather_service.py — 重写，多源聚合 + LLM 合成
backend/app/services/open_meteo.py — 新增客户端
backend/app/services/open_aq.py — 新增客户端
```

各客户端 30s 超时 + 1 次重试。缓存 30 分钟。

## 安全修复

- 删除旧的 `weather.py:72-105` debug 端点
- 密钥通过环境变量注入，不硬编码

## 开发者指南

1. 先跑通 Open-Meteo 客户端，确认数据格式
2. 再跑通 OpenAQ
3. 写数据聚合层
4. 写 LLM prompt 模板并测试
5. 前端小组件开发与后端同步
6. 通知逻辑对接已有通知模块
*（内容由AI生成，仅供参考）*
