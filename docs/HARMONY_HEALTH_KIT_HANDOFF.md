# Harmony Health Kit Integration Handoff

## Goal

Connect Pixel Planner to body-composition records already synchronized from a
Huawei scale into Huawei Health. This task is for the Codex responsible for
HarmonyOS setup, native SDK integration, signing, device authorization, build,
and debugging.

Flutter business code is already committed in `33e11dc`. Do not redesign its
channel contract unless an actual Health Kit API limitation requires it.

## Existing Flutter Contract

- Channel: `pixelplanner/harmony_health`
- Client: `mobile_app/lib/features/health/data/harmony_health_service.dart`
- Model: `mobile_app/lib/features/health/domain/body_measurement.dart`

Implement and register an ArkTS Flutter plugin under:

`mobile_app/ohos/entry/src/main/ets/plugins/HarmonyHealthPlugin.ets`

Register it using the same mechanism as the existing secure-storage and
notification plugins. Avoid editing generated registration code manually if the
current Flutter OHOS tool can generate it reliably.

## Required Native Methods

### `isAvailable`

Return `true` only when the Health Kit service and required APIs are usable on
the current device. Return `false` for unsupported devices or missing services.

### `authorizationStatus`

Return one of these strings:

- `authorized`
- `denied`
- `notDetermined`

The status must cover read access for weight. Optional body-composition fields
may remain absent when Huawei does not grant them.

### `requestAuthorization`

Arguments:

```json
{
  "dataTypes": [
    "weight",
    "bmi",
    "bodyFat",
    "muscleMass",
    "bodyWater",
    "basalMetabolicRate",
    "visceralFat"
  ]
}
```

Map only supported names to official Huawei Health Kit read permissions. Weight
is mandatory; unsupported optional types must not make the entire request fail.
Return `true` when weight access is granted.

### `readBodyMeasurements`

Arguments contain UTC ISO-8601 strings:

```json
{
  "startTime": "2026-07-01T00:00:00.000Z",
  "endTime": "2026-08-01T00:00:00.000Z"
}
```

Return a list with this stable shape:

```json
[
  {
    "measuredAt": "2026-07-31T07:35:12+08:00",
    "weightKg": 71.5,
    "bmi": 22.1,
    "bodyFatPercent": 18.2,
    "muscleMassKg": 54.3,
    "bodyWaterPercent": 56.8,
    "basalMetabolicRate": 1580,
    "visceralFatLevel": 7,
    "source": "huawei_health"
  }
]
```

Only `measuredAt` and `weightKg` are required. Omit unavailable optional fields;
do not return zero as a substitute for missing data. Normalize weight to kg and
percentages to the human-readable percentage value (for example `18.2`, not
`0.182`). Deduplicate records with the same source timestamp and measurement.

## Huawei Developer Setup

1. Confirm whether the target uses HarmonyOS Health Service Kit, Huawei Health
   Kit, or the currently supported replacement for this device/SDK version.
2. Enable the health service for the application in Huawei Developer Console.
3. Apply for read permissions for weight and each available body-composition
   data type. Record which types require review or are unavailable.
4. Add the official OHOS package dependency using the vendor documentation for
   the installed SDK version.
5. Add only official permissions required by that SDK to `module.json5`.
6. Use the application's existing signing identity; do not commit private keys,
   certificates, access tokens, account identifiers, or local SDK paths.

## Device Verification

Use the Huawei phone/account that already shows scale records in Huawei Health.

Acceptance criteria:

1. First call reports `notDetermined` before authorization where supported.
2. Authorization UI is shown and clearly identifies the requested health data.
3. Denial returns `denied` and does not crash the Flutter app.
4. After approval, at least the latest scale weight is returned in kg.
5. Timestamp matches the record shown in Huawei Health, including timezone.
6. Any available BMI/body-fat fields match Huawei Health within rounding error.
7. Revoking permission makes subsequent reads fail safely or return denied.
8. Android behavior is unchanged; missing OHOS plugin remains a safe fallback.

## Deliverables for the Development Codex

When finished, report:

- exact Health Kit package and version used;
- permissions approved and permissions unavailable;
- one redacted sample payload from a real device;
- any changes required to the Flutter channel contract;
- known limitations, especially whether Huawei Health permits third-party access
  to scale body-composition records rather than only weight.

Keep native integration, build-system changes, and device-debugging changes in a
separate Git commit so they do not become mixed with Flutter business features.
