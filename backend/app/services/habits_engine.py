"""
Habits engine — Jarvis Agent Phase 2.

Sliding-window (30-day) pattern detection and dynamic notification-timing
adjustment.  Non-ML; pure statistical heuristics.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §7
"""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import func

from ..models_habits import (
    EventHistory,
    ExerciseRecord,
    MealRecord,
    NotifyPreference,
    UserPattern,
)

logger = logging.getLogger(__name__)

TZ = timezone(timedelta(hours=8))  # UTC+8


# ---------------------------------------------------------------------------
#  Public API — adjust_lead_minutes
# ---------------------------------------------------------------------------

def adjust_lead_minutes(notify_type: str, user_id: int) -> int | None:
    """Return the recommended lead-minutes for *notify_type*, or None to cancel.

    Heuristics per spec §7.1:
      - transit   → avg(planned_time − reminded_at) of last 30 days
      - standing  → if last 5 consecutive skips → None (cancel); else 0
      - meal      → compute typical lead from actual completion times
    """
    if notify_type == "transit":
        return _transit_lead(user_id)

    if notify_type == "standing":
        return _standing_lead(user_id)

    if notify_type == "meal":
        return _meal_lead(user_id)

    # Other notify types — return current stored preference unchanged.
    pref = _get_pref(user_id, notify_type)
    return pref.get("lead_minutes") if pref else None


# ---------------------------------------------------------------------------
#  Public API — get_user_patterns
# ---------------------------------------------------------------------------

def get_user_patterns(user_id: int) -> dict[str, Any]:
    """Return a human-readable summary of learned patterns for *user_id*."""
    rows = UserPattern.query.filter_by(user_id=user_id).order_by(
        UserPattern.pattern_type, UserPattern.pattern_key
    ).all()

    grouped: dict[str, list[dict]] = {}
    for row in rows:
        g = grouped.setdefault(row.pattern_type, [])
        g.append({
            "key": row.pattern_key,
            "value": row.pattern_value,
            "confidence": row.confidence,
            "sample_count": row.sample_count,
        })

    return {
        "user_id": user_id,
        "patterns": grouped,
        "summary": _summarise_patterns(grouped),
    }


# ---------------------------------------------------------------------------
#  Public API — record_event_history
# ---------------------------------------------------------------------------

def record_event_history(
    *,
    event_id: int | None,
    user_id: int,
    notify_type: str,
    planned_time: datetime,
    reminded_at: datetime | None = None,
    completed_at: datetime | None = None,
    delayed_count: int = 0,
    skipped: bool = False,
) -> EventHistory:
    """Record a single event lifecycle snapshot and return the row."""
    entry = EventHistory(
        event_id=event_id,
        user_id=user_id,
        notify_type=notify_type,
        planned_time=planned_time,
        reminded_at=reminded_at,
        completed_at=completed_at,
        delayed_count=delayed_count,
        skipped=skipped,
    )
    from ..extensions import db

    db.session.add(entry)
    db.session.commit()
    return entry


# ---------------------------------------------------------------------------
#  Public API — detect_patterns
# ---------------------------------------------------------------------------

def detect_patterns(user_id: int) -> list[UserPattern]:
    """Run sliding-window (30-day) detectors and upsert pattern records.

    Returns the (possibly empty) list of patterns that were created or updated.
    """
    results: list[UserPattern] = []

    # -- wake_time (from exercise_records earliest daily activity) ----------
    wake = _detect_wake_time(user_id)
    if wake:
        results.append(_upsert_pattern(user_id, wake))

    # -- meal_time (breakfast / lunch / dinner) ----------------------------
    for meal_type in ("breakfast", "lunch", "dinner"):
        mt = _detect_meal_time(user_id, meal_type)
        if mt:
            results.append(_upsert_pattern(user_id, mt))

    # -- standing_acceptance -----------------------------------------------
    standing = _detect_standing_acceptance(user_id)
    if standing:
        results.append(_upsert_pattern(user_id, standing))

    # -- transit_lead ------------------------------------------------------
    transit = _detect_transit_lead(user_id)
    if transit:
        results.append(_upsert_pattern(user_id, transit))

    from ..extensions import db

    db.session.commit()
    logger.info("detect_patterns(user_id=%d) → %d patterns", user_id, len(results))
    return results


# ===========================================================================
#  Lead-minute calculators
# ===========================================================================

