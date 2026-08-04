import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import type common from '@ohos.app.ability.common';
import { healthService, healthStore } from '@kit.HealthServiceKit';

const REQUESTABLE_DATA_TYPES: Record<string, healthStore.DataType> = {
  weight: healthStore.healthDataTypes.WEIGHT,
  bmi: healthStore.healthDataTypes.WEIGHT,
  bodyFat: healthStore.healthDataTypes.WEIGHT,
  muscleMass: healthStore.healthDataTypes.WEIGHT,
  bodyWater: healthStore.healthDataTypes.WEIGHT,
  basalMetabolicRate: healthStore.healthDataTypes.WEIGHT,
  visceralFat: healthStore.healthDataTypes.WEIGHT,
  dailyActivities: healthStore.healthDataTypes.DAILY_ACTIVITIES,
  workout: healthStore.healthDataTypes.WORKOUT,
};

export default class HarmonyHealthPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;
  private initialized = false;

  getUniqueClassName(): string {
    return 'HarmonyHealthPlugin';
  }

  async onAttachedToEngine(binding: FlutterPluginBinding): Promise<void> {
    this.channel = new MethodChannel(
      binding.getBinaryMessenger(),
      'pixelplanner/harmony_health',
    );
    this.channel.setMethodCallHandler(this);
    this.context = binding.getApplicationContext();
    try {
      await healthStore.init(this.context);
      this.initialized = true;
    } catch (_) {
      this.initialized = false;
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.context = null;
    this.initialized = false;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'isAvailable') {
        result.success(await this.isAvailable());
        return;
      }

      if (call.method === 'authorizationStatus') {
        result.success(await this.authorizationStatus());
        return;
      }

      if (call.method === 'requestAuthorization') {
        result.success(await this.requestAuthorization(call));
        return;
      }

      if (call.method === 'requestActivityAuthorization') {
        result.success(await this.requestActivityAuthorization(call));
        return;
      }

      if (call.method === 'readBodyMeasurements') {
        result.success(await this.readBodyMeasurements(call));
        return;
      }

      if (call.method === 'readTodayActivityReport') {
        result.success(await this.readTodayActivityReport());
        return;
      }

      result.notImplemented();
    } catch (error) {
      result.error('health_error', 'Health operation failed', String(error));
    }
  }

  private async isAvailable(): Promise<boolean> {
    return this.initialized;
  }

  private async authorizationStatus(): Promise<string> {
    const request = this.buildAuthorizationRequest([
      'weight',
    ]);
    try {
      const response = await healthStore.getAuthorizations(request);
      return response.readDataTypes.includes(healthStore.healthDataTypes.WEIGHT)
        ? 'authorized'
        : response.readDataTypes.length > 0
          ? 'denied'
          : 'notDetermined';
    } catch (error) {
      return 'notDetermined';
    }
  }

  private async requestAuthorization(call: MethodCall): Promise<boolean> {
    const types = this.extractTypes(call);
    const request = this.buildAuthorizationRequest(types);
    const response = await this.requestAuthorizations(request);
    return response.readDataTypes.includes(healthStore.healthDataTypes.WEIGHT);
  }

  private async requestActivityAuthorization(call: MethodCall): Promise<boolean> {
    const types = this.extractTypes(call);
    const request = this.buildAuthorizationRequest(types);
    const response = await this.requestAuthorizations(request);
    return response.readDataTypes.includes(healthStore.healthDataTypes.DAILY_ACTIVITIES);
  }

  private async requestAuthorizations(
    request: healthStore.AuthorizationRequest,
  ): Promise<healthStore.AuthorizationResponse> {
    if (this.context == null) {
      throw new Error('Health context is unavailable');
    }
    return healthStore.requestAuthorizations(
      this.context as common.UIAbilityContext,
      request,
    );
  }

  private extractTypes(call: MethodCall): Array<string> {
    const rawTypes = call.argument('dataTypes') as Array<string> | undefined;
    return rawTypes ?? [];
  }

  private buildAuthorizationRequest(
    requestedTypes: Array<string>,
  ): healthStore.AuthorizationRequest {
    const readDataTypes: Array<healthStore.DataType> = [];
    for (const requestedType of requestedTypes) {
      const dataType = REQUESTABLE_DATA_TYPES[requestedType];
      if (dataType != null && !readDataTypes.includes(dataType)) {
        readDataTypes.push(dataType);
      }
    }
    return {
      readDataTypes,
      writeDataTypes: [],
      scopes: [],
    };
  }

  private async readBodyMeasurements(call: MethodCall): Promise<Array<Record<string, unknown>>> {
    const startTime = Date.parse(call.argument('startTime') as string);
    const endTime = Date.parse(call.argument('endTime') as string);
    const request: healthStore.SamplePointReadRequest<healthStore.healthFields.Weight> = {
      samplePointDataType: healthStore.healthDataTypes.WEIGHT,
      startTime,
      endTime,
    };
    const records = await healthStore.readData<healthStore.healthModels.Weight>(request);
    const deduplicated = new Map<string, Record<string, unknown>>();
    for (const record of records) {
      const measuredAt = this.formatMeasuredAt(record.startTime, record.timeZone);
      const payload = this.mapWeightRecord(record, measuredAt);
      const key = JSON.stringify(payload);
      if (!deduplicated.has(key)) {
        deduplicated.set(key, payload);
      }
    }
    return Array.from(deduplicated.values()).sort((left, right) => {
      return String(right.measuredAt).localeCompare(String(left.measuredAt));
    });
  }

  private async readTodayActivityReport(): Promise<Record<string, unknown> | null> {
    const report = await healthService.workout.readActivityReport();
    return {
      steps: report.steps,
      stepsGoal: report.stepsGoal ?? null,
      activeCalories: report.activeCalories,
      activeCaloriesGoal: report.activeCaloriesGoal ?? null,
      exerciseMinutes: report.exercise,
      exerciseGoalMinutes: report.exerciseGoal ?? null,
      activeHours: report.activeHours,
      activeHoursGoal: report.activeHoursGoal ?? null,
      source: 'huawei_health',
    };
  }

  private mapWeightRecord(
    record: healthStore.healthModels.Weight,
    measuredAt: string,
  ): Record<string, unknown> {
    return {
      measuredAt,
      weightKg: record.fields.bodyWeight,
      bmi: record.fields.bmi ?? null,
      bodyFatPercent: record.fields.bodyFatRate ?? null,
      muscleMassKg: record.fields.muscleMass ?? null,
      bodyWaterPercent: record.fields.moistureRate ?? null,
      basalMetabolicRate: record.fields.basalMetabolism ?? null,
      visceralFatLevel: record.fields.visceralFatLevel ?? null,
      source: 'huawei_health',
    };
  }

  private formatMeasuredAt(timeMillis: number, timeZone: string): string {
    const sign = timeZone.startsWith('-') ? -1 : 1;
    const hours = Number.parseInt(timeZone.slice(1, 3), 10) || 0;
    const minutes = Number.parseInt(timeZone.slice(3, 5), 10) || 0;
    const offsetMinutes = sign * (hours * 60 + minutes);
    const utcMillis = timeMillis + offsetMinutes * 60 * 1000;
    const date = new Date(utcMillis);
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    const hour = String(date.getUTCHours()).padStart(2, '0');
    const minute = String(date.getUTCMinutes()).padStart(2, '0');
    const second = String(date.getUTCSeconds()).padStart(2, '0');
    return `${year}-${month}-${day}T${hour}:${minute}:${second}${timeZone.slice(0, 3)}:${timeZone.slice(3, 5)}`;
  }
}
