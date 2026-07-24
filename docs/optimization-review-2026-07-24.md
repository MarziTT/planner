# PixelPlanner 项目优化审查报告

> 日期: 2026-07-24 | 审查人: Senior Developer
> 范围: 后端 44 个 .py 文件 + 移动端 110 个 .dart 文件

---

## 一、项目规模变化（对比 7月9日审查）

| 维度 | 7月9日 | 7月24日 | 变化 |
|------|--------|--------|------|
| 后端 .py 文件 | 23 | 44 | +21 (Phase 2 新模块) |
| 移动端 .dart 文件 | 62 | 110 | +48 (大量新特性) |
| API Blueprint | 7 | 14 | +7 |
| 数据表 | 8 | 15 | +7 |
| 测试文件 | 5 | 6 | +1 |
| 测试函数 | ~10 | 11 | +1 |

---

## 二、P0 — 必须立即修复

### 后端

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| 1 | `backend/app/services/habits_engine.py:19` | **导入路径错误**: `from .models_habits` → 应为 `from ..models_habits` | 运行时 ImportError，Phase 2 习惯引擎完全不可用 |
| 2 | `backend/app/services/dashboard_service.py:281` | **永假条件**: `"breakfast" in meal_times and "breakfast" not in meal_times` → 永远 False | 早餐通知永远不会触发 |
| 3 | `backend/tests/test_auth.py` | 测试了**不存在的端点** `/api/v1/auth/register` 和 `/api/v1/auth/login` | 测试会失败，假阳性 |

### 移动端

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| 4 | `mobile_app/android/app/build.gradle.kts:29` | **Release 用 debug 签名**发布 | 签名安全性为零，任何人都能伪造 |
| 5 | `features/weather/` | **2 个时间戳备份文件** (weather_controller_20260717...dart, weather_card_20260717...dart) | 死代码占空间，可能混淆维护者 |

---

## 三、P1 — 本周内修复

### 后端 (7 项)

| # | 位置 | 问题 |
|---|------|------|
| 6 | `backend/app/config.py:22` | **弱默认 SECRET_KEY**: `"pixel-planner-dev-secret"` — 生产环境未设置环境变量时 JWT 可被伪造 |
| 7 | `backend/app/config.py:49-51` | **硬编码后门**: `13800000001` / `888888` — 无运行时开关，生产环境仍可用 |
| 8 | `backend/app/config.py` + 多处 | **`datetime.utcnow()` 废弃**: 13+ 处使用 Python 3.12+ 废弃 API |
| 9 | `backend/app/api/auth.py:60-66` | **SMS 验证码 `print()` 输出**: 生产环境泄漏到日志 |
| 10 | `requirements.txt` | **缺少 `python-dateutil`**: `agent.py` 有条件导入但未声明依赖，导致 `_HAS_DATEUTIL = False` |
| 11 | `backend/app/api/weather.py:72-110` | **无认证调试端点**: `/weather/debug` 暴露私钥长度和前缀 |
| 12 | `backend/app/__init__.py` | **`_ensure_tables()` 170 行**: 迁移逻辑混在启动代码中，Alembic 状态与实际库不同步 |

### 移动端 (5 项)

| # | 位置 | 问题 |
|---|------|------|
| 13 | `planner_dashboard.dart` (81KB) | **巨型组件**: 日历+事件+待办+天气+健身全在一个文件 |
| 14 | 3 个文件 | **ZZZ 颜色常量重复**: `home_shell_page`, `login_page`, `planner_dashboard` 各自定义相同颜色 |
| 15 | `dashboard_controller.dart:16` | **死 `FutureProvider`**: `dashboardProvider` 定义后从未被导入 |
| 16 | 各 Repository | **API 响应解析脆弱**: 直接访问 `response.data['data']['items']`，无统一包装器 |
| 17 | `token_storage.dart` + `login_page.dart` | **手机号双重存储**: 同时写 `SharedPreferences`(明文) 和 `FlutterSecureStorage`(加密) |

---

## 四、P2 — 架构改进（本月内）

### 后端

| # | 问题 | 建议 |
|---|------|------|
| 18 | Phase 2 模块**零测试覆盖** (7 个模块) | 补 habits/meals/exercise/transit/routine/dashboard/agent 测试 |
| 19 | **18+ 处 `except Exception: pass`** 无声吞错 | 替换为明确异常类型 + `logging.warning()` |
| 20 | `exercise.py` 底部 `from datetime import datetime` + `noqa: E402` | 移到文件顶部 |
| 21 | `test_auth.py` / `test_planner.py` 中 `make_client()` 重复 | 提取为 conftest fixture |
| 22 | `transit_service.py:322-328` 未使用代码 | 清理 |
| 23 | `_ensure_tables()` 中 SQLite/PostgreSQL 处理不一致 | 统一或迁移到 Alembic |

### 移动端

| # | 问题 | 建议 |
|---|------|------|
| 24 | **架构不一致**: Clean (domain/data/state/ui) vs Flat (models/services/views) 两种范式共存 | 统一为 Clean Architecture |
| 25 | **手动 copyWith + fromJson/toJson** 遍布所有 model | 引入 `freezed` + `json_serializable` |
| 26 | `resource_cache.dart` 中使用 `\\` 硬编码路径分隔符 | 改用 `package:path` 的 `join()` |
| 27 | `api_client.dart` 硬编码生产 URL | 改为 localhost 默认值，生产通过 `--dart-define` 注入 |
| 28 | `_cancelAllReminders()` 空方法体存根 | 实现或删除 |
| 29 | `auth_repository.dart` 中 `_isAuthRejection()` 定义但未调用 | 清理 |
| 30 | `theme_controller.dart` 构造函数体中调用 `_restore()` 导致**双重状态构建** | 在 `super()` 调用中初始化 |

---

## 五、快速修复指南（无需改代码的优先）

### 5 分钟可完成

1. **删除死备份文件**: `rm weather_controller_20260717*.dart weather_card_20260717*.dart`
2. **删除死 `dashboardProvider`**: `dashboard_controller.dart` 第 16-24 行
3. **修复 habits_engine.py 导入**: 改一个字符 `.` → `..`

### 30 分钟可完成

4. **修复 `datetime.utcnow()`**: 13 处全局替换为 `datetime.now(timezone.utc)`
5. **添加 python-dateutil**: `pip install python-dateutil` + 更新 requirements.txt
6. **SMS print → logging**: 5 行改动
7. **修复 dashboard_service.py 永假条件**: 删除重复条件

### 2 小时可完成

8. **统一 ZZZ 颜色常量**: 删除 3 处本地定义，统一从 `zzz_gif_decoration.dart` 导入
9. **创建 Release 签名**: `keytool -genkey` + 更新 build.gradle.kts
10. **修复 test_auth.py**: 改为测试实际存在的 `/send-code` + `/phone-login` 端点

---

## 六、技术债务热力图

```
严重程度
  ▲
P0│  ██░░░░  5 items  (bugs + 死代码 + 签名安全)
P1│  ████░░  12 items (安全 + 废弃API + 架构)
P2│  ██████  13 items (测试 + 一致性 + 工具链)
  └──────────────────► 数量
```

**总计: 30 个可优化项** — 相比 7月9日审查新增了 14 个点，主要是 Phase 2 带来的新模块质量问题和架构不一致。
