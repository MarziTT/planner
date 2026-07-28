"""
Widget summary service — PixelPlanner P3-F9.

Provides a lightweight daily summary for the Android home screen widget.
Aggregates meals, exercise, schedule, and health into a compact JSON response.

Response structure:
    header{date, weekday, greeting}
    meals{summary, next, calories, items}
    exercise{summary, minutes, calories, status}
    schedule{next, count}
    health{steps, stand_hours, sleep}
"""

from __future__ import annotations

import logging
from datetime import date, datetime, time, timedelta, timezone
from typing import Any

from ..extensions import db
from ..models import Event, Todo
from ..models_habits import EventHistory, ExerciseRecord, MealRecord, UserPattern
from .time_service import SHANGHAI_TZ, get_clock

logger = logging.getLogger(__name__)

TZ = SHANGHAI_TZ

# Greeting time buckets (Beijing time)
GREETING_BUCKETS = [
    (time(5, 0), "早上好"),
    (time(8, 0), "上午好"),
    (time(12, 0), "中午好"),
    (time(14, 0), "下午好"),
    (time(18, 0), "傍晚好"),
    (time(22, 0), "晚上好"),
    (time(23, 59, 59), "夜深了"),
]

WEEKDAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def get_widget_summary(user_id: int) -> dict[str, Any]:
    """Return a compact daily summary for the home screen widget."""
    now = get_clock().now_local()
    today = now.date()
    today_start = datetime.combine(today, time(0, 0), tzinfo=TZ)
    today_end = datetime.combine(today, time(23, 59, 59), tzinfo=TZ)

    return {
        "header": _build_header(now, today),
        "meals": _get_meals_snapshot(user_id, today_start, today_end),
        "exercise": _get_exercise_snapshot(user_id, today_start, today_end),
        "schedule": _get_schedule_snapshot(user_id, now, today_end),
        "health": _get_health_snapshot(user_id, today_start, today_end),
    }


# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------


def _build_header(now: datetime, today: date) -> dict[str, Any]:
    """Build header with date, weekday, and time-appropriate greeting."""
    month = today.month
    day = today.day
    weekday = WEEKDAY_NAMES[today.weekday()]

    # Pick greeting based on current hour
    current_time = now.time()
    greeting = "你好"
    for bucket_time, text in GREETING_BUCKETS:
        if current_time <= bucket_time:
            greeting = text
            break

    return {
        "date": f"{month}月{day}日",
        "weekday": weekday,
        "greeting": greeting,
    }


# ---------------------------------------------------------------------------
# Meals
# ---------------------------------------------------------------------------


def _get_meals_snapshot(
    user_id: int, today_start: datetime, today_end: datetime
) -> dict[str, Any]:
    """Today's meal summary."""
    meals = (
        MealRecord.query
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= today_start,
            MealRecord.recorded_at <= today_end,
        )
        .order_by(MealRecord.recorded_at.asc())
        .all()
    )

    total_calories = 0
    for m in meals:
        if m.items:
            for item in (m.items if isinstance(m.items, list) else []):
                if isinstance(item, dict):
                    total_calories += item.get("calories", 0) or 0
    count = len(meals)

    # Determine next meal time suggestion
    now = get_clock().now_local()
    meal_times = {"早餐": time(8, 0), "午餐": time(12, 0), "晚餐": time(18, 0)}
    next_meal = None
    next_time_str = None
    for label, t in meal_times.items():
        dt = datetime.combine(now.date(), t, tzinfo=TZ)
        if dt > now and (
            next_time_str is None or t < meal_times.get(next_meal or "", time(23, 59))
        ):
            next_meal = label
            next_time_str = f"{t.hour:02d}:{t.minute:02d}"

    # Check which meal types were already recorded
    recorded_types = {m.meal_type for m in meals if m.meal_type}
    if next_meal and next_meal in recorded_types:
        next_meal = None
        next_time_str = None

    # Pick the most recent meal for display
    last_meal = meals[-1] if meals else None
    last_label = last_meal.meal_type or "餐食" if last_meal else None
    last_cal = None
    if last_meal and last_meal.items:
        for item in (last_meal.items if isinstance(last_meal.items, list) else []):
            if isinstance(item, dict):
                last_cal = item.get("calories", 0) or 0
                break

    summary = f"已记录 {count} 餐" if count > 0 else "今日未记录餐食"

    return {
        "summary": summary,
        "total_calories": total_calories,
        "count": count,
        "next": f"{next_meal} · {next_time_str}" if next_meal and next_time_str else None,
        "last": f"{last_label} {last_cal}kcal" if last_label and last_cal else None,
    }