def _transit_lead(user_id: int) -> int | None:
    """avg(planned_time − reminded_at) for transit events in the last 30 days."""
    cutoff = datetime.now(TZ) - timedelta(days=30)

    rows = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "transit",
            EventHistory.reminded_at.isnot(None),
            EventHistory.planned_time >= cutoff,
        )
        .all()
    )

    if not rows:
        return None

    deltas = [(r.planned_time - r.reminded_at).total_seconds() / 60 for r in rows]
    avg = sum(deltas) / len(deltas)
    return max(5, int(round(avg)))  # floor at 5 minutes


def _standing_lead(user_id: int) -> int | None:
    """Return None (cancel) if the last 5 consecutive standings were skipped."""
    recent = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "standing",
        )
        .order_by(EventHistory.planned_time.desc())
        .limit(5)
        .all()
    )

    if len(recent) < 5:
        return 0  # not enough data

    if all(r.skipped for r in recent):
        return None  # cancel

    return 0


def _meal_lead(user_id: int) -> int | None:
    """Based on actual meal completion times over the last 30 days."""
    cutoff = datetime.now(TZ) - timedelta(days=30)

    rows = (
        MealRecord.query
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= cutoff,
            MealRecord.meal_type == "lunch",
        )
        .all()
    )

    if not rows:
        return None

    # Average lunch hour in the day (ignore date)
    minutes_of_day = [
        r.recorded_at.astimezone(TZ).hour * 60 + r.recorded_at.astimezone(TZ).minute
        for r in rows
    ]
    avg_min = sum(minutes_of_day) / len(minutes_of_day)
    typical_hour = int(avg_min) // 60
    typical_minute = int(avg_min) % 60

    now = datetime.now(TZ)
    typical_dt = now.replace(hour=typical_hour, minute=typical_minute, second=0, microsecond=0)
    lead = int((typical_dt - now).total_seconds() / 60)

    if lead < 5:
        lead = 5  # floor

    return lead


# ===========================================================================
#  Pattern detectors (sliding window, 30 days)
# ===========================================================================

def _detect_wake_time(user_id: int) -> dict | None:
    """Detect average wake time from exercise_records (step-count onset).

    Uses the earliest daily recorded_at in the 04:00-10:00 window as a proxy
    for wake-up time (spec §12.1).
    """
    cutoff = datetime.now(TZ).date() - timedelta(days=30)
    from ..extensions import db

    # For each day, find the earliest exercise_record in the 04:00–10:00 window.
    # SQLite-compatible: work with dates directly.
    rows = (
        db.session.query(
            func.date(ExerciseRecord.recorded_at).label("day"),
            func.min(ExerciseRecord.recorded_at).label("earliest"),
        )
        .filter(
            ExerciseRecord.user_id == user_id,
            func.date(ExerciseRecord.recorded_at) >= cutoff.isoformat(),
        )
        .group_by(func.date(ExerciseRecord.recorded_at))
        .all()
    )

    wake_times: list[datetime] = []
    for day_str, earliest in rows:
        if earliest is None:
            continue
        dt = earliest.astimezone(TZ)
        if 4 <= dt.hour < 10:
            wake_times.append(dt)

    if len(wake_times) < 3:
        return None

    avg_min = sum(
        wt.hour * 60 + wt.minute for wt in wake_times
    ) / len(wake_times)
    avg_h, avg_m = divmod(int(round(avg_min)), 60)

    return {
        "pattern_type": "wake_time",
        "pattern_key": "default",
        "pattern_value": {"hour": avg_h, "minute": avg_m,
                          "weekday_count": len(wake_times)},
        "confidence": min(1.0, len(wake_times) / 20.0),
        "sample_count": len(wake_times),
    }


def _detect_meal_time(user_id: int, meal_type: str) -> dict | None:
    """Detect the typical *meal_type* time from the last 30 days."""
    cutoff = datetime.now(TZ) - timedelta(days=30)

    rows = (
        MealRecord.query
        .filter(
            MealRecord.user_id == user_id,
            MealRecord.meal_type == meal_type,
            MealRecord.recorded_at >= cutoff,
        )
        .all()
    )

    if len(rows) < 3:
        return None

    minutes_of_day = [
        r.recorded_at.astimezone(TZ).hour * 60 + r.recorded_at.astimezone(TZ).minute
        for r in rows
    ]
    avg_min = sum(minutes_of_day) / len(minutes_of_day)
    avg_h, avg_m = divmod(int(round(avg_min)), 60)

    return {
        "pattern_type": "meal_time",
        "pattern_key": meal_type,
        "pattern_value": {"hour": avg_h, "minute": avg_m},
        "confidence": min(1.0, len(rows) / 15.0),
        "sample_count": len(rows),
    }


