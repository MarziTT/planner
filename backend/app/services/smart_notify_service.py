"""
Smart notification service — P3-F3.

Generates context-aware push notification insights based on pattern
detection results from the habits engine.  The Flutter client polls
the insights endpoint and schedules local notifications accordingly.

Notification insight types:
  - wake_deviation   —  user woke up significantly later/earlier than usual
  - standing_nudge   —  user has been skipping standing reminders
  - exercise_drop    —  exercise volume dropped vs previous week
  - meal_sync        —  meal timing pattern established, suggest scheduling
  - sleep_reminder   —  based on learned wake time, remind to sleep on time
"""

from __future__ import annotations

import logging
import hashlib
import json
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func

from ..extensions import db
from ..models_habits import (
    EventHistory,
    ExerciseRecord,
    MealRecord,
    NotifyPreference,
    UserPattern,
)
from .time_service import SHANGHAI_TZ, get_clock

logger = logging.getLogger(__name__)

TZ = SHANGHAI_TZ

# ── Insight priority thresholds ──────────────────────────────────────────
WAKE_DEVIATION_THRESHOLD_MINUTES = 30
EXERCISE_DROP_THRESHOLD = 0.3       # 30% drop triggers a nudge
STANDING_SKIP_STREAK_THRESHOLD = 3  # 3 consecutive skips → nudge


def generate_insights(user_id: int) -> dict[str, Any]:
    """Return a list of smart notification insights for *user_id*.

    Each insight contains:
      - insight_type: the category key
      - priority: 'high' | 'medium' | 'low'
      - title: short notification title
      - body: human-readable notification body
      - data: optional JSON payload for Flutter routing
    """
    patterns = _load_patterns(user_id)
    prefs = _load_preferences(user_id)
    now = get_clock().now_local()

    insights: list[dict[str, Any]] = []

    # 1. Wake time deviation check ─────────────────────────────────────────
    wake_insight = _check_wake_deviation(user_id, patterns, now)
    if wake_insight:
        insights.append(wake_insight)

    # 2. Standing skip streak nudge ────────────────────────────────────────
    standing_insight = _check_standing_nudge(user_id, patterns)
    if standing_insight:
        insights.append(standing_insight)

    # 3. Exercise volume drop ──────────────────────────────────────────────
    exercise_insight = _check_exercise_drop(user_id, now)
    if exercise_insight:
        insights.append(exercise_insight)

    # 4. Meal pattern sync ─────────────────────────────────────────────────
    meal_insights = _check_meal_sync(user_id, patterns, prefs, now)
    insights.extend(meal_insights)

    # 5. Sleep reminder ────────────────────────────────────────────────────
    sleep_insight = _check_sleep_reminder(user_id, patterns, prefs, now)
    if sleep_insight:
        insights.append(sleep_insight)

    # Sort by priority: high → medium → low
    priority_order = {"high": 0, "medium": 1, "low": 2}
    insights.sort(key=lambda i: priority_order.get(i.get("priority", "low"), 99))
    insights = [_with_presentation(insight, now) for insight in insights]

    return {
        "user_id": user_id,
        "generated_at": now.isoformat(),
        "count": len(insights),
        "insights": insights,
    }


