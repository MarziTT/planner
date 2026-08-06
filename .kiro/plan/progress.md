# Progress

## 2026-08-02

- Restored project context from CODEX handoff documents.
- Confirmed build, signing, wireless install, and device logging toolchain.
- Diagnosed and fixed missing Flutter OHOS host page resources.
- Confirmed the app now renders instead of showing a white screen.
- Started registering custom secure-storage and notification plugins in GeneratedPluginRegistrant.
- Began full project ownership pass; next action is reconcile current diffs and replace temporary workarounds.
- Reconciled temporary workarounds: MemoryTokenStorage, mock SharedPreferences, and static login fields must be removed.
- Selected SharedPreferencesStorePlatform plus ArkTS Preferences as the project-wide OHOS persistence solution.
- Implemented the OHOS SharedPreferences platform backend and restored HarmonyTokenStorage.
- Made GoRouter stable across AuthState changes and removed static login form workarounds.
- Replaced invalid dart.library.ohos branches for voice and notifications with runtime OHOS detection.
- Moved OHOS custom plugin registration into EntryAbility.ets because GeneratedPluginRegistrant.ets is regenerated during builds.
- Fixed ArkTS compile errors in HarmonySecureStoragePlugin and registered only the secure storage/preferences bridge from EntryAbility.
- Rebuilt and installed D-drive debug HAP successfully; device logs now show the harmony secure storage channel handler is registered.
- Added tools/ohos_flutter_run.ps1 for online Flutter debugging and hot reload from the D-drive build copy.
- Repaired and registered the HarmonyNotificationPlugin against the installed DevEco SDK API; D-drive HAP build and device installation now succeed with the notification channel registered.
- Changed the mobile main experience to a chat-first command center. Existing dashboard, transit, meals, exercise, tags, profile, and settings pages now open as on-demand module sheets.
- Removed the chat-home floating module action because it overlapped the send control; modules remain reachable from the app bar and chat header.
- Updated notification navigation tests for the new module-sheet behavior. Targeted notification and lifecycle widget tests pass.

## 2026-08-04 continuation

- Another Codex has active uncommitted work for OHOS persistent storage, notification/health bridges, stable routing, and chat-first home integration.
- Preserved all active changes; no reset or overwrite performed.
- Full test commands from the previous session did not return usable output; rerunning them individually.

## Automated validation results

- Dart analyzer: completed with no compile errors; 106 warnings/info findings.
- Backend pytest with `D:\python`: 238 passed, 2 failed, 2 setup errors.
- Failed tests: `test_vision_capability_prefers_vision_models`, `test_auth_failure_skips_remaining_models_on_same_provider`.
- Setup errors: two update-resource tests could not create the Windows pytest temp directory due to permission denial.
- Backend warning: Flask-Limiter uses in-memory storage.

## 2026-08-05 agent confirmation follow-up

- Confirmed the D-drive app copy previously lagged behind G-drive source.
- Switched backend multi-intent classification to prefer the configured AI
  model, with regex fallback retained for outages and offline development.
- Verified `backend/tests/test_agent.py`: 43 tests passed.
- Next: add chat confirmation-card edit/cancel controls, validate, then commit
  and push all current reviewed source changes to trigger backend deployment.
- Added chat confirmation-card actions for pending schedules: edit title/start/
  end time, then confirm; or cancel without creating an event.
- Backend agent tests: 43 passed. Flutter fast-capture tests: 16 passed.
- Targeted Flutter analysis could not complete because the USB-source checkout
  has a locked `ios/Flutter/ephemeral/Packages/.packages` path; `dart format`
  successfully parsed all changed chat files.
- Added backend `llm_warning` propagation so AI connection failures surface as
  chat notices instead of silently falling back.
- Verified `backend/tests/test_agent.py` and Flutter static analysis for the
  changed agent files; committed and pushed the fix to `main`.

## 2026-08-05 butler tone and agent memory

- Renamed the independent tone setting from weather-specific naming to
  `butler_tone`; retained `/settings/weather-tone` as a compatibility alias.
- Removed user-visible “天气管家” labels from the weather feature; weather is
  now presented simply as weather.
- Added AI persona instructions to the multi-intent prompt so the configured
  butler identity/style is present when DeepSeek or another model is used.
- Added `agent_experiences` to store per-user language examples and perform
  offline similar-expression intent matching before calling the AI provider.
- Verified backend persona/settings/agent tests: 55 passed. Verified Flutter
  settings/weather static analysis: no issues.

## 2026-08-05 health center production repair

- Captured the connected HarmonyOS device UI state and confirmed the health
  center was displaying a Dio HTTP 500 response.
- Queried Railway HTTP and application logs; the root cause was the production
  `user_patterns` table missing the model's legacy `wake_time` column.
- Added Alembic migration `d4e5f6a7b8c9` and startup schema repair in
  `create_app(repair_tables=True)`, because the Railway Procfile runs
  `ensure_tables.py` rather than Alembic upgrades.
- Pushed `4ee1de0` and `9e6e0d6` to `main`; Railway deployment
  `2ae3c171-0b04-42a2-85ef-6f8f8d2620ae` logged the column repair.
- Triggered the phone's health-page retry and verified Railway returned
  `GET /api/v1/dashboard/health` with HTTP 200.

## 2026-08-06 Harmony health compile fix

- Fixed `HarmonyHealthPlugin.ets` ArkTS strict-mode errors by replacing
  untyped object maps and `Record<string, unknown>` payloads with explicit
  interfaces and typed resolver logic.
- Synced the fixed health plugin from `G:\PixelPlanner` to
  `D:\PixelPlannerBuild\mobile_app` for the active DevEco build copy.
- Diagnosed phone login failure for `13800000001` / `888888`: production
  config intentionally disabled the test-only backdoor credentials.
- Added an explicit `ENABLE_DEMO_LOGIN` / `DEMO_LOGIN_PHONE` /
  `DEMO_LOGIN_CODE` path for production demo login, defaulting off.
