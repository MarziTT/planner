---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: fe7e0515290b04070c7aa137e3bf58e6_547a167a81aa11f180b3525400bff409
    ReservedCode1: aQwT3pbPD+3ubuxk2JC+xyd4S3nv3ihMU5Gim21c5Rcz0WTXMAMYqY76VrPx8aJCM2uGzrlb+E7WntS9jvR9SdBX7KrhWvMP5yj7VeFGkD5GuJxPjjJ3s7zD7nGf2Csv4vVkFRhgj11Jic/p5PIfJKoTaEX8XckRGitgFrlW6940ls/ZlYoo71X+Szo=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: fe7e0515290b04070c7aa137e3bf58e6_547a167a81aa11f180b3525400bff409
    ReservedCode2: aQwT3pbPD+3ubuxk2JC+xyd4S3nv3ihMU5Gim21c5Rcz0WTXMAMYqY76VrPx8aJCM2uGzrlb+E7WntS9jvR9SdBX7KrhWvMP5yj7VeFGkD5GuJxPjjJ3s7zD7nGf2Csv4vVkFRhgj11Jic/p5PIfJKoTaEX8XckRGitgFrlW6940ls/ZlYoo71X+Szo=
---

# Profile 改动汇总

> 日期: 2026-07-17
> 项目: F:\PixelPlanner

---

## 改动的文件清单

| # | 文件路径 | 改动类型 | 说明 |
|---|---------|---------|------|
| 1 | `backend\app\models.py` | 新增字段 | Profile 模型新增 6 个字段 |
| 2 | `backend\app\api\profile.py` | 更新逻辑 | `_profile_to_dict` + `update_profile` 支持新字段 |
| 3 | `mobile_app\lib\features\profile\domain\profile_model.dart` | 重构 | 移除 gender/age/city/bio 四个字段 |
| 4 | `mobile_app\lib\features\profile\presentation\profile_page.dart` | 重构 | 移除城市/简介输入框，调整 UI |
| 5 | `mobile_app\lib\features\auth\presentation\login_page.dart` | Bug 修复 | `_savePhone` 中 `setString` 加 `await` |
| 6 | `mobile_app\lib\features\onboarding\presentation\profile_setup_page.dart` | 适配 | 移除 city 相关引用 |

### 数据库迁移

| 数据库 | 表 | 操作 | 新增列 |
|-------|-----|------|-------|
| `data/pixel_planner.db` | `profiles` | ALTER TABLE | identity, routine_start, routine_end, focus_area, wants_fitness, fitness_mode |

---

## 改动详情

### 一、Bug 修复

#### Bug 1: 账号修改资料保存后会被还原
- **原因**: 后端 `Profile` 模型缺少 identity / routine_start / routine_end / focus_area / wants_fitness / fitness_mode 字段，`_profile_to_dict` 未返回、`update_profile` 未保存这些字段
- **修复**: 模型新增 6 个字段 + API 层完整读写

#### Bug 2: 退出登录后手机号不预填
- **原因**: `_savePhone` 中 `SharedPreferences.setString` 缺少 `await`，导致异步写入未完成就跳转页面
- **修复**: `login_page.dart` 第 45 行加 `await`

### 二、功能优化：移除城市和简介字段

前端 `profile_model.dart`、`profile_page.dart`、`profile_setup_page.dart` 中移除 gender/age/city/bio 四个字段的所有引用（后端保留数据库列不动）。profile 页面标题改为"个人设置"。
*（内容由AI生成，仅供参考）*