def _with_presentation(insight: dict[str, Any], now: datetime) -> dict[str, Any]:
    """Attach a stable notification-bar/Live Activity presentation contract."""
    insight_type = str(insight.get("insight_type") or "general")
    priority = str(insight.get("priority") or "low")
    action_map = {
        "wake_deviation": {"label": "查看作息", "route": "/health", "action": "open_health"},
        "standing_nudge": {"label": "记录站立", "route": "/habits", "action": "log_standing"},
        "exercise_drop": {"label": "开始运动", "route": "/exercise", "action": "open_exercise"},
        "meal_sync": {"label": "记录餐食", "route": "/meals", "action": "log_meal"},
        "sleep_reminder": {"label": "查看睡眠", "route": "/health", "action": "open_sleep"},
    }
    action = action_map.get(insight_type, {"label": "打开管家", "route": "/agent", "action": "open_agent"})
    lifetime = 6 * 60 * 60 if priority == "high" else 2 * 60 * 60
    cooldown_minutes = {
        "wake_deviation": 12 * 60,
        "standing_nudge": 90,
        "exercise_drop": 24 * 60,
        "meal_sync": 12 * 60,
        "sleep_reminder": 12 * 60,
    }.get(insight_type, 120)
    identity_payload = {
        "type": insight_type,
        "data": insight.get("data") or {},
        "date": now.date().isoformat(),
    }
    dedupe_key = hashlib.sha256(
        json.dumps(identity_payload, ensure_ascii=False, sort_keys=True, default=str).encode("utf-8")
    ).hexdigest()[:24]
    decorated = dict(insight)
    decorated["dedupe_key"] = dedupe_key
    decorated["cooldown_minutes"] = cooldown_minutes
    decorated["presentation"] = {
        "surface": "notification_and_live_activity",
        "category": insight_type,
        "priority": priority,
        "compact_title": str(insight.get("title") or "Pixel Planner")[:32],
        "compact_body": str(insight.get("body") or "")[:80],
        "progress": None,
        "actions": [action],
        "route": action["route"],
        "expires_at": (now + timedelta(seconds=lifetime)).isoformat(),
        "ongoing": priority == "high",
        "dedupe_key": dedupe_key,
        "cooldown_minutes": cooldown_minutes,
    }
    return decorated


def get_notify_history(
    user_id: int,
    *,
    notify_type: str | None = None,
    days: int = 7,
    limit: int = 50,
) -> dict[str, Any]:
    """Return notification history entries for *user_id*."""
    cutoff = get_clock().now_local() - timedelta(days=days)

    q = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.created_at >= cutoff,
        )
    )
    if notify_type:
        q = q.filter(EventHistory.notify_type == notify_type)

    rows = (
        q.order_by(EventHistory.created_at.desc())
        .limit(limit)
        .all()
    )

    # Aggregate stats within the window
    total = len(rows)
    skipped = sum(1 for r in rows if r.skipped)
    completed = sum(1 for r in rows if r.completed_at is not None)

    return {
        "user_id": user_id,
        "total": total,
        "skipped": skipped,
        "completed": completed,
        "entries": [
            {
                "id": r.id,
                "event_id": r.event_id,
                "notify_type": r.notify_type,
                "planned_time": r.planned_time.isoformat() if r.planned_time else None,
                "reminded_at": r.reminded_at.isoformat() if r.reminded_at else None,
                "completed_at": r.completed_at.isoformat() if r.completed_at else None,
                "skipped": r.skipped,
                "delayed_count": r.delayed_count,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ],
    }


# ═══════════════════════════════════════════════════════════════════════════
#  Insight generators
# ═══════════════════════════════════════════════════════════════════════════

def _check_wake_deviation(
    user_id: int, patterns: dict[str, dict], now: datetime
) -> dict | None:
    """Detect if today's wake time deviates significantly from the learned pattern."""
    wake_pattern = patterns.get("wake_time", {}).get("default")
    if not wake_pattern or not wake_pattern.get("value"):
        return None

    val = wake_pattern["value"]
    expected_hour = val.get("hour")
    expected_minute = val.get("minute", 0)
    confidence = wake_pattern.get("confidence", 0)

    if expected_hour is None or confidence < 0.3:
        return None

    # Find today's actual wake time (earliest exercise record this morning)
    today_start = now.replace(hour=4, minute=0, second=0, microsecond=0)
    if now.hour < 4:
        today_start -= timedelta(days=1)
    today_end = now.replace(hour=11, minute=0, second=0, microsecond=0)

    earliest = (
        db.session.query(func.min(ExerciseRecord.recorded_at))
        .filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.recorded_at >= today_start,
            ExerciseRecord.recorded_at <= today_end,
        )
        .scalar()
    )

    if not earliest:
        return None

    actual_minutes = earliest.hour * 60 + earliest.minute
    expected_minutes = expected_hour * 60 + expected_minute
    deviation = actual_minutes - expected_minutes

    if abs(deviation) < WAKE_DEVIATION_THRESHOLD_MINUTES:
        return None

    if deviation > 0:
        title = "今天起床晚了哦 ☀️"
        body = f"比平时晚了约 {deviation} 分钟，要不要调整下日程？"
    else:
        deviation = abs(deviation)
        title = "今天起得真早！🌅"
        body = f"比平时早了 {deviation} 分钟，状态不错嘛"

    return {
        "insight_type": "wake_deviation",
        "priority": "medium",
        "title": title,
        "body": body,
        "data": {"expected_hour": expected_hour, "expected_minute": expected_minute,
                 "deviation_minutes": deviation},
    }


