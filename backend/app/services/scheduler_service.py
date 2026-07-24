"""
Scheduler Service — P3-F1: AI-driven schedule optimization engine.

Capabilities:
1. Conflict detection  — find time overlaps against existing events
2. Smart slot scoring   — rank candidate time slots by convenience
3. Schedule suggestions — recommend optimal slots based on user patterns

Uses: UserPattern (wake/meal times), Event (existing commitments)
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from ..extensions import db
from ..models import Event
from ..models_habits import UserPattern


# ---------------------------------------------------------------------------
#  Public API
# ---------------------------------------------------------------------------


def detect_conflicts(
    user_id: int,
    starts_at: datetime,
    ends_at: datetime,
    exclude_event_id: int | None = None,
) -> list[dict[str, Any]]:
    """Return all planned events that overlap with [starts_at, ends_at)."""
    query = Event.query.filter(
        Event.user_id == user_id,
        Event.status == "planned",
        Event.starts_at < ends_at,
        Event.ends_at > starts_at,
    )
    if exclude_event_id is not None:
        query = query.filter(Event.id != exclude_event_id)

    return [
        {
            "id": e.id,
            "title": e.title,
            "starts_at": e.starts_at.isoformat(),
            "ends_at": e.ends_at.isoformat(),
            "overlap_minutes": _overlap_minutes(starts_at, ends_at, e.starts_at, e.ends_at),
        }
        for e in query.order_by(Event.starts_at).all()
    ]


def suggest_times(
    user_id: int,
    date: datetime,
    duration_minutes: int = 60,
    preferred_period: str | None = None,
) -> dict[str, Any]:
    """Recommend optimal time slots for a given date.

    Args:
        user_id: target user
        date: which day to schedule (only the date part is used)
        duration_minutes: how long the event should be
        preferred_period: "morning" / "afternoon" / "evening" (optional)

    Returns:
        {
            "date": "2026-07-09",
            "duration_minutes": 60,
            "patterns_used": {...},
            "existing_events": [...],
            "conflicts_with_existing": [...],
            "suggestions": [{starts_at, ends_at, period, score}, ...]
        }
    """
    # Normalize to date
    day_start = date.replace(hour=0, minute=0, second=0, microsecond=0)

    patterns = _load_patterns(user_id)
    existing = _load_day_events(user_id, day_start)

    # Generate candidate slots
    wake_hour = patterns.get("wake_hour", 7)
    candidates = _generate_slots(day_start, wake_hour, duration_minutes, preferred_period, existing)

    # Score each candidate
    scored = []
    for slot in candidates:
        s = _score_slot(slot, day_start, patterns, existing)
        scored.append({**slot, "score": s})

    scored.sort(key=lambda x: (-x["score"], x["starts_at"]))

    return {
        "date": day_start.strftime("%Y-%m-%d"),
        "duration_minutes": duration_minutes,
        "patterns_used": _summarize_patterns(patterns),
        "existing_events": [
            {"title": e["title"], "starts_at": e["starts_at"].isoformat(), "ends_at": e["ends_at"].isoformat()}
            for e in existing
        ],
        "conflicts_with_existing": len(existing),
        "suggestions": scored[:5],
    }


# ---------------------------------------------------------------------------
#  Internal — pattern loading
# ---------------------------------------------------------------------------


def _load_patterns(user_id: int) -> dict[str, Any]:
    """Extract scheduling-relevant patterns for a user."""
    result: dict[str, Any] = {
        "wake_hour": 7,
        "wake_minute": 0,
    }
    for p in UserPattern.query.filter_by(user_id=user_id).all():
        val = p.pattern_value or {}
        if p.pattern_type == "wake_time":
            result["wake_hour"] = val.get("hour", 7)
            result["wake_minute"] = val.get("minute", 0)
        elif p.pattern_type == "meal_time":
            result[f"{p.pattern_key}_hour"] = val.get("hour")
            result[f"{p.pattern_key}_minute"] = val.get("minute", 0)
        elif p.pattern_type == "transit_lead":
            result["transit_lead_minutes"] = val.get("minutes", 30)
    return result


def _load_day_events(user_id: int, day_start: datetime) -> list[dict[str, Any]]:
    """Return all planned events that fall on *day_start*'s date."""
    day_end = day_start + timedelta(days=1)
    events = (
        Event.query.filter(
            Event.user_id == user_id,
            Event.status == "planned",
            Event.starts_at < day_end,
            Event.ends_at > day_start,
        )
        .order_by(Event.starts_at)
        .all()
    )
    return [
        {"title": e.title, "starts_at": _normalize_dt(e.starts_at), "ends_at": _normalize_dt(e.ends_at)}
        for e in events
    ]


