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
  private static readonly preferenceKeysKey: string = '__pixelplanner_preference_keys';
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
    if (this.store == null) {
      result.error('storage_unavailable', 'Secure storage is not ready', null);
      return;
    }
    try {
      if (call.method === 'write') {
        const key: string = call.argument('key') as string;
        if (!key) {
          result.error('invalid_key', 'Storage key is required', null);
          return;
        }
        const value: string = (call.argument('value') as string) ?? '';
        await this.store.put(key, value);
        await this.store.flush();
        result.success(null);
      } else if (call.method === 'read') {
        const key: string = call.argument('key') as string;
        if (!key) {
          result.error('invalid_key', 'Storage key is required', null);
          return;
        }
        const value = await this.store.get(key, '');
        result.success(value === '' ? null : value);
      } else if (call.method === 'delete') {
        const key: string = call.argument('key') as string;
        if (!key) {
          result.error('invalid_key', 'Storage key is required', null);
          return;
        }
        await this.store.delete(key);
        await this.store.flush();
        result.success(null);
      } else if (call.method === 'preferencesSet') {
        const key: string = call.argument('key') as string;
        if (!key) {
          result.error('invalid_key', 'Preference key is required', null);
          return;
        }
        const value: string = (call.argument('value') as string) ?? '';
        await this.store.put(key, value);
        await this.addPreferenceKey(key);
        await this.store.flush();
        result.success(null);
      } else if (call.method === 'preferencesRemove') {
        const key: string = call.argument('key') as string;
        if (!key) {
          result.error('invalid_key', 'Preference key is required', null);
          return;
        }
        await this.store.delete(key);
        await this.removePreferenceKey(key);
        await this.store.flush();
        result.success(null);
      } else if (call.method === 'preferencesGetAll') {
        const serialized: Record<string, string> = {};
        const preferenceKeys = await this.getPreferenceKeys();
        for (const preferenceKey of preferenceKeys) {
          const value = await this.store.get(preferenceKey, '');
          serialized[preferenceKey] = value as string;
        }
        result.success(serialized);
      } else if (call.method === 'preferencesClear') {
        const prefix: string = (call.argument('prefix') as string) ?? 'flutter.';
        const preferenceKeys = await this.getPreferenceKeys();
        const remainingKeys: Array<string> = [];
        for (const preferenceKey of preferenceKeys) {
          if (preferenceKey.startsWith(prefix)) {
            await this.store.delete(preferenceKey);
          } else {
            remainingKeys.push(preferenceKey);
          }
        }
        await this.store.put(HarmonySecureStoragePlugin.preferenceKeysKey, JSON.stringify(remainingKeys));
        await this.store.flush();
        result.success(null);
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('storage_error', 'Secure storage operation failed', String(error));
    }
  }

  private async getPreferenceKeys(): Promise<Array<string>> {
    if (this.store == null) {
      return [];
    }
    const serialized = await this.store.get(HarmonySecureStoragePlugin.preferenceKeysKey, '[]') as string;
    try {
      const decoded = JSON.parse(serialized) as Array<string>;
      return decoded.filter((value: string) => value.startsWith('flutter.'));
    } catch (error) {
      return [];
    }
  }

  private async addPreferenceKey(key: string): Promise<void> {
    const preferenceKeys = await this.getPreferenceKeys();
    if (!preferenceKeys.includes(key)) {
      preferenceKeys.push(key);
      await this.store?.put(HarmonySecureStoragePlugin.preferenceKeysKey, JSON.stringify(preferenceKeys));
    }
  }

  private async removePreferenceKey(key: string): Promise<void> {
    const preferenceKeys = await this.getPreferenceKeys();
    const remainingKeys = preferenceKeys.filter((preferenceKey: string) => preferenceKey !== key);
    await this.store?.put(HarmonySecureStoragePlugin.preferenceKeysKey, JSON.stringify(remainingKeys));
  }
}