def _check_standing_nudge(
    user_id: int, patterns: dict[str, dict]
) -> dict | None:
    """Nudge if user has been skipping standing reminders repeatedly."""
    standing = patterns.get("standing_acceptance", {}).get("default")
    if not standing or not standing.get("value"):
        return None

    val = standing["value"]
    skip_rate = val.get("skip_rate", 0)
    total = val.get("total", 0)
    skipped = val.get("skipped", 0)

    if total < STANDING_SKIP_STREAK_THRESHOLD:
        return None

    # Check actual consecutive skips from EventHistory
    recent = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "standing",
        )
        .order_by(EventHistory.created_at.desc())
        .limit(STANDING_SKIP_STREAK_THRESHOLD)
        .all()
    )

    consecutive_skips = 0
    for entry in recent:
        if entry.skipped:
            consecutive_skips += 1
        else:
            break

    if consecutive_skips < STANDING_SKIP_STREAK_THRESHOLD:
        return None

    title = "该站起来动动了 🪑➡️🏃"
    body = f"已经连续 {consecutive_skips} 次跳过站立提醒了哦，久坐对身体不好"
    return {
        "insight_type": "standing_nudge",
        "priority": "medium",
        "title": title,
        "body": body,
        "data": {"consecutive_skips": consecutive_skips, "skip_rate": round(skip_rate, 2)},
    }


def _check_exercise_drop(user_id: int, now: datetime) -> dict | None:
    """Compare this week's exercise volume to last week."""
    this_week_start = now - timedelta(days=now.weekday())
    this_week_start = this_week_start.replace(hour=0, minute=0, second=0, microsecond=0)
    last_week_start = this_week_start - timedelta(days=7)
    last_week_end = this_week_start

    def _week_minutes(since: datetime, until: datetime) -> float:
        return (
            db.session.query(func.coalesce(func.sum(ExerciseRecord.duration_minutes), 0))
            .filter(
                ExerciseRecord.user_id == user_id,
                ExerciseRecord.recorded_at >= since,
                ExerciseRecord.recorded_at < until,
            )
            .scalar()
        )

    this_week = _week_minutes(this_week_start, now)
    last_week = _week_minutes(last_week_start, last_week_end)

    if this_week <= 0 or last_week <= 0:
        return None

    drop_ratio = (last_week - this_week) / last_week
    if drop_ratio < EXERCISE_DROP_THRESHOLD:
        return None

    pct = int(drop_ratio * 100)
    title = "运动量有点下降 📉"
    body = f"这周运动比上周少了约 {pct}%，今天要不要跑个步？"
    return {
        "insight_type": "exercise_drop",
        "priority": "medium",
        "title": title,
        "body": body,
        "data": {"this_week_minutes": int(this_week), "last_week_minutes": int(last_week),
                 "drop_pct": pct},
    }


