# 天气功能 & 速记优化 - 实现计划

## 阶段一：天气功能

### Step 1: 后端 - 天气 API 封装
**文件**：`backend/app/services/weather.py`
- 封装和风天气 API 调用
- 获取实时天气 + 3 天预报 + 小时级预报
- 支持传入经纬度自动定位城市

### Step 2: 后端 - 天气 API 端点
**文件**：`backend/app/api/weather.py`
- 新增 `/api/v1/weather` 端点
- 请求参数：lat, lon
- 返回：current（temp/condition/icon_code）、daily（high/low）、hourly（3条）
- 内存缓存 1 小时

### Step 3: 后端 - 注册路由
**文件**：`backend/app/api/__init__.py`
- 注册 weather blueprint

### Step 4: Flutter - 天气状态管理
**文件**：`mobile_app/lib/features/weather/state/weather_controller.dart`
- Riverpod StateNotifier
- 请求位置权限 → 获取经纬度 → 调后端 API
- 刷新逻辑

### Step 5: Flutter - 天气数据层
**文件**：`mobile_app/lib/features/weather/data/weather_repository.dart`
- 调用后端 `/api/v1/weather`
- 模型类定义

### Step 6: Flutter - 天气卡片组件
**文件**：`mobile_app/lib/features/weather/presentation/weather_card.dart`
- 三行布局：当前天气 + 高低温 + 小时预报
- 集成主题系统
- 骨架屏加载态

### Step 7: Flutter - 集成到首页
**文件**：`mobile_app/lib/features/planner/presentation/planner_dashboard.dart`
- 在顶部嵌入 WeatherCard
- 登录后自动加载

## 阶段二：速记优化 - 语音识别速度

### Step 8: 实时转写模式
**文件**：`mobile_app/lib/features/fast_capture/data/speech_capture_gateway.dart`
- 新增 `startListeningStream` 方法，逐字返回识别结果
- 保留后端 ASR 作为最终修正

### Step 9: UI 实时反馈
**文件**：`mobile_app/lib/features/fast_capture/presentation/quick_capture_bar.dart`
- 录音时显示实时识别文字
- 波形动画

### Step 10: Controller 适配
**文件**：`mobile_app/lib/features/fast_capture/state/fast_capture_controller.dart`
- `startListening` 支持流式结果

## 阶段三：速记优化 - 全局面板

### Step 11: 全局 FAB + 速记面板
**文件**：`mobile_app/lib/features/home/presentation/home_shell_page.dart`
- 右下角 FAB（闪电图标，始终可见）
- 点击弹出全屏速记 panel
- 长按直接启动录音
- 复用现有 QuickCaptureBar 核心逻辑

## 阶段四：速记优化 - 解析增强

### Step 12: 文本解析增强
**文件**：`mobile_app/lib/features/fast_capture/data/schedule_text_parser.dart`
- 扩展事件类型关键词
- 新增置信度计算
- 处理更多时间表述

### Step 13: 歧义确认增强
**文件**：`mobile_app/lib/features/fast_capture/domain/parsed_schedule_draft.dart`
- 新增 `confidence` 字段
- 低置信度时展示分类确认 UI

---

## 执行顺序
阶段一（Step 1-7）→ 阶段二（Step 8-10）→ 阶段三（Step 11）→ 阶段四（Step 12-13）

按这个顺序开始执行。
