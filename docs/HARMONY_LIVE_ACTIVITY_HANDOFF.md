# Harmony Notification Bar / Live Activity Handoff

The backend `GET /api/v1/notify/insights` response now includes a stable
`presentation` object for every smart-butler insight.

Example:

```json
{
  "surface": "notification_and_live_activity",
  "category": "exercise_drop",
  "priority": "medium",
  "compact_title": "运动量下降",
  "compact_body": "这周运动少了很多",
  "progress": null,
  "actions": [
    {"label": "开始运动", "route": "/exercise", "action": "open_exercise"}
  ],
  "route": "/exercise",
  "expires_at": "2026-07-31T12:00:00+08:00",
  "ongoing": false
}
```

Each insight also contains `dedupe_key` and `cooldown_minutes`. Persist the last
display time per key locally. Do not display the same key again until its
cooldown expires, even if the polling endpoint returns it repeatedly.

The HarmonyOS/debugging Codex should map this protocol to the best currently
available official HarmonyOS notification and Live View/Live Activity API.
Do not hard-code category-specific text in ArkTS; the backend owns content and
actions.

Required behavior:

1. Use `compact_title` and `compact_body` for compact surfaces.
2. Use the original insight `title` and `body` for expanded notifications.
3. Do not display after `expires_at`.
4. Use `ongoing` only where the official API supports persistent presentation.
5. Tapping the surface opens `route` through the existing Flutter navigation.
6. Map action identifiers to Flutter callbacks; unknown actions open `/agent`.
7. For non-high-priority insights, expose `snooze` (30 minutes) and
   `dismiss_today` actions. Persist these decisions locally and suppress the
   matching `dedupe_key` until the snooze/daily expiry.
8. Deduplicate using the backend-provided `dedupe_key` and
   `cooldown_minutes`; do not invent a separate client hash.
9. Respect notification permission, quiet hours, and user preference settings.
10. If Live View is unavailable, fall back to an ordinary notification without
   losing the action or route.

Initial categories:

- `wake_deviation` → health/routine
- `standing_nudge` → standing completion
- `exercise_drop` → exercise page
- `meal_sync` → meal logging
- `sleep_reminder` → sleep/health page

Report the exact HarmonyOS API/version used, device limitations, and one
redacted screenshot or payload after real-device verification.
