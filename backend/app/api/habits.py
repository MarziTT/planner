"""
Habits API — Jarvis Agent Phase 2 endpoints.

GET  /api/v1/habits/summary          — learned user habits summary
POST /api/v1/habits/skip/<event_id>  — skip a reminder; trigger engine learning
PUT  /api/v1/notify/preferences      — adjust notification preferences

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §6
"""

from __future__ import annotations

import logging
from datetime import datetime, time

from flask import Blueprint, g, request

logger = logging.getLogger(__name__)

from ..extensions import db
from ..models_habits import NotifyPreference
from ..services.habits_engine import (
    detect_patterns,
    get_user_patterns,
    record_event_history,
)
from .common import auth_required, failure, success

habits_bp = Blueprint("habits", __name__)


# ---------------------------------------------------------------------------
#  GET /api/v1/habits/summary
# ---------------------------------------------------------------------------

@habits_bp.get("/habits/summary")
@auth_required
def habits_summary():
    """Return a summary of learned habits for the current user."""
    user_id = g.current_user.id

    # Refresh patterns before returning summary
    try:
        detect_patterns(user_id)
    except Exception as exc:
        logger.warning("detect_patterns failed for user %s: %s", user_id, exc)

    result = get_user_patterns(user_id)

    # Also return notify preferences
    prefs = NotifyPreference.query.filter_by(user_id=user_id).all()
    result["notify_preferences"] = [
        {
            "notify_type": p.notify_type,
            "lead_minutes": p.lead_minutes,
            "enabled": p.enabled,
            "quiet_hours_start": p.quiet_hours_start.isoformat() if p.quiet_hours_start else None,
            "quiet_hours_end": p.quiet_hours_end.isoformat() if p.quiet_hours_end else None,
        }
        for p in prefs
    ]

    return success(result)


# ---------------------------------------------------------------------------
#  POST /api/v1/habits/skip/<event_id>
# ---------------------------------------------------------------------------

@habits_bp.post("/habits/skip/<int:event_id>")
@auth_required
def skip_event(event_id: int):
    """Mark a notification as skipped and record it in event_history."""
    user_id = g.current_user.id

    payload = request.get_json(silent=True) or {}
    planned_time_raw = payload.get("planned_time", "")
    reminded_at_raw = payload.get("reminded_at")
    notify_type = payload.get("notify_type", "standing")

    if not planned_time_raw:
        return failure("validation_error", "planned_time is required", status=422)

    try:
        planned_time = datetime.fromisoformat(planned_time_raw)
    except ValueError as exc:
        return failure("validation_error", f"Invalid planned_time: {exc}", status=422)

    reminded_at = None
    if reminded_at_raw:
        try:
            reminded_at = datetime.fromisoformat(reminded_at_raw)
        except ValueError:
            pass

    delayed_count = payload.get("delayed_count", 0)

    entry = record_event_history(
        event_id=event_id,
        user_id=user_id,
        notify_type=notify_type,
        planned_time=planned_time,
        reminded_at=reminded_at,
        skipped=True,
        delayed_count=delayed_count,
    )

    return success({
        "id": entry.id,
        "event_id": event_id,
        "notify_type": notify_type,
        "skipped": True,
    }, status=201)


# ---------------------------------------------------------------------------
#  PUT /api/v1/notify/preferences
# ---------------------------------------------------------------------------

@habits_bp.put("/notify/preferences")
@auth_required
def update_notify_preferences():
    """Create or update notification preferences for the current user."""
    user_id = g.current_user.id

    payload = request.get_json(silent=True) or {}
    notify_type = payload.get("notify_type", "").strip()
    if not notify_type:
        return failure("validation_error", "notify_type is required", status=422)

    existing = NotifyPreference.query.filter_by(
        user_id=user_id, notify_type=notify_type
    ).first()

    if existing is None:
        existing = NotifyPreference(
            user_id=user_id, notify_type=notify_type
        )
        db.session.add(existing)

    # update fields if provided
    if "lead_minutes" in payload and payload["lead_minutes"] is not None:
        existing.lead_minutes = int(payload["lead_minutes"])

    if "enabled" in payload and payload["enabled"] is not None:
        existing.enabled = bool(payload["enabled"])

    if "quiet_hours_start" in payload:
        val = payload["quiet_hours_start"]
        existing.quiet_hours_start = _parse_time(val) if val else None

    if "quiet_hours_end" in payload:
        val = payload["quiet_hours_end"]
        existing.quiet_hours_end = _parse_time(val) if val else None

    db.session.commit()

    return success({
        "notify_type": existing.notify_type,
        "lead_minutes": existing.lead_minutes,
        "enabled": existing.enabled,
        "quiet_hours_start": existing.quiet_hours_start.isoformat() if existing.quiet_hours_start else None,
        "quiet_hours_end": existing.quiet_hours_end.isoformat() if existing.quiet_hours_end else None,
    })


# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------

def _parse_time(raw: str) -> time:
    """Parse 'HH:MM' or 'HH:MM:SS' into a time object."""
    raw = raw.strip()
    try:
        if len(raw) <= 5:
            return datetime.strptime(raw, "%H:%M").time()
        return datetime.strptime(raw, "%H:%M:%S").time()
    except ValueError:
        raise ValueError(f"Invalid time format: {raw!r}")
