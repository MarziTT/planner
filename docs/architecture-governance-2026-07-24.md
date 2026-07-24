# PixelPlanner 后端架构治理文档

> 生成于 2026-07-24 | Phase 2 测试覆盖完成后

---

## 当前架构全景

项目采用**两种范式并存**的设计：

| 模块层级 | 范式 | 代表模块 |
|----------|------|----------|
| Phase 0/1 API | Flat Service | `planner.py`, `auth.py`, `profile.py` — API route 直接调用 DB query |
| Phase 1 Agent | Pure Function | `agent.py` — 零 DB 依赖的纯解析器 |
| Phase 2 API | Flat Service + DB | `exercise.py`, `meals.py`, `routine.py`, `transit.py` — 业务逻辑在 service 层，API route 很薄 |
| Phase 2 Habits | Service + Models | `habits_engine.py`, `dashboard_service.py` — 较重的 DB 依赖 |

### 移动端架构

```
mobile_app/lib/
├── core/         # 跨模块基础设施 (network, storage, theme)
├── app/          # App 入口 + 路由
├── features/     # 功能模块 (Clean Architecture 风格)
│   ├── auth/         # domain / data / state / presentation
│   ├── planner/      # domain / data / state / presentation
│   ├── fast_capture/ # data / presentation (简化)
│   └── ...
└── widgets/      # 全局可复用组件
```

---

## 模块职责清单

### 后端 Service 层

| 文件 | 职责 | 依赖 | 测试文件 |
|------|------|------|----------|
| `agent.py` | 中文日程语义解析 | 无 (纯逻辑) + 可选 LLM | `test_agent.py` (17 用例) |
| `transit_service.py` | 地铁票 OCR + 地铁路线规划 | OcrCache DB + LLM API | `test_transit.py` (18 用例) |
| `exercise_service.py` | 运动模式管理 + 运动记录 CRUD | User + ExerciseRecord | `test_exercise.py` (13 用例) |
| `meal_service.py` | 餐食 OCR + 记录 + 卡路里统计 | MealRecord + OcrCache | `test_meal.py` (17 用例) |
| `routine_service.py` | 起床/睡眠/站立提醒 | UserPattern + EventHistory | `test_routine.py` (17 用例) |
| `habits_engine.py` | 习惯检测 + 提前通知计算 | EventHistory + MealRecord + NotifyPreference | 待补充 |
| `dashboard_service.py` | 仪表盘聚合视图 | 多模块级联 | 待补充 |

### 架构演进路线

```
当前状态 (Phase 2):
  Flat Service\_____________  Clean Architecture (部分)
  (api/ + services/)               (features/*/domain,data,state,ui)

建议 Phase 3:
  1. habits_engine → 抽取纯逻辑测试 (如 _summarise_patterns)
  2. dashboard_service → 拆分注入为策略模式
  3. 统一移动端 features/ 下所有模块为 Clean Architecture 四层
  4. 引入 OpenAPI / Swagger 文档自动生成
```

---

## 测试覆盖统计

| 指标 | Phase 0 | Phase 1 | Phase 2 | 合计 |
|------|---------|---------|---------|------|
| 测试文件数 | 5 | 1 | 5 | 11 |
| 测试用例数 | 9 | 17 | 65 | 91 |
| 通过率 | 100% | 100% | 100% | 100% |

### 新增长测试用例明细

| 测试文件 | 用例数 | 类型 |
|---------|--------|------|
| test_agent.py | 17 | 纯逻辑 (无DB) |
| test_transit.py | 18 | 纯逻辑 (无DB) + Dataclass |
| test_exercise.py | 13 | DB fixture |
| test_meal.py | 17 | DB fixture + 纯逻辑 |
| test_routine.py | 17 | DB fixture |

### 待补充测试

| 模块 | 优先级 | 原因 |
|------|--------|------|
| `habits_engine.py` | 中 | 依赖 5 个模型，需大量 fixture 数据 |
| `dashboard_service.py` | 中 | 级联依赖 6 个服务，需 mock 框架 |
| `weather.py` | 低 | 外部 API 依赖，需 mock httpx |
| `agent.py` (LLM 路径) | 低 | 需 mock `requests.post` |

---

## 测试 Fixture 清单

`conftest.py` 提供的 fixture：

| fixture | 作用 |
|---------|------|
| `app` | Flask 测试应用 (SQLite :memory:) |
| `client` | Flask test client |
| `db_session` | SQLAlchemy session |
| `test_user` | 基础用户 (phone: 13800000001) |
| `test_user2` | 第二用户 (用于隔离测试) |
| `test_event` | 基础事件 |
| `test_todo` | 基础待办 |
