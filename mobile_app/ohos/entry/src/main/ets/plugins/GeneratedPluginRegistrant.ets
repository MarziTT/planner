import { FlutterEngine, Log } from '@ohos/flutter_ohos';
import HarmonySecureStoragePlugin from './HarmonySecureStoragePlugin';
import HarmonyNotificationPlugin from './HarmonyNotificationPlugin';

export class GeneratedPluginRegistrant {
  static registerWith(flutterEngine: FlutterEngine): void {
    try {
      flutterEngine.getPlugins()?.add(new HarmonySecureStoragePlugin());
      flutterEngine.getPlugins()?.add(new HarmonyNotificationPlugin());
    } catch (error) {
      Log.e('GeneratedPluginRegistrant', 'Plugin registration failed', error);
    }
  }
}
