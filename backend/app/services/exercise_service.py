"""
Exercise service — mode switching, auto/manual recording, daily summary.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §12
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from flask import current_app

from ..extensions import db
from ..models import User
from ..models_habits import ExerciseRecord
from .time_service import get_clock

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Mode management
# ---------------------------------------------------------------------------


def get_current_mode(user: User) -> dict[str, Any]:
    """Return the user's current exercise mode info.

    If trainer mode has expired, auto-switch back to self and return self.
    """
    mode = getattr(user, "exercise_mode", "self") or "self"
    end_date = getattr(user, "trainer_end_date", None)

    if mode == "trainer" and end_date is not None:
        if end_date < get_clock().now_utc().date():
            # Auto-switch back to self
            user.exercise_mode = "self"
            user.trainer_end_date = None
            db.session.commit()
            mode = "self"
            end_date = None

    return {
        "exercise_mode": mode,
        "trainer_end_date": end_date.isoformat() if end_date else None,
    }


def set_mode(user: User, exercise_mode: str, trainer_end_date: str | None = None) -> dict[str, Any]:
    """Set the user's exercise mode.

    Args:
        user: User instance.
        exercise_mode: 'self' or 'trainer'.
        trainer_end_date: ISO date string for trainer mode expiry (ignored for self).

    Returns:
        Updated mode info dict.
    """
    user.exercise_mode = exercise_mode

    if exercise_mode == "trainer" and trainer_end_date:
        user.trainer_end_date = datetime.fromisoformat(trainer_end_date)
    else:
        user.trainer_end_date = None

    db.session.commit()
    return get_current_mode(user)


# ---------------------------------------------------------------------------
# Exercise records
# ---------------------------------------------------------------------------


def create_record(
    user_id: int,
    exercise_type: str,
    duration_minutes: int,
    source: str = "manual",
    calories: int | None = None,
    steps: int | None = None,
    recorded_at: datetime | None = None,
) -> ExerciseRecord:
    """Create a new exercise record.

    Args:
        user_id: User ID.
        exercise_type: 'walking' / 'running' / 'cycling' / etc.
        duration_minutes: Duration in minutes.
        source: 'sensor' / 'manual'.
        calories: Estimated calories burned.
        steps: Step count.
        recorded_at: When the exercise occurred (defaults to now).

    Returns:
        The created ExerciseRecord.
    """
    record = ExerciseRecord(
        user_id=user_id,
        exercise_type=exercise_type,
        duration_minutes=duration_minutes,
        source=source,
        calories=calories,
        steps=steps,
        recorded_at=recorded_at or get_clock().now_utc(),
    )
    db.session.add(record)
    db.session.commit()
    return record


def get_today_summary(user_id: int) -> dict[str, Any]:
    """Get today's exercise summary for a user.

    Returns:
        Dict with date, total_minutes, total_calories, total_steps, records.
    """
    today_start = get_clock().now_utc().replace(hour=0, minute=0, second=0, microsecond=0)
    records = (
        ExerciseRecord.query
        .filter_by(user_id=user_id)
        .filter(ExerciseRecord.recorded_at >= today_start)
        .order_by(ExerciseRecord.recorded_at.desc())
        .all()
    )

    total_minutes = 0
    total_calories = 0
    total_steps = 0
    record_dicts = []

    for r in records:
        total_minutes += r.duration_minutes or 0
        total_calories += r.calories or 0
        total_steps += r.steps or 0
        record_dicts.append(_record_to_dict(r))

    return {
        "date": today_start.isoformat(),
        "total_minutes": total_minutes,
        "total_calories": total_calories,
        "total_steps": total_steps,
        "records": record_dicts,
    }


def get_history(user_id: int, days: int = 7) -> dict[str, Any]:
    """Get exercise history for the past N days."""
    since = get_clock().now_utc() - timedelta(days=days)
    records = (
        ExerciseRecord.query
        .filter_by(user_id=user_id)
        .filter(ExerciseRecord.recorded_at >= since)
        .order_by(ExerciseRecord.recorded_at.desc())
        .all()
    )
    return {
        "records": [_record_to_dict(r) for r in records],
        "days": days,
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _record_to_dict(record: ExerciseRecord) -> dict[str, Any]:
    return {
        "id": record.id,
        "exercise_type": record.exercise_type,
        "duration_minutes": record.duration_minutes or 0,
        "calories": record.calories,
        "steps": record.steps,
        "recorded_at": record.recorded_at.isoformat() if record.recorded_at else None,
        "source": record.source or "manual",
    }
