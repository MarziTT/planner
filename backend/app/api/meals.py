"""
Meals API — Jarvis Agent Phase 2 meal module.

POST /api/v1/meals/ocr        — photo → OCR → record
GET  /api/v1/meals/today      — today's meal records
GET  /api/v1/meals/history    — historical meal records
POST /api/v1/meals/manual     — manual meal entry
GET  /api/v1/meals/summary    — today's summary with calories

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §11
"""

from __future__ import annotations

import base64
import logging
from datetime import datetime, timezone

from flask import Blueprint, current_app, g, request

from ..extensions import db, limiter
from ..models_habits import MealRecord
from ..services.meal_service import (
    create_meal_record,
    get_daily_summary,
    get_meal_history,
    get_today_meals,
    get_weekly_average_calories,
    ocr_meal,
)
from .common import auth_required, failure, success

logger = logging.getLogger(__name__)

meals_bp = Blueprint("meals", __name__)


# ---------------------------------------------------------------------------
#  POST /api/v1/meals/ocr
# ---------------------------------------------------------------------------

@meals_bp.post("/meals/ocr")
@auth_required
@limiter.limit("10 per minute; 60 per hour")
def ocr_and_record():
    """Receive an image (base64), run OCR, and create a meal record.

    Request JSON:
        image_base64: string (required) — base64-encoded JPEG/PNG
        meal_type: string (optional) — 'breakfast' / 'lunch' / 'dinner' / 'snack'
        recorded_at: string (optional) — ISO datetime override

    Returns:
        Created meal record with recognized items.
    """
    user_id = g.current_user.id
    payload = request.get_json(silent=True) or {}

    image_b64 = payload.get("image_base64", "")
    if not image_b64:
        return failure("validation_error", "image_base64 is required", status=422)

    try:
        image_bytes = base64.b64decode(image_b64)
    except Exception:
        return failure("validation_error", "Invalid base64 image data", status=422)

    # Phase 1: OCR
    try:
        dishes = ocr_meal(image_bytes, user_id, current_app.config)
    except Exception:
        logger.exception("OCR failed for user %s", user_id)
        return failure("ocr_failed", "OCR 服务暂不可用，请稍后重试", status=500)

    # Infer meal type from time if not given
    meal_type = (payload.get("meal_type") or "").strip()
    if not meal_type:
        hour = datetime.now(timezone.utc).hour
        if 6 <= hour < 10:
            meal_type = "breakfast"
        elif 11 <= hour < 14:
            meal_type = "lunch"
        elif 17 <= hour < 20:
            meal_type = "dinner"
        else:
            meal_type = "snack"

    # Parse recorded_at if given
    recorded_at = None
    raw_time = payload.get("recorded_at")
    if raw_time:
        try:
            recorded_at = datetime.fromisoformat(raw_time)
        except ValueError:
            pass

    # Phase 2: Create record
    record = create_meal_record(
        user_id=user_id,
        meal_type=meal_type,
        items=dishes,
        source="photo",
        recorded_at=recorded_at,
    )

    return success(
        {
            "id": record.id,
            "meal_type": record.meal_type,
            "items": record.items if isinstance(record.items, list) else [],
            "recorded_at": record.recorded_at.isoformat() if record.recorded_at else None,
            "source": record.source,
        },
        status=201,
    )


# ---------------------------------------------------------------------------
#  GET /api/v1/meals/today
# ---------------------------------------------------------------------------

@meals_bp.get("/meals/today")
@auth_required
def today_meals():
    """Get today's meal records."""
    user_id = g.current_user.id
    records = get_today_meals(user_id)
    return success({"records": records, "count": len(records)})


# ---------------------------------------------------------------------------
#  GET /api/v1/meals/history
# ---------------------------------------------------------------------------

@meals_bp.get("/meals/history")
@auth_required
def meal_history():
    """Get meal history for the past N days.

    Query params:
        days: int (default 7)
    """
    user_id = g.current_user.id
    try:
        days = int(request.args.get("days", "7"))
    except ValueError:
        days = 7
    days = max(1, min(days, 90))

    records = get_meal_history(user_id, days=days)
    return success({"records": records, "count": len(records), "days": days})


# ---------------------------------------------------------------------------
#  POST /api/v1/meals/manual
# ---------------------------------------------------------------------------

@meals_bp.post("/meals/manual")
@auth_required
def manual_meal():
    """Manually add a meal record.

    Request JSON:
        meal_type: string (required) — 'breakfast' / 'lunch' / 'dinner' / 'snack'
        items: list[dict] (required) — [{"name": "米饭", "calories": 200}]
        recorded_at: string (optional)
    """
    user_id = g.current_user.id
    payload = request.get_json(silent=True) or {}

    meal_type = (payload.get("meal_type") or "").strip()
    if meal_type not in ("breakfast", "lunch", "dinner", "snack"):
        return failure("validation_error", "meal_type must be breakfast/lunch/dinner/snack", status=422)

    items = payload.get("items")
    if not items or not isinstance(items, list):
        return failure("validation_error", "items must be a non-empty list", status=422)

    recorded_at = None
    raw_time = payload.get("recorded_at")
    if raw_time:
        try:
            recorded_at = datetime.fromisoformat(raw_time)
        except ValueError:
            pass

    record = create_meal_record(
        user_id=user_id,
        meal_type=meal_type,
        items=items,
        source=payload.get("source", "manual"),
        recorded_at=recorded_at,
    )

    return success(
        {
            "id": record.id,
            "meal_type": record.meal_type,
            "items": record.items if isinstance(record.items, list) else [],
            "recorded_at": record.recorded_at.isoformat() if record.recorded_at else None,
            "source": record.source,
        },
        status=201,
    )


# ---------------------------------------------------------------------------
#  GET /api/v1/meals/summary
# ---------------------------------------------------------------------------

@meals_bp.get("/meals/summary")
@auth_required
def daily_summary():
    """Get today's meal summary with calorie totals and weekly average."""
    user_id = g.current_user.id
    summary = get_daily_summary(user_id)
    weekly_avg = get_weekly_average_calories(user_id)
    summary["weekly_avg_calories"] = weekly_avg
    return success(summary)
