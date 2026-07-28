import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import notificationManager from '@ohos.notificationManager';

export default class HarmonyNotificationPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'HarmonyNotificationPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'pixelplanner/harmony_notifications',
    );
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const args = (call.arguments ?? {}) as Record<string, Object>;
      if (call.method === 'ensureChannel') {
        await notificationManager.addSlot({
          type: notificationManager.SlotType.SERVICE_INFORMATION,
          name: String(args['name'] ?? 'PixelPlanner'),
        });
        result.success(null);
      } else if (call.method === 'show') {
        const content = {
          contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: String(args['title'] ?? 'PixelPlanner'),
            text: String(args['body'] ?? ''),
            additionalText: String(args['category'] ?? 'schedule'),
          },
        };
        await notificationManager.publish({
          id: Number(args['id'] ?? 0),
          slotType: notificationManager.SlotType.SERVICE_INFORMATION,
          content,
        });
        result.success(null);
      } else if (call.method === 'cancelAll') {
        await notificationManager.cancelAll();
        result.success(null);
      } else {
        result.notImplemented();
      }
    } catch (error) {
      result.error('notification_error', 'Notification operation failed', String(error));
    }
  }
}
