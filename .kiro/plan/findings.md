# Findings

## 2026-08-02 takeover

- Device: HUAWEI Pura 70 Pro, HarmonyOS API 23.
- Build SDK: HarmonyOS API 24; minimum compatible SDK must remain API 12.
- Flutter host page resources were missing and caused a white screen. Added pages/Index and main_pages.json.
- GeneratedPluginRegistrant was empty. Custom secure-storage and notification bridges existed but were not registered.
- SharedPreferences currently uses an in-memory mock on OHOS, so settings are lost after process restart.
- Authentication had a temporary in-memory TokenStorage workaround; final native persistence is still required.
- Current third-party Flutter packages do not advertise OHOS implementations in .flutter-plugins-dependencies.
- Native bridges still required or must be replaced for TTS, speech input, recording, path provider, URL launching, sharing, image selection, and connectivity-dependent workflows.
- D-drive Hvigor automatic signing cannot decrypt plain passwords and looks for .ohos/config/material. Current reproducible workaround is package unsigned then sign with hap-sign-tool.jar.
- Existing docs identify router recreation and login input loss as app-level P1 issues.
- Source tree is dirty with user/previous-agent edits; preserve and reconcile them before committing.
- The clean persistence integration point is SharedPreferencesStorePlatform. Register an OHOS implementation before SharedPreferences.getInstance(), backed by the existing ArkTS Preferences plugin.
- Flutter regenerates GeneratedPluginRegistrant.ets during OHOS builds, so project-owned plugins must be added from EntryAbility.ets unless they are formal OHOS plugin packages.
- appRouterProvider currently watches the full AuthState and recreates GoRouter on every auth state change, which explains login form state loss.
- voice_output_service uses a dart.library.ohos conditional import that is false in this SDK; reminder and notification code also uses the same invalid platform check.
- HarmonyNotificationPlugin still has strict ArkTS typing/API issues and is intentionally not registered yet, so notification native delivery remains a separate follow-up.
- The fastest workflow is: edit on G drive, sync to D drive when needed, use tools/ohos_flutter_run.ps1 for Dart/UI hot reload, and rebuild HAP only after native OHOS/signing/manifest changes.
- The local DevEco SDK exposes `notificationManager.addSlot(SlotType)` and uses `notificationSlotType` / `notificationContentType`; the former plugin used obsolete object and property shapes.
- The app logs show custom secure-storage and notification channels registered successfully. The remaining `com.pixelplanner.widget` Android-only bridge reports method-not-implemented on OHOS and should become a no-op or receive a native bridge in a later compatibility pass.
- `pumpAndSettle` is unsuitable for notification navigation tests while dashboard loading indicators are active; fixed-duration pumps keep those tests deterministic.
# Harmony Health native bridge — 2026-08-03

- Existing Flutter contract uses `pixelplanner/harmony_health` with methods
  `isAvailable`, `authorizationStatus`, `requestAuthorization`, and
  `readBodyMeasurements`.
- The original scope is Huawei Health scale/body-composition data; this can be
  extended only after verifying the installed Harmony Health Service Kit APIs.
- Required native implementation location is
  `mobile_app/ohos/entry/src/main/ets/plugins/HarmonyHealthPlugin.ets`, then
  registration from `EntryAbility.ets`.
- The installed Harmony SDK exposes the native `@hms.health.store` APIs through
  `@kit.HealthServiceKit`; native calls include `requestAuthorizations`,
  `getAuthorizations`, and `readData`.
- `EntryAbility` already uses the correct manual registration pattern for
  custom ArkTS plugins, so the health bridge can follow the notification and
  secure-storage plugins without touching generated files.
- Health Store reads use epoch milliseconds (`startTime`, `endTime`) and return
  `SamplePoint` records with source timestamps. Authorization accepts typed
  `readDataTypes`, including the official `WEIGHT` data type.
- `WEIGHT` is a rich measurement record: it includes required `bodyWeight`
  plus optional body-composition metrics, so one official permission and read
  query can satisfy the original scale-data contract.
- Existing `ExercisePage` shows a backend summary plus an `AutoTracker` step
  stream. The bridge should augment this UI with a native Health data card and
  must not overwrite manual/backend exercise records.
- The installed API is supplied by the system bundles
  `com.huawei.hmos.health.kit/HealthStore` and `HealthService`, SDK version
  `5.0.0(12)`. Native availability must therefore also tolerate phones where
  these bundles or the user’s Huawei account are unavailable.
- Workout history uses `healthStore.readData` with an
  `ExerciseSequenceReadRequest` (`exerciseType: null` returns all available
  workout types); step totals are available in exercise sequence summaries.

## 2026-08-05 agent confirmation follow-up

- Chat text is classified by `backend/app/services/agent.py` before Flutter's
  fast-capture parser runs. The backend now prefers the configured AI model and
  retains regex only as a fallback.
- The chat confirmation card currently exposes only confirmation; it needs
  explicit cancel and edit actions before a schedule is created.
- `origin` is configured as `https://github.com/MarziTT/planner.git`; pushing
  the backend change is required to trigger the deployment pipeline.
