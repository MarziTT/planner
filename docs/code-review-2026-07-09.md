# PixelPlanner 项目技术审查报告

> 审查人：高级开发工程师  
> 日期：2026-07-09  
> 范围：backend/ (Flask) + mobile_app/ (Flutter) 全量代码

---

## 一、项目概览

| 维度 | 技术选型 |
|------|---------|
| 后端 | Flask 3.0 + SQLAlchemy + Flask-Migrate + PyJWT |
| 数据库 | PostgreSQL (生产) / SQLite (开发/测试) |
| 部署 | Railway (gunicorn + Procfile) |
| 移动端 | Flutter + Riverpod + Dio + GoRouter |
| 认证 | JWT (access + refresh token) |

项目功能覆盖：用户注册/登录、日程事件管理、待办事项、标签、个人资料、设置、数据导入导出、语音识别(mock)、应用更新检查。

**总体评价**：项目结构清晰、分层合理（API → Service → Model / Repository → Controller → View），基础架构选型不错。但在安全性、错误处理、测试覆盖和工程规范方面存在明显的短板，需要系统性提升。

---

## 二、问题清单（按严重程度分级）

### P0 — 必须立即修复（安全/数据丢失风险）

#### 1. CORS 配置完全放开 — 生产环境安全漏洞
**文件**: `backend/app/__init__.py:19`
```python
cors.init_app(app, resources={r"/api/*": {"origins": "*"}})  # 允许任意来源
```
**风险**: 任意网站都可以向你的 API 发请求，配合 JWT bearer token 可被 CSRF 或 token 窃取利用。  
**修复建议**: 生产环境限定具体域名，开发环境通过配置切换。

#### 2. `_ensure_tables` 中 DROP TABLE CASCADE — 生产数据丢失风险
**文件**: `backend/app/__init__.py:52-66`
```python
if "email" not in cols:
    # Drop all user tables with CASCADE, then recreate
    db.session.execute(text("DO $$ ... DROP TABLE IF EXISTS ... CASCADE ..."))
```
**风险**: 如果 users 表结构异常（如迁移中断），此代码会**删除整个生产数据库**然后重建。Procfile 中 `ensure_tables.py` 在每次部署时运行。  
**修复建议**: 删除此逻辑，改用正确的 migration 管理 schema 变更。如需修复，应通过备份 + 手动迁移完成。

#### 3. JWT 未校验 token 类型 — 越权风险
**文件**: `backend/app/api/common.py:41-46`
```python
payload = decode_token(token=token, ...)  # 未检查 payload["type"] == "access"
```
**风险**: refresh token 也可作为 access token 使用。refresh token 有效期 30 天，一旦泄露攻击窗口极大。  
**修复建议**: 在 `auth_required` 中增加 `payload.get("type") != "access"` 检查。

#### 4. Refresh token 明文存储 — 数据泄露风险
**文件**: `backend/app/api/auth.py:59, 88`
```python
RefreshToken(token=tokens["refreshToken"], ...)  # 明文存储
```
**风险**: 数据库泄露后所有 refresh token 可直接使用。  
**修复建议**: 存储 token 的 SHA-256 hash，验证时对传入 token 做 hash 后比对。

#### 5. 无密码强度校验
**文件**: `backend/app/api/auth.py:41`
```python
password_hash=generate_password_hash(payload["password"])  # 无长度/复杂度检查
```
**风险**: 用户可设置 "1" 作为密码。  
**修复建议**: 至少要求 8 字符长度。

---

### P1 — 应尽快修复（功能/可靠性问题）

#### 6. Profile/Settings 为 None 时崩溃
**文件**: `backend/app/api/profile.py:27, 33` / `backend/app/api/settings.py:27, 33`
```python
profile = Profile.query.filter_by(user_id=...).first()
return success({"item": _profile_to_dict(profile)})  # profile 可能为 None
```
**问题**: 如果用户记录未自动创建 Profile/AppSetting，`_profile_to_dict(None)` 会 AttributeError。`update_profile` 同样会在 `profile.gender = ...` 处崩溃。  
**修复建议**: 查询后检查 None，不存在则自动创建。

#### 7. datetime 解析无异常处理
**文件**: `backend/app/api/planner.py:65, 88, 90, 133, 154, 286-287, 301`
```python
starts_at=datetime.fromisoformat(payload["startsAt"]),  # 非法格式直接 500
```
**修复建议**: 用 try/except 包裹，返回 422 验证错误。

