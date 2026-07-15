---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: fe7e0515290b04070c7aa137e3bf58e6_e657f910802311f1b7005254006c9bbf
    ReservedCode1: dS3xIIQ5g2QdWmbFMaF+0iWwVbyKlxzKlk4vCblPOoVnbCLDTzJGgeQj0m3hVwcP2OHnmMfsjRdetW+RVf2Z/SreP/tyOHzM6uu7OgOv1th/ocd85gzae3EWh/AcYPpiiOirTKVqR2AdJJ870s8vRpYguZ5BV00/9xF1cKkBAexELN1EE7zymWS+vsA=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: fe7e0515290b04070c7aa137e3bf58e6_e657f910802311f1b7005254006c9bbf
    ReservedCode2: dS3xIIQ5g2QdWmbFMaF+0iWwVbyKlxzKlk4vCblPOoVnbCLDTzJGgeQj0m3hVwcP2OHnmMfsjRdetW+RVf2Z/SreP/tyOHzM6uu7OgOv1th/ocd85gzae3EWh/AcYPpiiOirTKVqR2AdJJ870s8vRpYguZ5BV00/9xF1cKkBAexELN1EE7zymWS+vsA=
---



# 主题系统重设计 Spec

**日期**: 2026-07-15  
**状态**: 设计已确认，待实现

---

## 1. 需求背景

- 现有 5 个主题区分度低，仅靠颜色变化
- 「假面骑士 ZZZ」主题用户不满意
- 主题切换后，App 重启会回退到默认 `premiumMinimal`（`ThemeController` 硬编码初始值，无本地持久化）
- 用户在设置页选主题后依赖后端异步恢复，存在启动闪烁和未访问设置页则不恢复的问题
- 缺少引导页主题选择入口

## 2. 目标

1. 全新 5 个**公共主题**（四季风景方案）：樱花季、海洋、森林、沙漠黄昏、极光
2. **假面骑士 ZZZ** 保留为当前账号专属主题，仅该账号可见可选（后端控制）
3. 主题选择**本地持久化**（SharedPreferences），App 启动立即恢复，无闪烁
4. 引导页（`ProfileSetupPage`）增加主题选择卡片（仅展示公共 5 个，ZZZ 在设置页解锁后出现）
5. 后端仍同步保存主题偏好，但仅作「镜像」，不阻塞 UI

## 3. 主题配色

使用 Material 3 `ColorScheme.fromSeed` 自动派生完整色调。每个主题在亮/暗模式下使用不同 seed 色。

| 主题名 | 枚举值 | 亮色 seed | 暗色 seed | 亮色 surfaceMuted | 暗色 surfaceMuted |
|--------|--------|-----------|-----------|-------------------|-------------------|
| 樱花季 | `sakuraSeason` | `#D98CB3` | `#E8A0BF` | `#FFF5F8` | `#1F1822` |
| 海洋 | `ocean` | `#4A7A9E` | `#5B8DB5` | `#F2F7FB` | `#0F1A24` |
| 森林 | `forest` | `#5A8A6C` | `#6BA17E` | `#F4F9F5` | `#101A14` |
| 沙漠黄昏 | `desertDusk` | `#C1764A` | `#D4895B` | `#FDF7F2` | `#1F1814` |
| 极光 | `aurora` | `#4AB8A6` | `#5CC9B8` | `#F2FAF8` | `#0F1A19` |

默认主题：**森林**（与后端 `forest` 默认值一致）

### 3.1 账号专属主题：假面骑士 ZZZ

| 属性 | 值 |
|------|-----|
| 枚举值 | `kamenRiderZzz`（保留原名，不变） |
| 亮色 seed | `#E53935` |
| 暗色 seed | `#E53935` |
| 亮色 surfaceMuted | `#FFF1F1` |
| 暗色 surfaceMuted | `#170F17` |
| 可见性 | 后端 `/settings` 返回 `availableThemes` 列表控制 |
| GIF 预览 | 保留 `assets/themes/zzz/` 下 4 张 GIF，设置页选中 ZZZ 时展示 |

**可见性逻辑**：
- 后端 `/settings` GET 响应新增字段 `availableThemes: ["sakuraSeason", "ocean", "forest", "desertDusk", "aurora"]`（+ ZZZ 用户额外含 `"kamenRiderZzz"`）
- 客户端收到后过滤主题选择列表
- 引导页永远不展示 ZZZ；设置页根据 `availableThemes` 动态显示

## 4. 架构变更

