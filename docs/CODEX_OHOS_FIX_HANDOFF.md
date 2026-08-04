# HarmonyOS 修复交接（给业务代码 Codex）

## 当前状态

PixelPlanner 已能在 HUAWEI Pura 70 Pro 上构建、签名、安装、启动和登录，但 OHOS 原生插件适配不完整。当前调试版为绕过阻塞使用了内存存储，不能作为最终实现。

## 必须修复的问题

### P0：OHOS 插件未注册导致启动白屏

`GeneratedPluginRegistrant.ets` 当前没有注册任何实际插件。以下 Flutter 插件/MethodChannel 在 OHOS 上不可用：

- `shared_preferences`
- `flutter_secure_storage`
- `flutter_local_notifications`
- 项目自定义 `pixelplanner/harmony_secure_storage`
- 项目自定义 `pixelplanner/harmony_notifications`

表现：

- `SharedPreferences.getInstance()` 在 `runApp()` 前不返回，屏幕保持白色。
- Dio 拦截器读取 Token 时调用未注册存储插件，请求可能在发出前失败。

临时调试方案：

- OHOS 使用 `SharedPreferences.setMockInitialValues({})`。
- OHOS 使用内存型 `TokenStorage`。

最终方案：实现并注册 ArkTS Preferences/Keystore 插件，或引入支持 OHOS 的正式插件包；初始化失败不得阻塞首帧。

### P0：错误的平台判断

项目多处使用：

```dart
bool.fromEnvironment('dart.library.ohos')
```

在当前 Flutter OHOS SDK 中该值不是 `true`。应统一使用：

```dart
Platform.operatingSystem == 'ohos'
```

并封装为单一平台能力入口，避免散落判断。

### P1：登录页在认证状态变化时被重建

登录失败后输入框曾被清空。原因之一是 `appRouterProvider` 监听整个 `AuthState` 并重新创建 `GoRouter`。当前调试补丁用静态字段保留输入，只是止血方案。

最终方案：

- `GoRouter` 保持单一实例。
- 使用 `refreshListenable` 或受控重定向刷新认证状态。
- 手机号持久化，验证码至少在失败后保留。
- 登录失败只更新错误提示，不销毁登录页 State。

### P1：首页产品结构需要确认

当前 `/home` 默认显示 `HabitsDashboard`，底部导航分别为出行、饮食、运动、标签、个人、设置。旧 `PlannerDashboard` 仍在仓库，但不再作为入口。

需与用户确认所谓“整合后的页面”究竟是：

- 当前多标签生活仪表盘；或
- 日程、待办、习惯、健康集中在单一首页的 PlannerDashboard 设计。

### P1：OHOS 本地持久化缺失

当前调试用内存存储意味着：

- 杀进程后登录态丢失。
- 手机号、主题、管家名称和部分缓存丢失。
- SharedPreferences 相关功能只在本次进程有效。

### P1：通知能力未完成

`NotifyManager.ensureChannels()` 在启动阶段执行。若原生通知 Channel 不存在，必须容错并延后初始化，不能阻塞 `runApp()`。

## 已验证接口

- `GET /healthz`：服务在线。
- `POST /api/v1/auth/send-code`，手机号 `13800000001`：200。
- `POST /api/v1/auth/phone-login`，验证码 `888888`：200，用户 ID 8。

## 构建约定

1. 在 `G:\PixelPlanner` 修改并提交 Git。
2. 同步到 `D:\PixelPlannerBuild`。
3. 用 `D:\flutter_ohos_latest` 调试或构建。
4. DevEco 自动签名后安装到真机。

