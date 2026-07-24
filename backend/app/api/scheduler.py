"""
Scheduler API blueprint — P3-F1: AI-driven schedule optimization.

POST /api/v1/scheduler/suggest   — get optimal time suggestions
POST /api/v1/scheduler/conflicts  — check for time conflicts
"""

from __future__ import annotations

from datetime import datetime

from flask import Blueprint, g, request

from ..services.scheduler_service import detect_conflicts, suggest_times
from .common import auth_required, failure, success

scheduler_bp = Blueprint("scheduler", __name__)


@scheduler_bp.post("/suggest")
@auth_required
def suggest():
    """Suggest optimal time slots for scheduling.

    Request body:
    {
        "date": "2026-07-09",           // required — YYYY-MM-DD
        "duration_minutes": 60,         // optional, default 60
        "preferred_period": "morning"   // optional — morning|afternoon|evening
    }

    Response:
    {
        "ok": true,
        "data": {
            "date": "2026-07-09",
            "duration_minutes": 60,
            "patterns_used": {"wake_hour": 7, "lunch_hour": 12},
            "existing_events": [...],
            "suggestions": [
                {"starts_at": "2026-07-09T09:00:00", "ends_at": "...",
                 "period": "morning", "score": 82}
            ]
        }
    }
    """
    payload = request.get_json(silent=True) or {}

    date_str = (payload.get("date") or "").strip()
    if not date_str:
        return failure("validation_error", "date is required (YYYY-MM-DD)", status=422)

    try:
        date = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return failure("validation_error", "date must be YYYY-MM-DD format", status=422)

    duration = max(15, min(480, int(payload.get("duration_minutes", 60))))
    preferred = payload.get("preferred_period") or None
    if preferred not in (None, "morning", "afternoon", "evening"):
        return failure("validation_error",
                       "preferred_period must be morning/afternoon/evening",
                       status=422)

    result = suggest_times(
        user_id=g.current_user.id,
        date=date,
        duration_minutes=duration,
        preferred_period=preferred,
    )
    return success(result)


@scheduler_bp.post("/conflicts")
@auth_required
def conflicts():
    """Check for scheduling conflicts.

    Request body:
    {
        "starts_at": "2026-07-09T14:00:00",
        "ends_at":   "2026-07-09T15:00:00",
        "exclude_event_id": 123     // optional — ignore this event (for rescheduling)
    }

    Response:
    {
        "ok": true,
        "data": {
            "has_conflicts": true,
            "conflicts": [
                {"id": 1, "title": "周会", "overlap_minutes": 30, ...}
            ]
        }
    }
    """
    payload = request.get_json(silent=True) or {}

    starts_raw = (payload.get("starts_at") or "").strip()
    ends_raw = (payload.get("ends_at") or "").strip()
    if not starts_raw or not ends_raw:
        return failure("validation_error",
                       "starts_at and ends_at are required (ISO8601)",
                       status=422)

    try:
        starts_at = datetime.fromisoformat(starts_raw)
        ends_at = datetime.fromisoformat(ends_raw)
    except ValueError as exc:
        return failure("validation_error",
                       f"Invalid datetime: {exc}",
                       status=422)

    if ends_at <= starts_at:
        return failure("validation_error",
                       "ends_at must be after starts_at",
                       status=422)

    exclude_id = payload.get("exclude_event_id")
    result = detect_conflicts(
        user_id=g.current_user.id,
        starts_at=starts_at,
        ends_at=ends_at,
        exclude_event_id=exclude_id,
    )

    return success({
        "has_conflicts": len(result) > 0,
        "conflicts": result,
    })
