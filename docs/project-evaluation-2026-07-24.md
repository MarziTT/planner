# PixelPlanner 项目综合评估报告

> 日期: 2026-07-24 | 审查人: Senior Developer
> 范围: 后端 44 .py + 移动端 110 .dart | 测试 124 后端 + 20 Flutter

---

## 一、紧急缺陷 (P0) — 必须立即修复

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| B1 | `routine_service.dart:232` | **令牌永远为空** — `RoutineService(token: '')` 初始化后 token 从未被设置，所有 API 调用在 `if (token.isEmpty) return` 处静默返回 | 作息模块完全不可用 |
| B2 | `routine_page.dart:69` | **空 baseUrl bug** — `setWakeTime(baseUrl: '', ...)` 传递空字符串 | 设置起床时间 API 调用失败 |
| B3 | `trainer_service.dart:140` | **`_cancelAllReminders()` 空方法体** — 提醒永不取消，可能造成通知泄漏 | 训练提醒残留 |
| B4 | `exercise.py:36` | **内部异常返回 400** — 5 个端点全部将 Exception 返回为 400（应该是 500），且 `str(exc)` 泄漏内部细节 | 错误日志混乱，内部信息泄露 |
| B5 | `__init__.py:77-235` | **SQLite/PostgreSQL 迁移不一致** — 6 个迁移块中 4 个只处理 PostgreSQL，`except Exception: pass` 完全静默 | SQLite 环境下旧数据库列缺失无感知 |
| B6 | `weather.py:72-105` | **debug 端点只需普通登录** — 暴露 API 密钥、JWT token 预览、完整 traceback | 已登录用户可获取敏感信息 |

---

## 二、高危问题 (P1) — 本周内修复

### 后端

| # | 位置 | 问题 | 建议 |
|---|------|------|------|
| B7 | `requirements.txt` | 缺少 `python-dateutil` 依赖声明 | 添加 `python-dateutil>=2.8` |
| B8 | `meals.py:69` | OCR 失败时 `f"OCR failed: {exc}"` 直接暴露异常细节 | 改为 `failure("ocr_failed", "OCR 服务暂不可用")` |
| B9 | `planner.py:412` | import 端点中 `datetime.fromisoformat()` 未捕获异常 | 使用 `_parse_iso_datetime()` 安全解析 |
| B10 | `updates.py:93,102,107` | `abort(404)` 返回 HTML 而非标准 JSON | 改为 `failure("not_found", ..., status=404)` |
| B11 | `habits.py:42` | `detect_patterns` 异常完全吞没，无日志 | 添加 `logger.warning()` |
| B12 | `voice.py:45` | ASR 端点缺少 `@auth_required`，未认证用户可调用 | 添加认证装饰器 |

### 移动端

| # | 位置 | 问题 | 建议 |
|---|------|------|------|
| B13 | 3 个文件 | ZZZ 颜色常量 `int` 重复定义（login_page / home_shell / tags_page） | 统一从 `zzz_gif_decoration.dart` 导入 |
| B14 | 10+ 个文件 | 100+ 处内联 `const Color(0xFF...)` 硬编码 | 统一为命名颜色常量 |
| B15 | `login_page.dart:53-54` | 手机号同时写 SharedPreferences(明文) + SecureStorage(加密) | 只保留 SecureStorage，删除 SharedPreferences 写入 |
| B16 | `dashboard_controller.dart:16` | `dashboardProvider` 死代码 — 定义后从未使用 | 删除 |
| B17 | `auth_repository.dart:130` | `_isAuthRejection()` 死代码 — 定义后从未调用 | 删除 |
| B18 | `theme_controller.dart:33-37` | 双重状态构建 — 构造函数 + `_restore()` 各自构建 ThemeState | 在 `super()` 调用中初始化，`_restore()` 只做异步覆盖 |

---

## 三、代码质量 (P2) — 本月内优化

### 架构一致性

| # | 问题 | 当前状态 | 建议 |
|---|------|----------|------|
| C1 | 架构范式不统一 | 10 个 Clean 模块 + 4 个 Flat 模块 | 将 exercise/meals/transit/habits 统一为 Clean Architecture |
| C2 | API 响应解析无统一包装器 | 每个仓库独立解析 `data['ok']` + `data['data']` | 创建 `ApiResponse` 类统一处理 |
| C3 | `routine_service.dart` 用 `package:http` | 其余全部用 `package:dio` | 统一为 Dio |
| C4 | `exercise_page.dart:58` 手动实例化 Service | 其他模块用 Riverpod provider | 创建 provider |
| C5 | 天气模型定义在 `weather_repository.dart` (data 层) | 违反 Clean Architecture | 移到 domain/models/ |

### 代码重复

