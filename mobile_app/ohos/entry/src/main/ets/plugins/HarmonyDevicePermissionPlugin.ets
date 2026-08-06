import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import type common from '@ohos.app.ability.common';
import geoLocationManager from '@ohos.geoLocationManager';

const MICROPHONE_PERMISSION = 'ohos.permission.MICROPHONE' as Permissions;
const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION' as Permissions,
  'ohos.permission.LOCATION' as Permissions,
];

export default class HarmonyDevicePermissionPlugin
  implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;
  private readonly accessManager = abilityAccessCtrl.createAtManager();

  getUniqueClassName(): string {
    return 'HarmonyDevicePermissionPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'pixelplanner/harmony_device_permissions',
    );
    this.channel.setMethodCallHandler(this);
    this.context = binding.getApplicationContext();
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.context = null;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'requestMicrophonePermission') {
        result.success(await this.requestPermissions([MICROPHONE_PERMISSION]));
        return;
      }
      if (call.method === 'requestLocationPermission') {
        result.success(await this.requestPermissions(LOCATION_PERMISSIONS));
        return;
      }
      if (call.method === 'getCurrentLocation') {
        const granted = await this.requestPermissions(LOCATION_PERMISSIONS);
        if (!granted) {
          result.error('location_denied', 'Location permission was denied', null);
          return;
        }
        const location = await geoLocationManager.getCurrentLocation();
        result.success({
          latitude: location.latitude,
          longitude: location.longitude,
        });
        return;
      }
      result.notImplemented();
    } catch (error) {
      result.error('device_permission_error', 'Device permission operation failed', String(error));
    }
  }

  private async requestPermissions(permissions: Permissions[]): Promise<boolean> {
    if (this.context == null) {
      throw new Error('UI ability context is unavailable');
    }
    const response = await this.accessManager.requestPermissionsFromUser(
      this.context as common.UIAbilityContext,
      permissions,
    );
    return response.authResults.every((result) => result === 0);
  }
}