```
App 启动
  └─ ThemeController 初始化 → SharedPreferences 读缓存 → 立即应用
       ├─ 无缓存 → 默认「森林」
       └─ 有缓存 → 直接恢复

用户切换主题
  └─ ThemeController.switchPreset()
       ├─ 立即生效（state 更新）
       ├─ SharedPreferences 写入
       └─ SettingsController.save() → 后端同步（静默，不阻塞）
```

**关键变更**：`ThemeController` 不再是纯内存状态，引入 `SharedPreferences` 本地缓存层。

## 5. 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/core/theme/theme_controller.dart` | 改 | 6 个枚举（5 公共 + 1 ZZZ）；初始化读 SharedPreferences；`switchPreset` 写入本地缓存；新增 `availableThemes` 状态字段 |
| `lib/core/theme/app_theme.dart` | 不改 | 通用 `AppThemeBuilder.build()` 不受影响，seed/surfaceMuted 由 controller 传入 |
| `lib/features/onboarding/presentation/profile_setup_page.dart` | 改 | 插入 5 个公共主题卡片，ZZZ 不出现 |
| `lib/features/settings/presentation/settings_page.dart` | 改 | 主题下拉框改为根据 `availableThemes` 动态生成；更新主题标签名；移除 `build()` 中脆弱的主题恢复逻辑；保留 ZZZ GIF 预览组件 |
| `lib/features/settings/domain/settings_model.dart` | 改 | 新增 `availableThemes: List<String>` 字段，从后端解析 |
| **后端** `/settings` API | 改 | GET 响应新增 `availableThemes` 数组；当前账号（含 ZZZ 权限）返回完整 6 项 |

## 6. UI 规范

### 6.1 引导页主题卡片

- 位置：`ProfileSetupPage` 中「保存并进入应用」按钮上方，独立 Section
- 标题：「选一个你喜欢的主题」
- 布局：5 个主题卡片，`Wrap` 水平排列，间距 10px
- 卡片尺寸：72×72dp 圆角方块（`BorderRadius.circular(14)`）
- 卡片内容：居中主题色圆形色块（直径 24dp）+ 下方 2 行文字（主题名 + 短描述）
- 选中态：`primary` 色边框 2px，背景 `primaryContainer`
- 选中后即时调用 `themeController.switchPreset()`

### 6.2 设置页主题选择

- 下拉框选项根据 `availableThemes` 动态生成（普通用户 5 项，ZZZ 用户 6 项）
- 标签改为「主题预设」
- 选中 ZZZ 时展示 GIF 预览组件（保留现有 `_ZzzThemePreview`）
- 移除 `build()` 中的 `_lastAppliedSettingsKey` + `addPostFrameCallback` 主题恢复逻辑

## 7. 数据流

1. `ThemeController` 持有 `SharedPreferences` 引用（通过 provider 注入）
2. `switchPreset(preset)` → 更新 state + `prefs.setString('theme', preset.name)` + `prefs.setString('themeMode', mode.name)`
3. App 启动时 `ThemeController()` 构造函数中同步读取 prefs，不存在则用默认「森林」
4. `SettingsController.save()` 照常写后端，由 settings_page 的 onChanged 触发，不影响主题即时切换

## 8. 边界与约束

- `PlannerPalette` 扩展中 success 和 warning 色保持不变（`#2C9A68` / `#F59E0B`），不随主题变化
- `ThemeMode` 逻辑不变（system/light/dark），仅新增本地持久化
- 后端 API `/settings` 的 `theme` 字段仍接受枚举名字符串，新值自动兼容
- 不引入额外第三方依赖（`shared_preferences` 已在项目中使用）

## 9. 验收标准

- [ ] App 首次启动默认显示「森林」主题
- [ ] 在引导页选择「沙漠黄昏」，切换即时生效
- [ ] 完成引导进入首页后，主题保持「沙漠黄昏」
- [ ] 杀掉 App 重新打开，主题仍为「沙漠黄昏」（无闪烁）
- [ ] 在设置页切换到「海洋」，后端 `/settings` 更新为 `theme: "ocean"`
- [ ] 5 个公共主题在亮色/暗色模式下均可读、无不协调色块
- [ ] 引导页主题卡片选中态视觉反馈正确
- [ ] 当前账号的设置页下拉框包含「假面骑士 ZZZ」选项
- [ ] 引导页不展示 ZZZ 选项
- [ ] 选中 ZZZ 时显示 GIF 预览组件
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