def _detect_standing_acceptance(user_id: int) -> dict | None:
    """Detect whether user accepts standing reminders in each time slot."""
    cutoff = datetime.now(TZ) - timedelta(days=30)

    rows = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "standing",
            EventHistory.planned_time >= cutoff,
        )
        .all()
    )

    if len(rows) < 5:
        return None

    total = len(rows)
    skipped = sum(1 for r in rows if r.skipped)
    skip_rate = skipped / total

    return {
        "pattern_type": "standing_acceptance",
        "pattern_key": "default",
        "pattern_value": {"total": total, "skipped": skipped, "skip_rate": round(skip_rate, 2)},
        "confidence": min(1.0, total / 15.0),
        "sample_count": total,
    }


def _detect_transit_lead(user_id: int) -> dict | None:
    """Detect average transit lead time in minutes."""
    avg_lead = _transit_lead(user_id)
    if avg_lead is None:
        return None

    cutoff = datetime.now(TZ) - timedelta(days=30)
    sample_count = (
        EventHistory.query
        .filter(
            EventHistory.user_id == user_id,
            EventHistory.notify_type == "transit",
            EventHistory.reminded_at.isnot(None),
            EventHistory.planned_time >= cutoff,
        )
        .count()
    )

    return {
        "pattern_type": "transit_lead",
        "pattern_key": "default",
        "pattern_value": {"minutes": avg_lead},
        "confidence": min(1.0, sample_count / 5.0),
        "sample_count": sample_count,
    }


# ===========================================================================
#  Helpers
# ===========================================================================

def _get_pref(user_id: int, notify_type: str) -> dict | None:
    row = NotifyPreference.query.filter_by(
        user_id=user_id, notify_type=notify_type
    ).first()
    if not row:
        return None
    return {
        "lead_minutes": row.lead_minutes,
        "enabled": row.enabled,
        "quiet_hours_start": row.quiet_hours_start.isoformat() if row.quiet_hours_start else None,
        "quiet_hours_end": row.quiet_hours_end.isoformat() if row.quiet_hours_end else None,
    }


def _upsert_pattern(user_id: int, data: dict) -> UserPattern:
    from ..extensions import db

    existing = UserPattern.query.filter_by(
        user_id=user_id,
        pattern_type=data["pattern_type"],
        pattern_key=data["pattern_key"],
    ).first()

    value_str = json.dumps(data["pattern_value"], ensure_ascii=False, default=str)
    if existing:
        existing.pattern_value = value_str
        existing.confidence = data["confidence"]
        existing.sample_count = data["sample_count"]
        existing.updated_at = datetime.now(timezone.utc)
        return existing

    row = UserPattern(
        user_id=user_id,
        pattern_type=data["pattern_type"],
        pattern_key=data["pattern_key"],
        pattern_value=value_str,
        confidence=data["confidence"],
        sample_count=data["sample_count"],
    )
    db.session.add(row)
    return row


def _summarise_patterns(grouped: dict) -> dict:
    """Generate a short human-readable summary of grouped patterns."""
    parts = []
    for ptype, items in grouped.items():
        if ptype == "wake_time":
            for it in items:
                v = it.get("value", {}) if isinstance(it.get("value"), dict) else {}
                h = v.get("hour")
                m = v.get("minute")
                if h is not None and m is not None:
                    parts.append(f"wake_time={h:02d}:{m:02d}")
        elif ptype == "meal_time":
            for it in items:
                v = it.get("value", {}) if isinstance(it.get("value"), dict) else {}
                h = v.get("hour")
                m = v.get("minute")
                if h is not None and m is not None:
                    parts.append(f"meal({it['key']})={h:02d}:{m:02d}")
        elif ptype == "standing_acceptance":
            for it in items:
                v = it.get("value", {}) if isinstance(it.get("value"), dict) else {}
                parts.append(f"standing(skip_rate)={v.get('skip_rate', '?')}")
        elif ptype == "transit_lead":
            for it in items:
                v = it.get("value", {}) if isinstance(it.get("value"), dict) else {}
                parts.append(f"transit(lead_min)={v.get('minutes', '?')}")
    return {"summary_lines": parts}
