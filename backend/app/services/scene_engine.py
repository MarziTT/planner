"""
Scene intelligence engine — PixelPlanner P6.

Proactive butler: analyzes user state across all domains (weather, exercise,
meals, schedule, routine) and generates contextual suggestions before the user
even asks.

Scene trigger types:
  - weather_warning  — bad weather today → suggest leaving early
  - exercise_nudge   — exercise goal not met by afternoon → suggest a walk
  - meal_reminder    — no dinner logged by evening → reminder to eat
  - conflict_alert   — schedule conflict between events → suggest alternatives
  - wake_adjust      — woke up late → adjust morning schedule
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func

from ..extensions import db
from ..models import Event, Todo
from ..models_habits import EventHistory, ExerciseRecord, MealRecord, UserPattern

logger = logging.getLogger(__name__)

TZ = timezone(timedelta(hours=8))

# ── Scene priority ───────────────────────────────────────────────────────
PRIORITY_HIGH = "high"
PRIORITY_MEDIUM = "medium"
PRIORITY_LOW = "low"

# ── Scene types ──────────────────────────────────────────────────────────
SCENE_WEATHER = "weather_warning"
SCENE_EXERCISE = "exercise_nudge"
SCENE_MEAL = "meal_reminder"
SCENE_CONFLICT = "conflict_alert"
SCENE_WAKE = "wake_adjust"

# ── Thresholds ───────────────────────────────────────────────────────────
DINNER_CHECK_HOUR = 19       # Check if dinner logged by 7 PM
EXERCISE_CHECK_HOUR = 16     # Check if exercise done by 4 PM
EXERCISE_MIN_MINUTES = 20    # Minimum daily exercise
WAKE_DEVIATION_MINUTES = 45  # Wake deviation triggering adjustment


def check_scenes(user_id: int, weather_text: str | None = None) -> list[dict[str, Any]]:
    """Analyze user state and return active scene cards.

    Args:
        user_id: Target user ID.
        weather_text: Optional weather description (e.g. "中雨，15°C-22°C").
                      If None, weather_warning scene is skipped.

    Returns:
        List of scene cards sorted by priority (high → medium → low).
    """
    cards: list[dict[str, Any]] = []

    now = datetime.now(TZ)
    today = now.date()
    today_start = datetime.combine(today, datetime.min.time(), tzinfo=TZ)
    today_end = today_start + timedelta(days=1)

    # ── Weather warning ──────────────────────────────────────────────────
    if weather_text:
        card = _check_weather(user_id, weather_text, now)
        if card:
            cards.append(card)

    # ── Exercise nudge ───────────────────────────────────────────────────
    if now.hour >= EXERCISE_CHECK_HOUR:
        card = _check_exercise(user_id, today_start, today_end, now)
        if card:
            cards.append(card)

    # ── Meal reminder ────────────────────────────────────────────────────
    if now.hour >= DINNER_CHECK_HOUR:
        card = _check_dinner(user_id, today_start, today_end, now)
        if card:
            cards.append(card)

    # ── Schedule conflict ────────────────────────────────────────────────
    card = _check_conflicts(user_id, today_start, today_end)
    if card:
        cards.append(card)

    # ── Wake adjustment ──────────────────────────────────────────────────
    if now.hour < 12:
        card = _check_wake(user_id, today_start, now)
        if card:
            cards.append(card)

    # Sort by priority: high > medium > low
    priority_order = {PRIORITY_HIGH: 0, PRIORITY_MEDIUM: 1, PRIORITY_LOW: 2}
    cards.sort(key=lambda c: priority_order.get(c.get("priority", "low"), 99))

    return cards


# ── Individual scene checkers ────────────────────────────────────────────

def _check_weather(
    user_id: int, weather_text: str, now: datetime
) -> dict[str, Any] | None:
    """Check if weather is bad enough to warrant a warning."""
    bad_keywords = ["雨", "雪", "暴", "霾", "雾", "台风", "大风", "冰雹", "沙尘"]
    is_bad = any(kw in weather_text for kw in bad_keywords)

    if not is_bad:
        return None

    # Find next upcoming event
    next_event = (
        Event.query
        .filter(
            Event.user_id == user_id,
            Event.starts_at >= now,
            Event.starts_at <= now + timedelta(hours=24),
        )
        .order_by(Event.starts_at.asc())
        .first()
    )

    suggestion = "建议提前10-15分钟出门，注意安全"
    if next_event and next_event.starts_at:
        leave_time = next_event.starts_at - timedelta(minutes=30)
        suggestion = f"下一个日程在 {next_event.starts_at.strftime('%H:%M')}，建议提前出发"

    return {
        "type": SCENE_WEATHER,
        "priority": PRIORITY_HIGH,
        "icon": "🌧",
        "title": f"今日天气：{weather_text[:12]}",
        "body": suggestion,
        "action_label": "查看日程",
        "action_type": "open_schedule",
    }


def _check_exercise(
    user_id: int, today_start: datetime, today_end: datetime, now: datetime
) -> dict[str, Any] | None:
    """Check if user needs an exercise nudge."""
    # Get today's exercise total
    result = (
        db.session.query(func.coalesce(func.sum(ExerciseRecord.duration_minutes), 0))
        .filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.completed_at >= today_start,
            ExerciseRecord.completed_at < today_end,
        )
        .scalar()
    )
    total_minutes = result if result else 0

    if total_minutes >= EXERCISE_MIN_MINUTES:
        return None

    if total_minutes == 0:
        return {
            "type": SCENE_EXERCISE,
            "priority": PRIORITY_MEDIUM,
            "icon": "🏃",
            "title": "今天还没有运动哦",
            "body": "快走15分钟或做几个拉伸，保持活力！",
            "action_label": "去运动",
            "action_type": "open_exercise",
        }

    remaining = EXERCISE_MIN_MINUTES - total_minutes
    return {
        "type": SCENE_EXERCISE,
        "priority": PRIORITY_LOW,
        "icon": "🚶",
        "title": f"还差{remaining}分钟完成运动目标",
        "body": "完成一个小目标，散个步就够了！",
        "action_label": "继续运动",
        "action_type": "open_exercise",
    }


def _check_dinner(
    user_id: int, today_start: datetime, today_end: datetime, now: datetime
) -> dict[str, Any] | None:
    """Check if dinner has been logged yet."""
    if now.hour < DINNER_CHECK_HOUR:
        return None

    dinner = (
        MealRecord.query
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= today_start,
            MealRecord.recorded_at < today_end,
            MealRecord.meal_type == "晚餐",
        )
        .first()
    )

    if dinner is not None:
        return None

    # Check total meals today
    total_meals = (
        db.session.query(func.count(MealRecord.id))
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= today_start,
            MealRecord.recorded_at < today_end,
        )
        .scalar()
    )

    if total_meals and total_meals >= 3:
        return None  # Already had enough meals

    time_str = now.strftime("%H:%M")
    if now.hour >= 21:
        return {
            "type": SCENE_MEAL,
            "priority": PRIORITY_HIGH,
            "icon": "🍽",
            "title": f"已经{time_str}了，还没吃晚饭？",
            "body": "记得吃点东西，饿着肚子睡觉不好哦",
            "action_label": "记录餐食",
            "action_type": "open_meals",
        }

    return {
        "type": SCENE_MEAL,
        "priority": PRIORITY_MEDIUM,
        "icon": "🍽",
        "title": "别忘了记录晚餐",
        "body": "记录一下今晚吃了什么吧",
        "action_label": "记录餐食",
        "action_type": "open_meals",
    }


def _check_conflicts(
    user_id: int, today_start: datetime, today_end: datetime
) -> dict[str, Any] | None:
    """Check for schedule conflicts in today's events."""
    events = (
        Event.query
        .filter(
            Event.user_id == user_id,
            Event.starts_at >= today_start,
            Event.starts_at < today_end,
        )
        .order_by(Event.starts_at.asc())
        .all()
    )

    if len(events) < 2:
        return None

    # Check for overlapping events
    for i in range(len(events) - 1):
        a = events[i]
        b = events[i + 1]
        if a.ends_at and b.starts_at and a.ends_at > b.starts_at:
            return {
                "type": SCENE_CONFLICT,
                "priority": PRIORITY_HIGH,
                "icon": "⚠",
                "title": "日程时间冲突",
                "body": f"「{a.title}」和「{b.title}」时间重叠，建议调整其中一个",
                "action_label": "查看日程",
                "action_type": "open_schedule",
            }

    return None


