# PixelPlanner Codex 交接说明

更新时间：2026-07-29

## 项目结构

- `backend/`：Flask API、SQLAlchemy 模型、业务服务和测试。
- `mobile_app/`：Flutter 客户端。
- `mobile_app/ohos/`：OpenHarmony 工程骨架和 ArkTS 原生桥接。

## 本次已完成

### 后端

- JWT access/refresh token 类型隔离。
- Bearer token 校验和 JSON 必填字段校验修复。
- 生产环境默认关闭 backdoor 登录；测试配置显式开启。
- 设置接口不再向客户端返回 traceback，失败时回滚事务并记录日志。
- 新增可注入时间服务：`backend/app/services/time_service.py`。
- scene engine 和 widget service 使用统一 Shanghai 时钟。
- 修复天气 debug 接口、运动字段兼容和 widget 跨时区查询。

### Flutter

- `PlannerRepository` 保留旧 `createEvent` API，新增 `createEventWithTags`。
- 修复认证恢复、主题 provider、快速记录流程和若干模型字段。
- Flutter 分析已达到 0 个 error，仍有 warning/info 需要后续清理。

### OpenHarmony

- 恢复 OHOS entry/module/string 资源。
- 增加最小图标和启动背景资源。
- 增加 `HarmonySecureStoragePlugin` 和 `HarmonyNotificationPlugin`。
- 增加 `GeneratedPluginRegistrant` 和 `oh-package.json5`。
- Flutter 侧已根据 `dart.library.ohos` 选择鸿蒙存储和通知实现。
- Flutter 侧新增动态语音输出抽象：`mobile_app/lib/core/voice/`。
- 新增 `mobile_app/lib/core/butler/butler_persona.dart`：普通主题使用标准管家预设，
  ZZZ 主题自动切换为原创的冷静、克制、任务导向预设，并同步语音参数；用户自定义
  管家名字优先级高于主题默认称呼。
- ZZZ 主题核心已重做：`zzz_theme_extension.dart` 提供黑曜石分层、红色警戒、青色
  遥测、完成/警告/危险语义色和终端字体 token；`app_theme.dart` 已统一应用到卡片、
  输入框、按钮、弹窗、导航栏、进度条和 SnackBar。需要在另一台电脑上做实际 UI 截图
  检查，确认不同屏幕尺寸下的对比度和动效表现。
- Agent 查询回答和确认完成后会触发默认 TTS；鸿蒙原生侧需实现
  `pixelplanner/harmony_voice` MethodChannel 的 `speak`、`stop`、`setRate`、
  `setPitch`、`dispose` 方法。

## 当前验证结果

后端关键回归测试：

```text
19 passed
```

Flutter：

```text
0 errors
113 warnings/info
```

## 重要未完成事项

1. 另一台电脑需要安装匹配的 DevEco Studio、HarmonyOS SDK、ohpm 和 Hvigor。
2. 当前项目 Flutter 要求 Dart 3.4+，旧 OpenHarmony Flutter SDK 使用 Dart 2.19.6，不能直接作为最终构建 SDK。
3. 需要使用目标 OpenHarmony Flutter SDK 重新生成/确认 `har/flutter.har`。
4. 在 DevEco 中验证 ArkTS API：
   - `preferences.getPreferences(...)`
   - `notificationManager.addSlot/publish/cancelAll`
   - `FlutterPluginBinding.getApplicationContext()`
5. 需要真机验证通知、SecureStorage、权限和签名。
6. Android/iOS 中原有大量文件目前仍是工作区删除状态，本次没有擅自恢复。
7. 场景测试仍有一个依赖现实系统时间的用例，应改为注入 `app.extensions["clock"]` 的固定时钟。

## 接手后的推荐顺序

1. 在新电脑安装与项目 Dart 版本匹配的 OpenHarmony Flutter SDK。
2. 安装 DevEco Studio 和 API 12+ HarmonyOS SDK。
3. 在 `mobile_app/ohos` 执行 `ohpm install`，确认 `har/flutter.har` 存在。
4. 检查并修正 ArkTS 原生桥接 API，再执行 `flutter build hap`。
5. 接入鸿蒙 TTS 后验证 `pixelplanner/harmony_voice`，确认动态中文播报、停止和
   语速/音调设置正常；不得抓取或克隆影视角色/演员原声。
6. 使用真实签名文件配置 release 构建；不要把 `.ohos/` 中的证书和私钥提交到 Git。
7. 运行后端全量测试和 Flutter 测试。
8. 处理 Flutter warnings，并补齐固定时钟测试。

## 常用命令

```powershell
# 后端
$env:TEMP='D:\Temp'
$env:TMP='D:\Temp'
D:\PixelPlannerDeps\backend-venv\Scripts\python.exe -m pytest backend/tests -q

# Flutter
$env:PUB_CACHE='D:\PubCache'
D:\flutter\bin\flutter.bat pub get
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test

# 鸿蒙（需要在新电脑配置 SDK 后执行）
cd mobile_app
flutter build hap
```

## 提交注意事项

- `backend/data/pixel_planner.db` 是本地运行数据，不应提交。
- `mobile_app/ohos/.ohos/` 可能包含签名证书和私钥，不应提交。
- 环境变量、API key、backdoor 凭据只能通过本地或部署平台 secret 配置。
