"""
Notification API — P3-F3 smart push insights & history.

GET  /api/v1/notify/insights   —  smart notification content suggestions
GET  /api/v1/notify/history    —  notification event history
"""

from __future__ import annotations

import logging
from datetime import timedelta

from flask import Blueprint, g, request

from ..services.smart_notify_service import generate_insights, get_notify_history
from ..extensions import db
from ..models_habits import EventHistory
from ..services.time_service import get_clock
from .common import auth_required, failure, success

logger = logging.getLogger(__name__)

notify_bp = Blueprint("notifications", __name__)


@notify_bp.post("/notify/decision")
@auth_required
def notify_decision():
    """Persist a smart-notification action across app restarts and devices."""
    payload = request.get_json(silent=True) or {}
    dedupe_key = str(payload.get("dedupe_key") or "").strip()
    action = str(payload.get("action") or "").strip()
    if not dedupe_key or action not in {"snooze", "dismiss_today", "completed"}:
        return failure("validation_error", "dedupe_key and a valid action are required", status=422)

    now = get_clock().now_local()
    try:
        minutes = max(1, min(int(payload.get("minutes") or 30), 24 * 60))
    except (TypeError, ValueError):
        return failure("validation_error", "minutes must be an integer", status=422)
    entry = EventHistory(
        user_id=g.current_user.id,
        notify_type=f"insight:{dedupe_key}",
        planned_time=now + timedelta(minutes=minutes) if action == "snooze" else now,
        reminded_at=now,
        completed_at=now if action == "completed" else None,
        skipped=action == "dismiss_today",
        delayed_count=1 if action == "snooze" else 0,
    )
    db.session.add(entry)
    db.session.commit()
    return success({"accepted": True, "action": action, "resume_at": entry.planned_time.isoformat()})


# ---------------------------------------------------------------------------
#  GET /api/v1/notify/insights
# ---------------------------------------------------------------------------

@notify_bp.get("/notify/insights")
@auth_required
def notify_insights():
    """Return smart notification content suggestions for the current user.

    The Flutter client polls this endpoint periodically (e.g. every 30 min)
    and schedules local notifications for any new insights.

    Response:
      { ok: true, data: { user_id, generated_at, count, insights: [...] } }
    """
    user_id = g.current_user.id

    try:
        result = generate_insights(user_id)
    except Exception as exc:
        logger.exception("generate_insights failed for user %s", user_id)
        # Soft-fail: return empty insights so the client doesn't break
        result = {
            "user_id": user_id,
            "generated_at": None,
            "count": 0,
            "insights": [],
            "_error": str(exc),
        }

    return success(result)


# ---------------------------------------------------------------------------
#  GET /api/v1/notify/history
# ---------------------------------------------------------------------------

@notify_bp.get("/notify/history")
@auth_required
def notify_history():
    """Return notification event history for the current user.

    Query params:
      notify_type  — optional filter (transit/standing/meal/exercise/sleep)
      days         — lookback window in days (default 7, max 30)
      limit        — max entries returned (default 50, max 200)

    Response:
      { ok: true, data: { user_id, total, skipped, completed, entries: [...] } }
    """
    user_id = g.current_user.id

    notify_type = request.args.get("notify_type", "").strip() or None
    try:
        days = int(request.args.get("days", 7))
    except (TypeError, ValueError):
        days = 7
    days = max(1, min(days, 30))

    try:
        limit = int(request.args.get("limit", 50))
    except (TypeError, ValueError):
        limit = 50
    limit = max(1, min(limit, 200))

    result = get_notify_history(
        user_id,
        notify_type=notify_type,
        days=days,
        limit=limit,
    )
    return success(result)