def _check_wake(
    user_id: int, today_start: datetime, now: datetime
) -> dict[str, Any] | None:
    """Check if user woke up late and adjust morning suggestions."""
    pattern = (
        UserPattern.query
        .filter(UserPattern.user_id == user_id)
        .first()
    )

    if not pattern or not pattern.wake_time:
        return None

    try:
        parts = pattern.wake_time.strip().split(":")
        expected_hour = int(parts[0])
        expected_minute = int(parts[1]) if len(parts) > 1 else 0
    except (ValueError, IndexError):
        return None

    expected = expected_hour * 60 + expected_minute
    actual = now.hour * 60 + now.minute

    deviation = actual - expected
    if deviation < WAKE_DEVIATION_MINUTES:
        return None

    # Check if there are morning events affected
    morning_cutoff = datetime.combine(
        now.date(),
        datetime.min.time().replace(hour=10),
        tzinfo=TZ,
    )
    morning_events = (
        Event.query
        .filter(
            Event.user_id == user_id,
            Event.starts_at >= today_start,
            Event.starts_at <= morning_cutoff,
        )
        .count()
    )

    if morning_events > 0:
        return {
            "type": SCENE_WAKE,
            "priority": PRIORITY_HIGH,
            "icon": "⏰",
            "title": "今天起得比平时晚",
            "body": f"你有{morning_events}个上午的日程，可能需要调整一下",
            "action_label": "查看日程",
            "action_type": "open_schedule",
        }

    return {
        "type": SCENE_WAKE,
        "priority": PRIORITY_LOW,
        "icon": "☕",
        "title": "今天起得比平时晚呢",
        "body": "慢慢来，喝杯咖啡再开始一天吧",
        "action_label": "好的",
        "action_type": "dismiss",
    }
