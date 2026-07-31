"""
Dashboard aggregation service — Jarvis Agent Phase 2.

Aggregates all six domains (schedule, weather, routine, meals, exercise, transit)
into a single overview response for the Habits Dashboard.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, time
from typing import Any

from ..extensions import db
from ..models import Event, Todo, User
from ..models_habits import ExerciseRecord, MealRecord, UserPattern
from ..services.exercise_service import get_today_summary as _exercise_today
from ..services.meal_service import get_daily_summary as _meals_summary
from ..services.routine_service import get_routine_today as _routine_today
from ..services.time_service import SHANGHAI_TZ, get_clock

logger = logging.getLogger(__name__)

TZ = SHANGHAI_TZ


def get_dashboard_overview(user_id: int, lat: float | None = None, lon: float | None = None) -> dict[str, Any]:
    """Aggregate all 6 domain data into dashboard overview.

    Returns a dictionary with keys:
        date, schedule, weather, routine, meals, exercise, transit, pattern_announcement
    """
    today = get_clock().now_local().date()
    today_start = datetime.combine(today, time(0, 0), tzinfo=TZ)
    today_end = datetime.combine(today, time(23, 59, 59), tzinfo=TZ)

    return {
        "date": today.isoformat(),
        "schedule": _get_schedule_snapshot(user_id, today_start, today_end),
        "weather": _get_weather_snapshot(lat, lon),
        "routine": _get_routine_snapshot(user_id),
        "meals": _get_meals_snapshot(user_id),
        "exercise": _get_exercise_snapshot(user_id),
        "transit": _get_transit_snapshot(user_id, today_start, today_end),
        "pattern_announcement": _get_pattern_announcement(user_id),
    }


# ---------------------------------------------------------------------------
# Domain snapshots
# ---------------------------------------------------------------------------


def _get_schedule_snapshot(user_id: int, today_start: datetime, today_end: datetime) -> dict:
    """Today's schedule — pending events count + next 3 upcoming events."""

    event_query = (
        Event.query
        .filter(
            Event.user_id == user_id,
            Event.starts_at >= today_start,
            Event.starts_at <= today_end,
            Event.status != "cancelled",
        )
        .order_by(Event.starts_at.asc())
    )
    event_count = event_query.count()
    events = event_query.limit(3).all()

    todos = (
        Todo.query
        .filter(
            Todo.user_id == user_id,
            Todo.completed == False,
            Todo.due_date <= today_start.date(),
            Todo.due_date >= today_start.date(),
        )
        .count()
    )

    upcoming = []
    for e in events[:3]:
        upcoming.append({
            "id": e.id,
            "title": e.title,
            "time": e.starts_at.strftime("%H:%M"),
            "status": e.status,
        })

    return {
        "pending_count": event_count + todos,
        "event_count": event_count,
        "todo_count": todos,
        "upcoming": upcoming,
    }


def _get_weather_snapshot(lat: float | None, lon: float | None) -> dict:
    """Weather snapshot — placeholder, client fetches weather directly.

    If lat/lon are provided, try to fetch weather; otherwise return empty.
    """
    if lat is None or lon is None:
        return {"available": False, "message": "lat/lon not provided"}

    try:
        from ..services.weather_service import fetch_weather
        data = fetch_weather(lat, lon)

        current = data.get("current", {})
        daily = data.get("daily", [])
        today_daily = daily[0] if daily else {}

        return {
            "available": True,
            "temp": current.get("temp", "--"),
            "feels_like": current.get("feels_like", "--"),
            "condition": current.get("weather_text", "--"),
            "condition_code": current.get("weather_code", 0),
            "humidity": current.get("humidity", "--"),
            "wind_speed": current.get("wind_speed", "--"),
            "high": today_daily.get("temp_max", "--"),
            "low": today_daily.get("temp_min", "--"),
        }
    except Exception as exc:
        logger.warning("Weather snapshot failed: %s", exc)
        return {"available": False, "message": str(exc)}


def _get_routine_snapshot(user_id: int) -> dict:
    """Routine snapshot — wake time, sleep suggestion, standing status."""
    try:
        routine = _routine_today(user_id)

        wake = routine.get("wake_time", {})
        sleep = routine.get("sleep_time", {})
        standing = routine.get("standing", {})

        return {
            "available": True,
            "wake_time": f"{wake.get('hour', 7):02d}:{wake.get('minute', 30):02d}",
            "wake_source": wake.get("source", "default"),
            "sleep_time": f"{sleep.get('hour', 23):02d}:{sleep.get('minute', 30):02d}",
            "standing_enabled": standing.get("enabled", False),
            "standing_completed": standing.get("today_total", 0) - standing.get("today_skipped", 0),
            "standing_total": standing.get("today_total", 0),
            "auto_stopped": standing.get("auto_stopped", False),
        }
    except Exception as exc:
        logger.warning("Routine snapshot failed: %s", exc)
        return {"available": False, "message": str(exc)}


