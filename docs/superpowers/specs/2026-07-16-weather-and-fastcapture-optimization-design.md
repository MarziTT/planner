# FlowDay 天气功能 & 速记优化 设计文档

日期：2026-07-16
状态：已批准

---

## 一、天气功能

### 1.1 数据源
- 和风天气 API（免费版，每日 1000 次调用）
- 城市级天气 + 小时预报接口

### 1.2 后端
新增 `/api/weather` 端点：

**请求**：
```json
{
  "lat": 39.9,
  "lon": 116.4
}
```

**响应**：
```json
{
  "current": {
    "temp": 22,
    "condition": "多云",
    "icon_code": "101"
  },
  "daily": {
    "high": 28,
    "low": 18
  },
  "hourly": [
    {"time_offset": 1, "condition": "小雨", "temp": 18},
    {"time_offset": 2, "condition": "小雨", "temp": 17},
    {"time_offset": 3, "condition": "阴", "temp": 20}
  ]
}
```

缓存策略：Redis 或内存缓存，同一坐标 1 小时内复用。

### 1.3 前端

**位置**：PlannerDashboard 顶部，速记栏下方。

**卡片内容**（三行）：
- 第一行：天气图标 + 当前温度 + 天气状况文字
- 第二行：今日最高温 / 最低温
- 第三行：未来 3 小时简要预报（如"1小时后 小雨 18°C · 3小时后 阴 20°C"）

**位置获取**：Flutter `geolocator` 插件获取经纬度，首次使用请求权限。

**新文件**：
- `mobile_app/lib/features/weather/`（新 feature 目录）
- `backend/app/api/weather.py`（新 API 端点）

---

## 二、速记优化

### 2.1 优先级 P0：语音识别速度

**现状问题**：录音 → 上传 → 等待后端 ASR → 显示结果，用户感知延迟 2-3 秒。

**方案**：前端实时转写 + 后端高精度兜底

1. **本地实时转写**：使用 `speech_to_text` 插件的本地离线识别，录音时实时显示文字（`listenMode: ListenMode.dictation`）
2. **双通道**：
   - 录音时本地识别结果实时显示在速记 bar 下方
   - 停止录音后，后端 ASR 做最终修正
   - 后端结果返回后替换本地结果并解析
3. **进度可视化**：录音时显示波形动画，识别时显示进度条

**改动范围**：
- `speech_capture_gateway.dart`：新增 `startListeningWithPartialResults` 模式
- `quick_capture_bar.dart`：新增实时文字显示区域

### 2.2 优先级 P1：UI 交互流畅度

**现状问题**：速记栏只在 PlannerDashboard（首页标签页）显示，切到其他标签页就不可用。

**方案**：全局悬浮触发按钮 + 全局面板

1. **右下角悬浮按钮**（FAB）：带闪电图标，始终可见
2. **点击展开**：弹出底部 sheet 或全屏速记面板，与现有 QuickCaptureBar 复用核心逻辑
3. **长按触发**：长按悬浮按钮直接启动语音录音

**改动范围**：
- `home_shell_page.dart`：添加 FAB + 全局悬浮面板
- 速记状态从 `QuickCaptureBar` 抽取到 provider 层（全局可访问）

### 2.3 优先级 P2：文本解析准确性

**现状问题**：纯规则引擎覆盖有限，复杂句式（如"下午两点半小区门口取快递"）可能误分类。

**方案**：
1. **规则增强**：扩展 `ScheduleTextParser`，增加更多关键词和模式
2. **类型置信度**：parser 返回时附带置信度，低置信度时在 UI 展示候选分类让用户确认
3. **AI 兜底**（可选）：对于无法解析的句子，调用后端 `/voice/parse` 使用 LLM 辅助解析

**改动范围**：
- `schedule_text_parser.dart`：新增置信度字段、更多规则
- `parsed_schedule_draft.dart`：新增 `confidence` 字段
- `quick_capture_bar.dart`：低置信度时展示确认 UI

---

## 三、技术约束

- 天气 API 调用仅在后端进行，不暴露 API Key 到客户端
- 所有天气请求经过 1 小时缓存
- 语音识别保持现有双模式（本地 `speech_to_text` + 远程 `RemoteAsrClient`）
- 不引入新的第三方 SDK 依赖（除天气图标字体外）

## 四、文件清单

### 新增
- `backend/app/api/weather.py`
- `mobile_app/lib/features/weather/data/weather_repository.dart`
- `mobile_app/lib/features/weather/presentation/weather_card.dart`
- `mobile_app/lib/features/weather/state/weather_controller.dart`
- `backend/app/services/weather.py`（天气 API 封装）

### 修改
- `backend/app/__init__.py`（注册 weather blueprint）
- `backend/requirements.txt`（添加 requests 如需要）
- `mobile_app/lib/features/home/presentation/home_shell_page.dart`（FAB + 全局面板）
- `mobile_app/lib/features/fast_capture/data/speech_capture_gateway.dart`（实时转写）
- `mobile_app/lib/features/fast_capture/state/fast_capture_controller.dart`（全局化状态）
- `mobile_app/lib/features/fast_capture/presentation/quick_capture_bar.dart`（实时文字 + 信心度 UI）
- `mobile_app/lib/features/fast_capture/data/schedule_text_parser.dart`（规则增强 + 置信度）
- `mobile_app/lib/features/fast_capture/domain/parsed_schedule_draft.dart`（confidence 字段）
