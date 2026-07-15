// EntryAbility.ets — Pixel Planner 鸿蒙入口 Ability
// 继承 FlutterAbility，由华为定制 flutter_ohos 插件提供基类。
// 后续可在此重写 configureFlutterEngine() 注册自定义 Platform Channel。

import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);

    // TODO: 在此注册自定义 MethodChannel / EventChannel
    // 示例:
    // GeneratedPluginRegistrant.registerWith(flutterEngine);
  }
}