#### 8. 无速率限制 — 暴力破解风险
**问题**: `/auth/login` 和 `/auth/register` 无任何速率限制。  
**修复建议**: 接入 Flask-Limiter，限制如 5 次/分钟/IP。

#### 9. 移动端无 Token 自动刷新机制
**文件**: `mobile_app/lib/core/network/api_client.dart`
**问题**: Dio interceptor 只添加 access token，不处理 401 → refresh → retry 流程。access token 过期后（1 小时）所有请求失败，用户被迫重新登录。  
**修复建议**: 增加响应拦截器，401 时自动用 refresh token 换新 access token 并重试请求。

#### 10. 无日志记录 — 全后端零 logging
**问题**: 所有异常被 `except Exception: pass` 或 `catch (_)` 静默吞掉。生产排查问题无任何线索。  
**修复建议**: 
- 后端：接入 Python logging，记录请求/异常/关键操作
- 前端：增加错误上报（如 Sentry）

#### 11. 导入操作无事务保护
**文件**: `backend/app/api/planner.py:262-309`
**问题**: `import_data` 中循环 add 后统一 commit，但如果第 5 条数据出错，前 4 条已 add 到 session。虽然 commit 失败会回滚，但错误信息不明确。  
**修复建议**: 包裹在 `with db.session.begin()` 中，失败时返回明确错误。

#### 12. 列表接口无分页
**文件**: `backend/app/api/planner.py:44-52, 112-120`
**问题**: `list_events` 和 `list_todos` 返回全部记录。用户数据量大时严重影响性能。  
**修复建议**: 增加 `page` + `pageSize` 参数，返回总数和分页元数据。

---

### P2 — 建议改进（代码质量/可维护性）

#### 13. `register_models()` 是空函数
**文件**: `backend/app/models.py:102-103`
```python
def register_models() -> None:
    return None  # 什么也没做
```
**问题**: 死代码，让人误以为有注册逻辑。  
**修复**: 删除此函数及其调用。

#### 14. 测试 fixture 重复
**文件**: `backend/tests/test_auth.py` 和 `test_planner.py`
**问题**: `make_client()` 函数在两个测试文件中完全重复，`conftest.py` 只做了 sys.path 设置。  
**修复**: 在 `conftest.py` 中定义 `@pytest.fixture` 并共享。

#### 15. 测试覆盖不足
**当前**: 仅 4 个测试文件，覆盖 register/login/profile/planner 基础流程。  
**缺失**: 
- 无 settings 接口测试
- 无 voice/updates 接口测试
- 无边界条件测试（空数据、非法输入、权限越界）
- 无并发测试
- Flutter 端零测试

#### 16. 移动端 `_ProfileRhythmCard` 使用 `dynamic` 类型
**文件**: `mobile_app/lib/features/planner/presentation/planner_dashboard.dart:322`
```dart
final dynamic profile;  // 完全丢失类型安全
```
**修复**: 使用具体的 Profile model 类型。

#### 17. `planner_dashboard.dart` 文件过大（597 行）
**问题**: 单文件包含 dashboard + 6 个内部 widget 类 + 编辑弹窗逻辑。  
**修复**: 拆分为独立文件：`event_tile.dart`、`todo_tile.dart`、`event_editor_dialog.dart` 等。

#### 18. `schedule_text_parser.dart` 使用 Unicode 转义
**问题**: 所有中文字符用 `\u660e\u5929` 等转义，可读性极差。  
```dart
if (input.contains('\u660e\u5929')) {  // vs: if (input.contains('明天'))
```
**修复**: 直接使用中文字符，确保文件编码为 UTF-8。

#### 19. 硬编码生产 URL
**文件**: `mobile_app/lib/core/network/api_client.dart:6`
```dart
const _defaultApiBaseUrl = 'https://planner-production-d1ee.up.railway.app/api/v1';
```
**问题**: 开发环境无法指向本地后端。  
**修复**: 使用 `--dart-define` 或 flavor 配置区分环境。

#### 20. 无 API 文档
**问题**: 无 OpenAPI/Swagger 文档，前后端对接靠口口相传。  
**修复**: 接入 flask-smorest 或 apispec 自动生成 API 文档。