# ---------------------------------------------------------------------------
#  Internal — slot generation
# ---------------------------------------------------------------------------

# Time windows (start_hour, end_hour) for each period.
_PERIOD_WINDOWS: dict[str, list[tuple[int, int]]] = {
    "morning":   [(7, 12)],
    "afternoon": [(13, 18)],
    "evening":   [(18, 22)],
}


def _generate_slots(
    day_start: datetime,
    wake_hour: int,
    duration_minutes: int,
    preferred_period: str | None,
    existing: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Generate non-conflicting time slots for the day."""

    if preferred_period and preferred_period in _PERIOD_WINDOWS:
        windows = _PERIOD_WINDOWS[preferred_period]
    else:
        windows = _PERIOD_WINDOWS["morning"] + _PERIOD_WINDOWS["afternoon"] + _PERIOD_WINDOWS["evening"]

    # Don't start before (wake_hour + 1)
    effective_start = max(wake_hour + 1, 7)

    slots: list[dict[str, Any]] = []
    duration_hours = duration_minutes / 60.0

    for win_start, win_end in windows:
        start_hour = max(win_start, effective_start)
        hour = start_hour
        while hour + duration_hours <= win_end:
            slot_start = day_start.replace(hour=hour, minute=0, second=0, microsecond=0)
            slot_end = slot_start + timedelta(minutes=duration_minutes)

            if not _overlaps_any(slot_start, slot_end, existing):
                slots.append({
                    "starts_at": slot_start.isoformat(),
                    "ends_at": slot_end.isoformat(),
                    "period": _period_for_hour(hour),
                })

            hour += 1  # granularity: 1 hour

    return slots


def _overlaps_any(
    start: datetime, end: datetime, existing: list[dict[str, Any]]
) -> bool:
    for ev in existing:
        if start < ev["ends_at"] and end > ev["starts_at"]:
            return True
    return False


# ---------------------------------------------------------------------------
#  Internal — scoring
# ---------------------------------------------------------------------------


def _score_slot(
    slot: dict[str, Any],
    day_start: datetime,
    patterns: dict[str, Any],
    existing: list[dict[str, Any]],
) -> int:
    """Score a time slot 0–100.  Higher = more convenient."""
    start = datetime.fromisoformat(slot["starts_at"])
    hour = start.hour
    score = 70.0

    # ── Penalty: within 1h of waking ──
    wake_h = patterns.get("wake_hour", 7)
    if hour <= wake_h + 1:
        score -= 15

    # ── Penalty: overlapping meal windows (±1h) ──
    for meal_key in ("breakfast", "lunch", "dinner"):
        mh = patterns.get(f"{meal_key}_hour")
        if mh is not None and abs(float(hour) - float(mh)) <= 1:
            score -= 12

    # ── Penalty: late evening ──
    if hour >= 21:
        score -= 10
    elif hour >= 20:
        score -= 5

    # ── Bonus: ideal focus hours ──
    if 9 <= hour <= 11:
        score += 12
    elif 14 <= hour <= 16:
        score += 12
    elif 17 <= hour <= 19:
        score += 5

    # ── Penalty: tight buffer with existing events (<30 min gap) ──
    for ev in existing:
        gap_before = int((start - ev["ends_at"]).total_seconds() / 60)
        gap_after = int((ev["starts_at"] - start).total_seconds() / 60)
        if 0 < gap_before < 30 or 0 < gap_after < 30:
            score -= 8
            break

    return max(0, min(100, round(score)))


# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------


def _period_for_hour(hour: int) -> str:
    if hour < 12:
        return "morning"
    if hour < 18:
        return "afternoon"
    return "evening"


def _summarize_patterns(patterns: dict[str, Any]) -> dict[str, Any]:
    """Return only non-None pattern values for the response."""
    return {k: v for k, v in patterns.items() if v is not None}


def _normalize_dt(dt: datetime) -> datetime:
    """Strip timezone info to enable comparison of naive and aware datetimes."""
    return dt.replace(tzinfo=None) if dt.tzinfo is not None else dt


def _overlap_minutes(
    a_start: datetime, a_end: datetime, b_start: datetime, b_end: datetime
) -> int:
    a_start = _normalize_dt(a_start)
    a_end = _normalize_dt(a_end)
    b_start = _normalize_dt(b_start)
    b_end = _normalize_dt(b_end)
    overlap_start = max(a_start, b_start)
    overlap_end = min(a_end, b_end)
    return max(0, int((overlap_end - overlap_start).total_seconds() / 60))
