"""
Routine API — Jarvis Agent Phase 2 endpoints.

GET  /api/v1/routine/today           — today's routine timeline
POST /api/v1/routine/wake            — record wake-up time
PUT  /api/v1/routine/wake_time       — manually set wake time
GET  /api/v1/routine/standing_status — standing reminder status

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md
"""

from __future__ import annotations

from flask import Blueprint, g, request

from ..services.routine_service import (
    get_routine_today,
    get_standing_status,
    record_wake,
    update_wake_time,
)
from .common import auth_required, failure, success

routine_bp = Blueprint("routine", __name__)


# ---------------------------------------------------------------------------
#  GET /api/v1/routine/today
# ---------------------------------------------------------------------------


@routine_bp.get("/routine/today")
@auth_required
def routine_today():
    """Return today's routine: wake time, sleep time, standing status, timeline."""
    user_id = g.current_user.id
    result = get_routine_today(user_id)
    return success(result)


# ---------------------------------------------------------------------------
#  POST /api/v1/routine/wake
# ---------------------------------------------------------------------------


@routine_bp.post("/routine/wake")
@auth_required
def record_wake_time():
    """Record today's wake-up time. Accepts optional 'wake_time' (HH:MM) in JSON body;
    if omitted, uses the current time as wake-up timestamp."""
    user_id = g.current_user.id

    payload = request.get_json(silent=True) or {}
    wake_time_raw = payload.get("wake_time")

    try:
        result = record_wake(user_id, wake_time_raw)
    except ValueError as exc:
        return failure("validation_error", str(exc), status=422)

    return success(result, status=201)


# ---------------------------------------------------------------------------
#  PUT /api/v1/routine/wake_time
# ---------------------------------------------------------------------------


@routine_bp.put("/routine/wake_time")
@auth_required
def set_wake_time():
    """Manually override the learned wake-up time. Expects {hour: int, minute: int}."""
    user_id = g.current_user.id

    payload = request.get_json(silent=True) or {}
    hour = payload.get("hour")
    minute = payload.get("minute")

    if hour is None or minute is None:
        return failure("validation_error", "hour and minute are required", status=422)

    try:
        hour = int(hour)
        minute = int(minute)
    except (ValueError, TypeError):
        return failure("validation_error", "hour and minute must be integers", status=422)

    try:
        result = update_wake_time(user_id, hour, minute)
    except ValueError as exc:
        return failure("validation_error", str(exc), status=422)

    return success(result)


# ---------------------------------------------------------------------------
#  GET /api/v1/routine/standing_status
# ---------------------------------------------------------------------------


@routine_bp.get("/routine/standing_status")
@auth_required
def standing_status():
    """Return current standing reminder status for the user."""
    user_id = g.current_user.id
    result = get_standing_status(user_id)
    return success(result)