| # | 问题 | 位置 |
|---|------|------|
| C6 | `_StatItem` widget 重复 | exercise_page.dart:817 + meal_page.dart:298 |
| C7 | `make_client()` 重复 | test_auth.py:7 + test_planner.py:5（应使用 conftest fixtures） |
| C8 | `zzzColor` 常量重复导出 + 重新定义 | planner_zzz_decoration.dart:10-15 |

### 测试缺口

| # | 缺失测试的模块 | 优先级 |
|---|---------------|--------|
| C9 | `app/api/dashboard.py` — API 端点 | 高 |
| C10 | `app/api/habits.py` — API 端点 | 高 |
| C11 | `app/api/weather.py` — API 端点 | 高 |
| C12 | `app/api/exercise.py` — API 端点（仅测了 service 层） | 中 |
| C13 | `app/api/meals.py` — API 端点（仅测了 service 层） | 中 |
| C14 | `app/api/routine.py` — API 端点（仅测了 service 层） | 中 |
| C15 | `app/api/transit.py` — API 端点（仅测了 service 层） | 中 |
| C16 | `app/api/agent.py` — API 端点（仅测了 service 层） | 中 |
| C17 | Flutter 移动端整体覆盖率 ~15-20% | 低 |

---

## 四、新增功能机会 (P3) — 按价值排序

### 高价值（差异化体验）

| # | 功能 | 描述 | 工作量 |
|---|------|------|--------|
| F1 | **AI 日程智能排程** | 基于用户习惯/天气/通勤的自动日程优化，agent 模块已有基础 | 3-5天 |
| F2 | **健康数据中心** | 运动+饮食+作息 三条数据流整合为可视化仪表板（折线图/热力图/趋势） | 3-5天 |
| F3 | **智能推送通知** | 基于习惯引擎 `detect_patterns()` 的上下文感知推送（如"今天比平时晚起了30分钟"） | 2-3天 |
| F4 | **语音全流程交互** | 已有 ASR 端点，扩展为"一句话安排全天"（语音→解析→创建事件/待办/饮食记录） | 2-3天 |

### 中等价值（体验升级）

| # | 功能 | 描述 | 工作量 |
|---|------|------|--------|
| F5 | **手动添加餐食** | meal_page 已有 `addManual` 方法，连接 UI 弹窗即可 | 0.5-1天 |
| F6 | **ZZZ 角标启用** | 5 处 TODO 注释中隐藏的 ZZZ 角标功能 | 0.5天 |
| F7 | **离线模式** | 本地 SQLite 缓存 + 网络恢复后自动同步 | 2-3天 |
| F8 | **数据导出增强** | 当前仅 JSON 导入导出，增加 CSV/PDF 健康报告导出 | 1-2天 |
| F9 | **Widget 桌面小组件** | iOS/Android 桌面小组件显示今日天气+日程摘要 | 2-3天 |

### 低优先级（锦上添花）

| # | 功能 | 描述 | 工作量 |
|---|------|------|--------|
| F10 | **多设备同步** | 通过后端实现多设备数据同步 | 3-5天 |
| F11 | **社交分享** | 健康成就卡片分享到微信/朋友圈 | 1-2天 |
| F12 | **暗黑模式优化** | 当前已有主题切换基础，完善全局暗黑适配 | 1天 |

---

## 五、技术基础设施 (P4) — 长期规划

| # | 项目 | 价值 | 工作量 |
|---|------|------|--------|
| I1 | 引入 `freezed` + `json_serializable` 替代手写 28-30 个模型类的序列化 | 减少 boilerplate，类型安全 | 2-3天 |
| I2 | 数据库迁移从 `_ensure_tables()` 手写 → Alembic | 规范迁移管理，支持回滚 | 2天 |
| I3 | Flutter 测试覆盖率从 15% → 50% | 质量保障 | 持续进行 |
| I4 | CI/CD 流水线（GitHub Actions：lint + test + build APK） | 自动化质量门禁 | 1天 |
| I5 | 后端 API 文档自动生成（Flask-RESTX / Swagger） | 14 个 API Blueprint 自动维护 | 1天 |
| I6 | 统一 `exercise.py` 错误码命名（`missing_field` → `validation_error`） | API 一致性 | 0.5天 |

---

## 六、优先级建议

```
紧急度
  ▲
P0│  ██  6 items  — 必须立即修复（作息模块不可用 + 安全泄漏）
P1│  ██  1"2 items  — 本周修复（API 一致性 + 代码死肉 + 颜色混乱）
P2│  ██  17 items — 本月优化（架构统一 + 测试补充）
P3│  ██  12 items — 新功能机会（AI 体验升级 + 离线模式）
P4│  ██  6 items  — 基础设施（freezed + Alembic + CI/CD）
  └─────────────────────► 数量
```

**建议推进顺序：P0 紧急修复 → P1 高危清理 → P3 高价值功能（挑 1-2 个）→ P2 架构统一（边做边改）**
