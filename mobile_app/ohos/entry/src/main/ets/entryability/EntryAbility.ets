// PixelPlanner 鸿蒙入口 Ability。
// MethodChannel 的具体注册由 OpenHarmony-SIG Flutter SDK 提供；原生桥接
// 实现应在确认 SDK 版本后接入，避免把 Android API 误用到 ArkTS。
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import HarmonyHealthPlugin from '../plugins/HarmonyHealthPlugin';
import HarmonyDevicePermissionPlugin from '../plugins/HarmonyDevicePermissionPlugin';
import HarmonyNotificationPlugin from '../plugins/HarmonyNotificationPlugin';
import HarmonySecureStoragePlugin from '../plugins/HarmonySecureStoragePlugin';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    flutterEngine.getPlugins()?.add(new HarmonySecureStoragePlugin());
    flutterEngine.getPlugins()?.add(new HarmonyNotificationPlugin());
    flutterEngine.getPlugins()?.add(new HarmonyHealthPlugin(this.context));
    flutterEngine.getPlugins()?.add(new HarmonyDevicePermissionPlugin(this.context));
  }
}
