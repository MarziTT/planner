"""
Health data aggregation service — PixelPlanner P3-F2.

Aggregates exercise, meals, routine (sleep/wake), and standing habits
over a configurable lookback window (default 7 days) with daily breakdowns
and summary statistics.

Response structure:
    period, exercise{daily[], summary}, meals{daily[], summary},
    routine{daily[], summary}, standing{daily[], summary}
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from typing import Any

from ..extensions import db
from ..models_habits import EventHistory, ExerciseRecord, MealRecord, UserPattern
from .time_service import SHANGHAI_TZ, get_clock

logger = logging.getLogger(__name__)

TZ = SHANGHAI_TZ
MAX_DAYS = 90


def get_health_trends(user_id: int, days: int = 7) -> dict[str, Any]:
    """Aggregate health data over *days* (default 7, max 90).

    Returns:
        period, exercise, meals, routine, standing
    """
    days = max(1, min(days, MAX_DAYS))
    today = get_clock().now_local().date()
    start_date = today - timedelta(days=days - 1)

    # Pre‑compute date range as list of date objects for zero‑fill
    date_range = [start_date + timedelta(days=i) for i in range(days)]

    return {
        "period": {
            "start": start_date.isoformat(),
            "end": today.isoformat(),
            "days": days,
        },
        "exercise": _exercise_trends(user_id, start_date, today, date_range),
        "meals": _meals_trends(user_id, start_date, today, date_range),
        "routine": _routine_trends(user_id, start_date, today, date_range),
        "standing": _standing_trends(user_id, start_date, today, date_range),
    }


# ---------------------------------------------------------------------------
# Exercise trends
# ---------------------------------------------------------------------------


def _exercise_trends(
    user_id: int, start_date: date, end_date: date, date_range: list[date]
) -> dict[str, Any]:
    """Daily exercise totals: minutes, calories, steps."""
    start_dt = datetime.combine(start_date, time(0, 0), tzinfo=TZ)
    end_dt = datetime.combine(end_date, time(23, 59, 59), tzinfo=TZ)

    records = (
        ExerciseRecord.query
        .filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.recorded_at >= start_dt,
            ExerciseRecord.recorded_at <= end_dt,
        )
        .order_by(ExerciseRecord.recorded_at.asc())
        .all()
    )

    # Group by local date
    by_date: dict[date, dict[str, int]] = defaultdict(lambda: {"minutes": 0, "calories": 0, "steps": 0, "records": 0})
    for r in records:
        d = r.recorded_at.astimezone(TZ).date()
        by_date[d]["minutes"] += r.duration_minutes or 0
        by_date[d]["calories"] += r.calories or 0
        by_date[d]["steps"] += r.steps or 0
        by_date[d]["records"] += 1

    daily = []
    total_minutes = total_calories = total_steps = total_records = 0
    for d in date_range:
        entry = by_date.get(d, {"minutes": 0, "calories": 0, "steps": 0, "records": 0})
        daily.append({
            "date": d.isoformat(),
            "total_minutes": entry["minutes"],
            "total_calories": entry["calories"],
            "total_steps": entry["steps"],
            "record_count": entry["records"],
        })
        total_minutes += entry["minutes"]
        total_calories += entry["calories"]
        total_steps += entry["steps"]
        total_records += entry["records"]

    active_days = sum(1 for e in daily if e["record_count"] > 0)

    return {
        "daily": daily,
        "summary": {
            "total_minutes": total_minutes,
            "total_calories": total_calories,
            "total_steps": total_steps,
            "total_records": total_records,
            "avg_minutes": round(total_minutes / len(date_range), 1),
            "avg_calories": round(total_calories / len(date_range), 1),
            "avg_steps": round(total_steps / len(date_range), 1),
            "active_days": active_days,
            "streak": _calc_streak(daily),
        },
    }


# ---------------------------------------------------------------------------
# Meals / nutrition trends
# ---------------------------------------------------------------------------


def _meals_trends(
    user_id: int, start_date: date, end_date: date, date_range: list[date]
) -> dict[str, Any]:
    """Daily meal totals: calories, count, breakdown by meal_type."""
    start_dt = datetime.combine(start_date, time(0, 0), tzinfo=TZ)
    end_dt = datetime.combine(end_date, time(23, 59, 59), tzinfo=TZ)

    records = (
        MealRecord.query
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= start_dt,
            MealRecord.recorded_at <= end_dt,
        )
        .order_by(MealRecord.recorded_at.asc())
        .all()
    )

    by_date: dict[date, dict[str, Any]] = {}
    for r in records:
        d = r.recorded_at.astimezone(TZ).date()
        if d not in by_date:
            by_date[d] = {
                "calories": 0,
                "count": 0,
                "breakfast": 0,
                "lunch": 0,
                "dinner": 0,
                "snack": 0,
                "protein": 0,
                "carb": 0,
                "fat": 0,
            }
        entry = by_date[d]
        entry["count"] += 1

        # Sum calories from items JSON
        meal_cals = _sum_item_calories(r.items)
        entry["calories"] += meal_cals

        # Accumulate by meal type
        meal_type = r.meal_type or "snack"
        if meal_type in entry:
            entry[meal_type] += meal_cals

        # Rough macro estimates
        entry["protein"] += _estimate_macro(r.items, "protein")
        entry["carb"] += _estimate_macro(r.items, "carb")
        entry["fat"] += _estimate_macro(r.items, "fat")

    daily = []
    total_cals = total_count = 0
    for d in date_range:
        entry = by_date.get(d, {
            "calories": 0, "count": 0,
            "breakfast": 0, "lunch": 0, "dinner": 0, "snack": 0,
            "protein": 0, "carb": 0, "fat": 0,
        })
        daily.append({
            "date": d.isoformat(),
            "total_calories": entry["calories"],
            "meal_count": entry["count"],
            "breakfast": entry["breakfast"],
            "lunch": entry["lunch"],
            "dinner": entry["dinner"],
            "snack": entry["snack"],
            "protein_g": round(entry["protein"], 1),
            "carb_g": round(entry["carb"], 1),
            "fat_g": round(entry["fat"], 1),
        })
        total_cals += entry["calories"]
        total_count += entry["count"]

    active_days = sum(1 for e in daily if e["meal_count"] > 0)

    return {
        "daily": daily,
        "summary": {
            "total_calories": total_cals,
            "total_meals": total_count,
            "avg_daily_calories": round(total_cals / len(date_range), 1),
            "avg_meal_count": round(total_count / len(date_range), 1) if date_range else 0,
            "active_days": active_days,
            "streak": _calc_streak(daily, key="meal_count"),
        },
    }


def _sum_item_calories(items: Any) -> int:
    """Sum calories from meal items JSON array."""
    if not items:
        return 0
    try:
        if isinstance(items, str):
            import json
            items = json.loads(items)
        return sum(it.get("calories", 0) or 0 for it in items if isinstance(it, dict))
    except Exception:
        return 0


# Rough macros per category (grams per 100 kcal, rough estimates)
_MACRO_ESTIMATES: dict[str, dict[str, float]] = {
    "主食":   {"protein": 2.5, "carb": 22.0, "fat": 0.5},
    "蔬菜":   {"protein": 4.0, "carb": 10.0, "fat": 0.3},
    "肉类":   {"protein": 20.0, "carb": 0.0, "fat": 10.0},
    "海鲜":   {"protein": 18.0, "carb": 0.0, "fat": 2.0},
    "豆制品": {"protein": 8.0, "carb": 3.0, "fat": 4.0},
    "汤品":   {"protein": 2.0, "carb": 3.0, "fat": 2.0},
    "水果":   {"protein": 0.5, "carb": 22.0, "fat": 0.2},
    "饮料":   {"protein": 0.0, "carb": 25.0, "fat": 0.0},
    "零食":   {"protein": 3.0, "carb": 12.0, "fat": 8.0},
    "其他":   {"protein": 5.0, "carb": 10.0, "fat": 5.0},
}


def _estimate_macro(items: Any, macro: str) -> float:
    """Rough macro estimate based on food category."""
    if not items:
        return 0.0
    try:
        if isinstance(items, str):
            import json
            items = json.loads(items)
        total = 0.0
        for it in items:
            if not isinstance(it, dict):
                continue
            cals = it.get("calories", 0) or 0
            cat = it.get("category", "其他")
            ratio = _MACRO_ESTIMATES.get(cat, _MACRO_ESTIMATES["其他"])
            # ratio is g per 100 kcal
            total += cals * ratio.get(macro, 0) / 100.0
        return round(total, 1)
    except Exception:
        return 0.0


# ---------------------------------------------------------------------------
# Routine / sleep trends
# ---------------------------------------------------------------------------


def _routine_trends(
    user_id: int, start_date: date, end_date: date, date_range: list[date]
) -> dict[str, Any]:
    """Daily wake/sleep times from UserPattern history.

    Since UserPattern only stores the latest value, we also look at
    ExerciseRecord as a proxy for wake time (earliest record each day).
    """
    # Get current pattern as baseline
    wake_pattern = (
        UserPattern.query
        .filter_by(user_id=user_id, pattern_type="wake_time")
        .first()
    )

    # Estimate daily wake times from exercise records (earliest of the day)
    start_dt = datetime.combine(start_date, time(0, 0), tzinfo=TZ)
    end_dt = datetime.combine(end_date, time(23, 59, 59), tzinfo=TZ)

    all_exercise = (
        ExerciseRecord.query
        .filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.recorded_at >= start_dt,
            ExerciseRecord.recorded_at <= end_dt,
        )
        .order_by(ExerciseRecord.recorded_at.asc())
        .all()
    )

    # Group by date, take earliest record
    earliest_by_date: dict[date, datetime] = {}
    for r in all_exercise:
        d = r.recorded_at.astimezone(TZ).date()
        if d not in earliest_by_date or r.recorded_at < earliest_by_date[d]:
            earliest_by_date[d] = r.recorded_at

    # Default wake time from pattern
    default_h, default_m = 7, 30
    if wake_pattern and wake_pattern.pattern_value:
        try:
            val = wake_pattern.pattern_value if isinstance(wake_pattern.pattern_value, dict) else __import__("json").loads(wake_pattern.pattern_value)
            default_h = val.get("hour", 7)
            default_m = val.get("minute", 30)
        except Exception:
            pass

    daily = []
    wake_hours = []
    for d in date_range:
        earliest = earliest_by_date.get(d)
        if earliest:
            lt = earliest.astimezone(TZ)
            wh, wm = lt.hour, lt.minute
            source = "exercise"
        else:
            wh, wm = default_h, default_m
            source = "default"

        # Sleep = wake - 8h
        sleep_total = (wh * 60 + wm) - 8 * 60
        if sleep_total < 0:
            sleep_total += 24 * 60
        sh, sm = divmod(sleep_total, 60)

        daily.append({
            "date": d.isoformat(),
            "wake_time": f"{wh:02d}:{wm:02d}",
            "wake_source": source,
            "sleep_time": f"{sh:02d}:{sm:02d}",
            "sleep_hours": 8.0,
        })
        wake_hours.append(wh + wm / 60.0)

    avg_wake = sum(wake_hours) / len(wake_hours) if wake_hours else 7.5
    avg_h, avg_m = divmod(int(avg_wake * 60), 60)
    avg_h = avg_h % 24

    return {
        "daily": daily,
        "summary": {
            "avg_wake_time": f"{avg_h:02d}:{avg_m:02d}",
            "avg_sleep_hours": 8.0,
            "default_wake_time": f"{default_h:02d}:{default_m:02d}",
            "active_days": len(earliest_by_date),
        },
    }


# ---------------------------------------------------------------------------
# Standing habits trends
# ---------------------------------------------------------------------------


def _standing_trends(
    user_id: int, start_date: date, end_date: date, date_range: list[date]
) -> dict[str, Any]:
    """Daily standing reminder completion rates."""
    start_dt = datetime.combine(start_date, time(0, 0), tzinfo=TZ)
    end_dt = datetime.combine(end_date, time(23, 59, 59), tzinfo=TZ)

    events = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "standing",
            EventHistory.planned_time >= start_dt,
            EventHistory.planned_time <= end_dt,
        )
        .all()
    )

    by_date: dict[date, dict[str, int]] = defaultdict(lambda: {"total": 0, "completed": 0, "skipped": 0})
    for e in events:
        d = e.planned_time.astimezone(TZ).date()
        by_date[d]["total"] += 1
        if e.skipped:
            by_date[d]["skipped"] += 1
        else:
            by_date[d]["completed"] += 1

    daily = []
    total = total_completed = total_skipped = 0
    for d in date_range:
        entry = by_date.get(d, {"total": 0, "completed": 0, "skipped": 0})
        rate = entry["completed"] / entry["total"] if entry["total"] > 0 else 0.0
        daily.append({
            "date": d.isoformat(),
            "total": entry["total"],
            "completed": entry["completed"],
            "skipped": entry["skipped"],
            "completion_rate": round(rate, 2),
        })
        total += entry["total"]
        total_completed += entry["completed"]
        total_skipped += entry["skipped"]

    active_days = sum(1 for e in daily if e["total"] > 0)

    return {
        "daily": daily,
        "summary": {
            "total": total,
            "completed": total_completed,
            "skipped": total_skipped,
            "avg_completion_rate": round(total_completed / total, 2) if total else 0,
            "active_days": active_days,
            "streak": _calc_standing_streak(daily),
        },
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _calc_streak(daily: list[dict], key: str = "record_count") -> int:
    """Calculate consecutive active days streak (from today backwards)."""
    streak = 0
    for entry in reversed(daily):
        if entry.get(key, 0) > 0:
            streak += 1
        else:
            break
    return streak


def _calc_standing_streak(daily: list[dict]) -> int:
    """Calculate consecutive days with >50% standing completion (from today)."""
    streak = 0
    for entry in reversed(daily):
        if entry["total"] > 0 and entry["completion_rate"] >= 0.5:
            streak += 1
        else:
            break
    return streak
