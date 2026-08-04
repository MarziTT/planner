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
  private readonly slotType = notificationManager.SlotType.SERVICE_INFORMATION;

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
      if (call.method === 'ensureChannel') {
        await notificationManager.addSlot(this.slotType);
        result.success(null);
      } else if (call.method === 'show') {
        const title = (call.argument('title') as string) ?? 'PixelPlanner';
        const body = (call.argument('body') as string) ?? '';
        const category = (call.argument('category') as string) ?? 'schedule';
        const notificationId = (call.argument('id') as number) ?? 0;
        const scheduledAt = (call.argument('scheduledAt') as number) ?? 0;
        const publishTime = scheduledAt > 0 ? scheduledAt : Date.now();
        const content: notificationManager.NotificationContent = {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: body,
            additionalText: category,
          },
        };
        const request: notificationManager.NotificationRequest = {
          id: notificationId,
          notificationSlotType: this.slotType,
          content: content,
          deliveryTime: publishTime,
          showDeliveryTime: true,
          tapDismissed: true,
          extraInfo: {
            payload: (call.argument('payload') as string) ?? '',
            channelId: (call.argument('channelId') as string) ?? '',
            priority: (call.argument('priority') as string) ?? '',
            category: category,
          },
        };
        await notificationManager.publish(request);
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