#### 21. 无 CI/CD 流水线
**问题**: 无自动化测试、lint、部署流程。  
**修复**: 增加 GitHub Actions，至少包含 lint + test 步骤。

#### 22. 无 Lint 配置
**问题**: Python 端无 ruff/flake8 配置，Flutter 端无自定义 `analysis_options.yaml`。  
**修复**: 
- Python: `ruff` + `mypy`
- Flutter: 启用 `flutter_lints` 严格规则

#### 23. 业务逻辑散落在路由处理函数中
**问题**: `planner.py` 中 CRUD 逻辑、序列化、验证全在 route handler 内。  
**修复**: 抽取 service 层，route 只负责 HTTP 入出参。

#### 24. `_ensure_tables` 中 except Exception: pass
**文件**: `backend/app/__init__.py:67-68`
```python
except Exception:
    pass  # 静默吞掉所有错误
```
**修复**: 至少记录日志。

---

## 三、架构评估

### 优点
1. **分层清晰**: 后端 API → Service → Model 三层，移动端 data → domain → state → presentation 四层
2. **技术选型合理**: Flask 轻量灵活，Riverpod 状态管理现代化，Dio + GoRouter 组合成熟
3. **统一响应格式**: `{ok, data, error, meta}` 规范统一
4. **JWT + Refresh Token**: 认证架构设计正确（但实现有缺陷）
5. **Feature-based 组织**: 移动端按 feature 模块拆分，可维护性好

### 不足
1. **无 Service 层**: 后端 route handler 直接操作 ORM，业务逻辑和 HTTP 层耦合
2. **无 Schema 验证**: 缺少 marshmallow/pydantic 做请求体验证
3. **无错误处理中间件**: 没有全局异常处理器，未捕获异常直接 500
4. **Migration 不完整**: 有 Flask-Migrate 但 `register_models()` 为空，实际靠 `db.create_all()`
5. **无环境隔离**: 移动端无 dev/staging/prod 配置

---

## 四、团队技术提升建议

### 4.1 短期（1-2 周）
1. **修复所有 P0 问题** — 安全漏洞必须第一时间堵上
2. **接入 ruff + mypy** — 统一代码风格，引入类型检查
3. **补充 conftest.py** — 共享测试 fixture
4. **增加全局异常处理** — Flask `@app.errorhandler(Exception)`

### 4.2 中期（1-2 月）
1. **引入 Service 层** — 将业务逻辑从 route 中抽离
2. **接入 Schema 验证** — 用 pydantic 或 marshmallow 做请求验证
3. **实现 Token 自动刷新** — 移动端 Dio interceptor 完善刷新逻辑
4. **补充测试** — 后端覆盖率目标 80%，移动端引入 widget test
5. **搭建 CI/CD** — GitHub Actions: lint → test → deploy
6. **接入日志系统** — Python logging + 结构化日志

### 4.3 长期（3-6 月）
1. **API 文档自动化** — OpenAPI spec 自动生成
2. **监控告警** — Sentry/接入了再考虑 APM
3. **性能优化** — 数据库索引审查、查询优化、分页
4. **容器化** — Docker + docker-compose 本地开发环境
5. **Code Review 流程** — PR 模板 + 必须审批

---

## 五、优先级行动清单

| 优先级 | 事项 | 预估工作量 |
|--------|------|-----------|
| P0 | 修复 CORS 配置（限定域名） | 0.5h |
| P0 | 移除 `_ensure_tables` 中 DROP CASCADE 逻辑 | 0.5h |
| P0 | JWT 增加 token 类型校验 | 0.5h |
| P0 | Refresh token hash 存储 | 2h |
| P0 | 密码强度校验 | 0.5h |
| P1 | Profile/Settings None 保护 | 1h |
| P1 | datetime 解析异常处理 | 1h |
| P1 | 接入 Flask-Limiter 速率限制 | 2h |
| P1 | 移动端 Token 自动刷新 | 4h |
| P1 | 接入 logging | 2h |
| P2 | 删除 `register_models()` 空函数 | 5min |
| P2 | 统一测试 fixture | 1h |
| P2 | 修复 Unicode 转义为明文中文 | 0.5h |
| P2 | 拆分 planner_dashboard.dart | 2h |
| P2 | 接入 ruff + mypy | 1h |
| P2 | 搭建 CI/CD | 3h |

---

*报告完。建议从 P0 安全问题开始逐项修复，我可以逐条协助实施。*