# ---------------------------------------------------------------------------
# Exercise
# ---------------------------------------------------------------------------


def _get_exercise_snapshot(
    user_id: int, today_start: datetime, today_end: datetime
) -> dict[str, Any]:
    """Today's exercise summary."""
    records = (
        ExerciseRecord.query
        .filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.recorded_at >= today_start,
            ExerciseRecord.recorded_at <= today_end,
        )
        .all()
    )

    total_minutes = sum(r.duration_minutes or 0 for r in records)
    total_calories = sum(r.calories or 0 for r in records)
    total_steps = sum(r.steps or 0 for r in records)

    # Status: daily goal ~30 min
    if total_minutes >= 30:
        status = "今日达标"
        status_emoji = "✓"
    elif total_minutes > 0:
        status = f"还差{30 - total_minutes}分钟"
        status_emoji = "…"
    else:
        status = "今日未运动"
        status_emoji = "—"

    summary = f"运动 {total_minutes} 分钟" if total_minutes > 0 else "今日未运动"

    return {
        "summary": summary,
        "minutes": total_minutes,
        "calories": total_calories,
        "steps": total_steps,
        "status": status,
        "status_emoji": status_emoji,
    }


# ---------------------------------------------------------------------------
# Schedule (next event)
# ---------------------------------------------------------------------------


def _get_schedule_snapshot(
    user_id: int, now: datetime, today_end: datetime
) -> dict[str, Any]:
    """Next upcoming event and today's event count."""
    # Today's events
    # SQLite drops timezone information from DateTime values. Normalize both
    # sides in Python so events written with either aware or naive timestamps
    # are consistently visible to the widget.
    candidates = Event.query.filter(Event.user_id == user_id).all()
    def _as_tz(value: datetime) -> datetime:
        return value.replace(tzinfo=TZ) if value.tzinfo is None else value.astimezone(TZ)

    today_events = sorted(
        (
            event
            for event in candidates
            if event.starts_at
            and now <= _as_tz(event.starts_at) <= now + timedelta(hours=24)
        ),
        key=lambda event: _as_tz(event.starts_at),
    )

    count = len(today_events)
    next_event = today_events[0] if today_events else None

    next_str = None
    if next_event:
        event_time = next_event.starts_at
        if event_time.tzinfo is None:
            event_time = event_time.replace(tzinfo=TZ)
        time_str = event_time.astimezone(TZ).strftime("%H:%M")
        title = next_event.title or "日程"
        next_str = f"{time_str} {title}"

    return {
        "next": next_str,
        "count": count,
        "summary": f"{count} 项待办" if count > 0 else "今日无日程",
    }


# ---------------------------------------------------------------------------
# Health snapshot (standing + sleep from routine)
# ---------------------------------------------------------------------------


def _get_health_snapshot(
    user_id: int, today_start: datetime, today_end: datetime
) -> dict[str, Any]:
    """Quick health stats: standing & sleep."""
    # Standing: use today's EventHistory with notify_type='standing'
    standing_records = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "standing",
            EventHistory.planned_time >= today_start,
            EventHistory.planned_time <= today_end,
        )
        .all()
    )

    total = len(standing_records)
    skipped = sum(1 for r in standing_records if r.skipped)
    completed = total - skipped

    # Sleep: check UserPattern for today's wake time
    pattern = (
        UserPattern.query
        .filter(UserPattern.user_id == user_id)
        .first()
    )

    sleep_str = None
    if pattern and pattern.wake_time:
        sleep_str = _format_wake_time(pattern.wake_time)

    return {
        "stand_total": total,
        "stand_completed": completed,
        "stand_skipped": skipped,
        "stand_label": f"站立 {completed} 次" if completed > 0 else "今日未记录站立",
        "sleep": sleep_str,
    }


def _format_wake_time(wake_str: str) -> str | None:
    """Format wake time like '07:30' into sleep estimate."""
    try:
        parts = wake_str.strip().split(":")
        if len(parts) == 2:
            hour = int(parts[0])
            minute = int(parts[1])
            wake_dt = datetime(2000, 1, 1, hour, minute)
            sleep_dt = wake_dt - timedelta(hours=7, minutes=30)
            return f"约 {sleep_dt.hour:02d}:{sleep_dt.minute:02d} 入睡"
    except (ValueError, IndexError):
        pass
    return None
