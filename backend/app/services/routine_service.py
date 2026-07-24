"""
Routine service — Jarvis Agent Phase 2.

Wake time tracking, sleep/standing reminder scheduling, daily timeline.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md
"""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta, time, timezone

from ..extensions import db
from ..models_habits import EventHistory, UserPattern

logger = logging.getLogger(__name__)

TZ = timezone(timedelta(hours=8))

# Default routine window
DEFAULT_WAKE_HOUR = 7
DEFAULT_WAKE_MINUTE = 30
DEFAULT_SLEEP_HOUR = 23
DEFAULT_SLEEP_MINUTE = 30
DEFAULT_STANDING_INTERVAL_MINUTES = 45
DEFAULT_STANDING_START = time(9, 0)
DEFAULT_STANDING_END = time(18, 0)


def get_routine_today(user_id: int) -> dict:
    """Return today's routine data including wake time, sleep time, and standing status."""

    wake = _get_wake_time(user_id)
    wake_h, wake_m = wake["hour"], wake["minute"]

    # Sleep time = wake - 8h
    wake_dt = datetime.combine(date.today(), time(wake_h, wake_m))
    sleep_dt = wake_dt - timedelta(hours=8)
    sleep_h = sleep_dt.hour
    sleep_m = sleep_dt.minute

    # Sleep reminder = sleep_time - 30min
    remind_dt = sleep_dt - timedelta(minutes=30)
    remind_h = remind_dt.hour
    remind_m = remind_dt.minute

    # Standing status
    standing = _get_standing_status(user_id)

    # Today's routine timeline
    timeline = [
        {"time": f"{wake_h:02d}:{wake_m:02d}", "label": "起床"},
        {"time": f"{remind_h:02d}:{remind_m:02d}", "label": "入睡提醒"},
        {"time": f"{sleep_h:02d}:{sleep_m:02d}", "label": "预计入睡"},
    ]

    return {
        "date": date.today().isoformat(),
        "wake_time": {"hour": wake_h, "minute": wake_m, "source": wake["source"]},
        "sleep_time": {"hour": sleep_h, "minute": sleep_m},
        "sleep_reminder": {"hour": remind_h, "minute": remind_m},
        "standing": standing,
        "timeline": timeline,
    }


def record_wake(user_id: int, wake_time: str | None = None) -> dict:
    """Record today's wake-up time.  If *wake_time* is not given, use now."""

    now = datetime.now(TZ)
    if wake_time:
        try:
            parsed = datetime.strptime(wake_time.strip(), "%H:%M").time()
            now = datetime.combine(date.today(), parsed, tzinfo=TZ)
        except ValueError:
            raise ValueError(f"Invalid time format: {wake_time!r}, expected HH:MM")

    # Upsert UserPattern (wake_time / today)
    pattern = _upsert_wake_time(user_id, now.hour, now.minute)

    return {
        "hour": now.hour,
        "minute": now.minute,
        "recorded_at": now.isoformat(),
        "confidence": pattern.confidence if pattern else 0.0,
    }


def update_wake_time(user_id: int, hour: int, minute: int) -> dict:
    """Manually set the user's wake time."""

    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise ValueError(f"Invalid time: {hour}:{minute:02d}")

    pattern = _upsert_wake_time(user_id, hour, minute)

    return {
        "hour": hour,
        "minute": minute,
        "source": "manual",
        "confidence": pattern.confidence if pattern else 1.0,
    }


def get_standing_status(user_id: int) -> dict:
    return _get_standing_status(user_id)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _get_wake_time(user_id: int) -> dict:
    """Get user's wake time from learned patterns or defaults."""
    row = UserPattern.query.filter_by(
        user_id=user_id,
        pattern_type="wake_time",
        pattern_key="default",
    ).first()

    if row and row.pattern_value:
        try:
            v = row.pattern_value if isinstance(row.pattern_value, dict) else json.loads(row.pattern_value)
            h = int(v.get("hour", DEFAULT_WAKE_HOUR))
            m = int(v.get("minute", DEFAULT_WAKE_MINUTE))
            return {"hour": h, "minute": m, "source": "learned"}
        except Exception:
            logger.warning("Failed to parse wake_time pattern value: %s", row.pattern_value)

    return {"hour": DEFAULT_WAKE_HOUR, "minute": DEFAULT_WAKE_MINUTE, "source": "default"}


def _get_standing_status(user_id: int) -> dict:
    """Return standing reminder status for today."""

    today = date.today()
    today_start = datetime.combine(today, time(0, 0), tzinfo=TZ)
    today_end = datetime.combine(today, time(23, 59, 59), tzinfo=TZ)

    # Count today's standing events
    today_events = EventHistory.query.filter(
        EventHistory.user_id == user_id,
        EventHistory.notify_type == "standing",
        EventHistory.planned_time >= today_start,
        EventHistory.planned_time <= today_end,
    ).all()

    total = len(today_events)
    skipped = sum(1 for e in today_events if e.skipped)

    # Check last 5 for auto-stop
    recent_5 = EventHistory.query.filter(
        EventHistory.user_id == user_id,
        EventHistory.notify_type == "standing",
    ).order_by(EventHistory.planned_time.desc()).limit(5).all()

    auto_stopped = len(recent_5) >= 5 and all(r.skipped for r in recent_5)

    return {
        "enabled": not auto_stopped,
        "interval_minutes": DEFAULT_STANDING_INTERVAL_MINUTES,
        "start_time": DEFAULT_STANDING_START.strftime("%H:%M"),
        "end_time": DEFAULT_STANDING_END.strftime("%H:%M"),
        "today_total": total,
        "today_skipped": skipped,
        "auto_stopped": auto_stopped,
        "consecutive_skips": sum(1 for r in recent_5 if r.skipped) if recent_5 else 0,
    }


def _upsert_wake_time(user_id: int, hour: int, minute: int) -> UserPattern | None:
    """Upsert a wake_time pattern for *user_id*."""

    from ..models_habits import UserPattern

    existing = UserPattern.query.filter_by(
        user_id=user_id,
        pattern_type="wake_time",
        pattern_key="default",
    ).first()

    value_str = json.dumps({"hour": hour, "minute": minute})

    if existing:
        existing.pattern_value = value_str
        existing.confidence = 1.0
        existing.sample_count = existing.sample_count + 1
        existing.updated_at = datetime.now(timezone.utc)
    else:
        existing = UserPattern(
            user_id=user_id,
            pattern_type="wake_time",
            pattern_key="default",
            pattern_value=value_str,
            confidence=1.0,
            sample_count=1,
        )
        db.session.add(existing)

    db.session.commit()
    return existing