def _check_meal_sync(
    user_id: int,
    patterns: dict[str, dict],
    prefs: dict[str, dict],
    now: datetime,
) -> list[dict]:
    """Suggest scheduling meal reminders based on learned meal times."""
    insights: list[dict] = []
    meal_map = {
        "breakfast": ("早餐", "🥐"),
        "lunch": ("午餐", "🍱"),
        "dinner": ("晚餐", "🍲"),
    }

    meal_patterns = patterns.get("meal_time", {})
    for meal_type, (label, emoji) in meal_map.items():
        pat = meal_patterns.get(meal_type)
        if not pat or not pat.get("value"):
            continue

        val = pat["value"]
        hour = val.get("hour")
        minute = val.get("minute", 0)
        confidence = pat.get("confidence", 0)

        if hour is None or confidence < 0.4:
            continue

        # Check if this meal type already has notifications enabled
        pref = prefs.get(meal_type)
        if pref and pref.get("enabled"):
            continue  # Already set up, skip

        time_str = f"{hour:02d}:{minute:02d}"
        title = f"{emoji} {label}时间到了"
        body = f"你一般在 {time_str} 左右吃{label}，要开启用餐提醒吗？"

        insights.append({
            "insight_type": "meal_sync",
            "priority": "low",
            "title": title,
            "body": body,
            "data": {"meal_type": meal_type, "suggested_hour": hour,
                     "suggested_minute": minute, "confidence": round(confidence, 2)},
        })

    return insights


def _check_sleep_reminder(
    user_id: int,
    patterns: dict[str, dict],
    prefs: dict[str, dict],
    now: datetime,
) -> dict | None:
    """Suggest a sleep reminder based on learned wake time."""
    wake_pattern = patterns.get("wake_time", {}).get("default")
    if not wake_pattern or not wake_pattern.get("value"):
        return None

    val = wake_pattern["value"]
    wake_hour = val.get("hour")
    wake_minute = val.get("minute", 0)
    confidence = wake_pattern.get("confidence", 0)

    if wake_hour is None or confidence < 0.4:
        return None

    # Recommended bedtime = wake_time - 8 hours - 30 min wind-down
    bed_hour = wake_hour - 8
    bed_minute = wake_minute - 30
    if bed_minute < 0:
        bed_hour -= 1
        bed_minute += 60
    if bed_hour < 0:
        bed_hour += 24

    # Only suggest in the evening
    if now.hour < 20 or now.hour > 23:
        return None

    # Check if already has sleep preference set
    pref = prefs.get("sleep")
    if pref and pref.get("enabled"):
        return None

    time_str = f"{bed_hour:02d}:{bed_minute:02d}"
    wake_str = f"{wake_hour:02d}:{wake_minute:02d}"

    return {
        "insight_type": "sleep_reminder",
        "priority": "low",
        "title": "🌙 该准备睡觉了",
        "body": f"你一般在 {wake_str} 起床，建议 {time_str} 前入睡保证 8 小时睡眠",
        "data": {"suggested_bed_hour": bed_hour, "suggested_bed_minute": bed_minute,
                 "wake_hour": wake_hour, "wake_minute": wake_minute},
    }


# ═══════════════════════════════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════════════════════════════

def _load_patterns(user_id: int) -> dict[str, dict[str, Any]]:
    """Load all patterns for *user_id* as {pattern_type: {pattern_key: pattern}}."""
    rows = UserPattern.query.filter_by(user_id=user_id).all()
    grouped: dict[str, dict[str, Any]] = {}
    for row in rows:
        inner = grouped.setdefault(row.pattern_type, {})
        inner[row.pattern_key] = {
            "value": row.pattern_value,
            "confidence": row.confidence,
            "sample_count": row.sample_count,
        }
    return grouped


def _load_preferences(user_id: int) -> dict[str, dict[str, Any]]:
    """Load notify preferences as {notify_type: {...}}."""
    rows = NotifyPreference.query.filter_by(user_id=user_id).all()
    return {
        r.notify_type: {
            "lead_minutes": r.lead_minutes,
            "enabled": r.enabled,
            "quiet_hours_start": r.quiet_hours_start,
            "quiet_hours_end": r.quiet_hours_end,
        }
        for r in rows
    }
