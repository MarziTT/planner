import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import preferences from '@ohos.data.preferences';

export default class HarmonySecureStoragePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private store: preferences.Preferences | null = null;

  getUniqueClassName(): string {
    return 'HarmonySecureStoragePlugin';
  }

  async onAttachedToEngine(binding: FlutterPluginBinding): Promise<void> {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'pixelplanner/harmony_secure_storage',
    );
    this.channel.setMethodCallHandler(this);
    this.store = await preferences.getPreferences(binding.getApplicationContext(), {
      name: 'pixelplanner_secure_storage',
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.store = null;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    const args = (call.arguments ?? {}) as Record<string, string>;
    const key = args['key'];
    if (this.store == null || !key) {
      result.error('storage_unavailable', 'Secure storage is not ready', null);
      return;
    }
    try {
      if (call.method === 'write') {
        await this.store.put(key, args['value'] ?? '');
        await this.store.flush();
        result.success(null);
      } else if (call.method === 'read') {
        result.success(await this.store.get(key, null));
      } else if (call.method === 'delete') {
        await this.store.delete(key);
        await this.store.flush();
        result.success(null);
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('storage_error', 'Secure storage operation failed', String(error));
    }
  }
}
