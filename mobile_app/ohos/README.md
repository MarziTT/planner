# Pixel Planner - HarmonyOS NEXT 适配记录

## 当前状态

:hammer: **工程骨架已搭建**（2026-07-14）— ohos/ 目录结构已创建，等待安装华为定制 Flutter SDK 后构建。

---

## 前置环境依赖

| 前置条件 | 状态 | 说明 |
|---------|------|------|
| 华为定制 Flutter SDK | :x: 未安装 | 需从 [OpenHarmony-SIG/flutter_flutter](https://gitee.com/openharmony-sig/flutter_flutter) 拉取 |
| DevEco Studio | :x: 未安装 | 用于签名、调试和 HAP 打包 |
| HarmonyOS SDK | :x: 未安装 | 随 DevEco Studio 安装，或通过 Command Line Tools 单独安装 |
| Node.js (LTS) | :grey_question: 待确认 | Hvigor 构建工具链依赖 |
| 华为开发者联盟账号 | :x: 未注册 | [developer.huawei.com](https://developer.huawei.com/consumer/cn/) |

---

## 适配待办清单

### 环境搭建

- [ ] 安装华为定制 Flutter SDK（Gitee: OpenHarmony-SIG/flutter_flutter）
- [ ] 配置 `PUB_HOSTED_URL` 和 `FLUTTER_STORAGE_BASE_URL` 指向华为源
- [ ] 安装 DevEco Studio 和 HarmonyOS SDK (API 12+)
- [ ] 运行 `flutter doctor -v` 确认 Ohos 工具链可识别
- [ ] 运行 `flutter create --platforms=ohos .` 补齐自动生成文件

### 签名与发布

- [ ] 注册华为开发者联盟账号（需实名认证）
- [ ] 在 DevEco Studio 中生成 `.p12` 密钥和 CSR
- [ ] 在开发者联盟申请数字证书（`.cer`）和 Profile（`.p7b`）
- [ ] 将签名文件放入 `ohos/.ohos/config/` 并更新 `build-profile.json5`

### 插件适配（核心工作量）

| Flutter 插件 | 鸿蒙兼容性 | 适配方案 |
|-------------|-----------|---------|
| `flutter_riverpod` | :white_check_mark: 纯 Dart | 无需适配 |
| `go_router` | :white_check_mark: 纯 Dart | 无需适配 |
| `dio` | :white_check_mark: 纯 Dart | 需声明 `ohos.permission.INTERNET` |
| `intl` | :white_check_mark: 纯 Dart | 无需适配 |
| `crypto` | :white_check_mark: 纯 Dart | 无需适配 |
| `timezone` | :white_check_mark: 纯 Dart | 无需适配 |
| `flutter_secure_storage` | :warning: 需适配 | 编写 ArkTS MethodChannel，对接 OHOS Keystore / Preferences API |
| `flutter_local_notifications` | :warning: 需适配 | 编写 ArkTS 通知发布与响应逻辑 |
| `speech_to_text` | :warning: 需适配 | 对接 OHOS 语音识别 API |
| `record` | :warning: 需适配 | 对接 OHOS 麦克风录制 API（已声明 `ohos.permission.MICROPHONE`） |
| `path_provider` | :warning: 需适配 | 对接 OHOS 沙箱文件路径 API |
| `url_launcher` | :warning: 需适配 | 对接 OHOS Want/Ability 跳转 |
| `cupertino_icons` | :white_check_mark: 纯资源 | 无需适配 |

### 构建与测试

- [ ] 执行 `flutter build hap` 生成调试 HAP
- [ ] 在鸿蒙真机上安装并运行 HAP
- [ ] 功能回归测试（导航、语音录制、通知、数据持久化）
- [ ] 执行 `flutter build app` 生成上架 .app 文件

---

## 目录结构说明

```
ohos/
├── .gitignore                  # 忽略构建产物和签名文件
├── build-profile.json5         # 根构建配置（签名、SDK 版本、模块声明）
├── hvigorw / hvigorw.bat       # Hvigor 构建包装脚本 (Linux/Win)
├── hvigor/
│   └── hvigor-config.json5     # Hvigor 版本及插件依赖
├── AppScope/
│   └── app.json5               # 应用全局配置（包名、版本号、图标）
├── entry/                      # 主模块 (HAP)
│   ├── build-profile.json5     # entry 模块构建选项
│   ├── hvigorfile.ts           # entry 模块 hvigor 任务入口
│   └── src/main/
│       ├── module.json5        # 模块清单（Ability、权限声明）
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets   # Flutter 入口 Ability
│       │   └── plugins/               # 原生插件目录（待适配）
│       └── resources/
│           └── base/
│               ├── element/string.json
│               └── media/             # 图标等资源（待补充）
```

---

## 参考资源

- [OpenHarmony-SIG/flutter_flutter](https://gitee.com/openharmony-sig/flutter_flutter) — 华为定制 Flutter SDK
- [HarmonyOS 应用开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-guide)
- [Flutter 鸿蒙适配 FAQ](https://gitee.com/openharmony-sig/flutter_flutter/wikis)