def _get_meals_snapshot(user_id: int) -> dict:
    """Meals snapshot — today's recorded meals + total calories."""
    try:
        summary = _meals_summary(user_id)
        return {
            "available": True,
            "total_calories": summary.get("total_calories", 0),
            "meal_count": summary.get("meal_count", 0),
            "by_type": summary.get("by_type", {}),
            "weekly_avg": summary.get("weekly_avg_calories", 0),
        }
    except Exception as exc:
        logger.warning("Meals snapshot failed: %s", exc)
        return {"available": False, "message": str(exc), "total_calories": 0, "meal_count": 0}


def _get_exercise_snapshot(user_id: int) -> dict:
    """Exercise snapshot — today's steps, duration, calories."""
    try:
        summary = _exercise_today(user_id)
        return {
            "available": True,
            "total_minutes": summary.get("total_minutes", 0),
            "total_calories": summary.get("total_calories", 0),
            "total_steps": summary.get("total_steps", 0),
            "record_count": summary.get("record_count", 0),
        }
    except Exception as exc:
        logger.warning("Exercise snapshot failed: %s", exc)
        return {"available": False, "message": str(exc), "total_minutes": 0, "total_calories": 0, "total_steps": 0}


def _get_transit_snapshot(user_id: int, today_start: datetime, today_end: datetime) -> dict:
    """Transit snapshot — upcoming trips with departure countdown.

    Transit trips are learned from EventHistory entries with notify_type='transit'.
    """
    from ..models_habits import EventHistory

    recent_transit = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "transit",
            EventHistory.planned_time >= today_start,
            EventHistory.planned_time <= today_end,
        )
        .order_by(EventHistory.planned_time.asc())
        .limit(3)
        .all()
    )

    now = get_clock().now_local()
    trips = []
    for t in recent_transit:
        delta = t.planned_time - now
        minutes_left = int(delta.total_seconds() / 60) if delta.total_seconds() > 0 else 0
        trips.append({
            "id": t.id,
            "planned_time": t.planned_time.isoformat() if t.planned_time else None,
            "minutes_to_departure": max(0, minutes_left),
            "completed": t.completed_at is not None,
            "skipped": t.skipped,
        })

    return {
        "available": True,
        "trip_count": len(trips),
        "trips": trips,
    }


# ---------------------------------------------------------------------------
# Pattern announcement — 乔布斯风格有温度的一句话
# ---------------------------------------------------------------------------


def _get_pattern_announcement(user_id: int) -> str | None:
    """Generate a human-friendly announcement based on learned patterns.

    Returns a single sentence or None if no patterns are available.
    """
    patterns = (
        UserPattern.query
        .filter_by(user_id=user_id)
        .all()
    )

    if not patterns:
        return None

    # Group by type
    meal_times: dict[str, str] = {}
    wake_time: str | None = None

    for p in patterns:
        if p.pattern_type == "meal_time" and p.pattern_value:
            try:
                val = p.pattern_value if isinstance(p.pattern_value, dict) else json.loads(p.pattern_value)
                h = val.get("hour", 12)
                m = val.get("minute", 0)
                meal_times[p.pattern_key] = f"{int(h):02d}:{int(m):02d}"
            except Exception:
                logger.warning("Failed to parse meal_time pattern: %s", p.pattern_value)
        elif p.pattern_type == "wake_time" and p.pattern_value:
            try:
                val = p.pattern_value if isinstance(p.pattern_value, dict) else json.loads(p.pattern_value)
                h = val.get("hour", 7)
                m = val.get("minute", 30)
                wake_time = f"{int(h):02d}:{int(m):02d}"
            except Exception:
                logger.warning("Failed to parse wake_time pattern: %s", p.pattern_value)

    # Build announcement
    announcements: list[str] = []

    meal_labels = {"lunch": "午餐", "dinner": "晚餐", "breakfast": "早餐"}
    if "lunch" in meal_times:
        announcements.append(
            f"你午饭通常在 {meal_times['lunch']} 左右，今天按这个时间安排了提醒"
        )
    if "dinner" in meal_times:
        announcements.append(
            f"晚饭时间一般在 {meal_times['dinner']}，别吃太晚，对胃好"
        )
    if "breakfast" in meal_times:
        announcements.append(
            f"你通常 {meal_times['breakfast']} 吃早餐，习惯很好，继续保持"
        )

    if wake_time:
        announcements.append(
            f"你通常 {wake_time} 起床，今晚 {_wake_to_sleep(wake_time)} 前睡觉能保证 8 小时睡眠"
        )

    # Select the most relevant one (prefer lunch time announcement)
    if announcements:
        return announcements[0]

    # Generic fallback
    if wake_time:
        return f"你通常 {wake_time} 起床，今晚记得早点休息"
    if meal_times:
        first_label = next(iter(meal_times))
        return f"你通常在 {meal_times[first_label]} 用餐，好习惯是成功的一半"

    return "今天是新的一天，按计划推进就是对时间的尊重"


def _wake_to_sleep(wake_str: str) -> str:
    """Convert wake time to recommended sleep time (-8h)."""
    try:
        parts = wake_str.split(":")
        h = int(parts[0])
        m = int(parts[1])
        sleep_h = (h - 8) % 24
        return f"{sleep_h:02d}:{m:02d}"
    except Exception:
        return "23:00"
