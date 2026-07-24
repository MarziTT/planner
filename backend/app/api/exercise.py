"""
Exercise API — mode management, record creation, daily summary.

Blueprint: exercise_bp
Base path: /api/v1/exercise
"""

from __future__ import annotations

import logging
from datetime import datetime

from flask import Blueprint, request

from .common import auth_required, failure, success
from ..extensions import db
from ..models import User
from ..services import exercise_service

logger = logging.getLogger(__name__)

exercise_bp = Blueprint("exercise", __name__)


# ---------------------------------------------------------------------------
# GET /api/v1/exercise/today — 今日运动汇总
# ---------------------------------------------------------------------------


@exercise_bp.route("/today", methods=["GET"])
@auth_required
def get_today(user: User):
    try:
        summary = exercise_service.get_today_summary(user.id)
        return success(data=summary)
    except Exception:
        logger.exception("Exercise today failed")
        return failure("exercise_today_failed", "Internal server error", status=500)


# ---------------------------------------------------------------------------
# POST /api/v1/exercise/record — 手动/自动记录运动
# ---------------------------------------------------------------------------


@exercise_bp.route("/record", methods=["POST"])
@auth_required
def create_record(user: User):
    try:
        body = request.get_json(silent=True) or {}
        exercise_type = body.get("exercise_type", "").strip()
        duration_minutes = body.get("duration_minutes", 0)
        source = body.get("source", "manual")
        calories = body.get("calories")
        steps = body.get("steps")
        recorded_at_str = body.get("recorded_at")

        if not exercise_type:
            return failure("missing_field", "exercise_type is required")

        if not isinstance(duration_minutes, int) or duration_minutes <= 0:
            return failure("invalid_duration", "duration_minutes must be a positive integer")

        recorded_at = None
        if recorded_at_str:
            try:
                recorded_at = datetime.fromisoformat(recorded_at_str)
            except ValueError:
                return failure("invalid_date", "recorded_at format invalid")

        record = exercise_service.create_record(
            user_id=user.id,
            exercise_type=exercise_type,
            duration_minutes=duration_minutes,
            source=source,
            calories=calories,
            steps=steps,
            recorded_at=recorded_at,
        )
        return success(data=exercise_service._record_to_dict(record))
    except Exception:
        logger.exception("Exercise record failed")
        return failure("exercise_record_failed", "Internal server error", status=500)


# ---------------------------------------------------------------------------
# GET /api/v1/exercise/mode — 获取当前模式
# ---------------------------------------------------------------------------


@exercise_bp.route("/mode", methods=["GET"])
@auth_required
def get_mode(user: User):
    try:
        mode_info = exercise_service.get_current_mode(user)
        return success(data=mode_info)
    except Exception:
        logger.exception("Exercise mode get failed")
        return failure("exercise_mode_failed", "Internal server error", status=500)


# ---------------------------------------------------------------------------
# PUT /api/v1/exercise/mode — 切换运动模式
# ---------------------------------------------------------------------------


@exercise_bp.route("/mode", methods=["PUT"])
@auth_required
def set_mode(user: User):
    try:
        body = request.get_json(silent=True) or {}
        exercise_mode = body.get("exercise_mode", "").strip()
        trainer_end_date = body.get("trainer_end_date")

        if exercise_mode not in ("self", "trainer"):
            return failure("invalid_mode", "exercise_mode must be 'self' or 'trainer'")

        mode_info = exercise_service.set_mode(
            user=user,
            exercise_mode=exercise_mode,
            trainer_end_date=trainer_end_date,
        )
        return success(data=mode_info)
    except Exception:
        logger.exception("Exercise mode set failed")
        return failure("exercise_mode_set_failed", "Internal server error", status=500)


# ---------------------------------------------------------------------------
# GET /api/v1/exercise/history?days=7 — 历史记录
# ---------------------------------------------------------------------------


@exercise_bp.route("/history", methods=["GET"])
@auth_required
def get_history(user: User):
    try:
        days = request.args.get("days", "7")
        try:
            days = min(int(days), 90)
        except (ValueError, TypeError):
            days = 7

        history = exercise_service.get_history(user.id, days=days)
        return success(data=history)
    except Exception:
        logger.exception("Exercise history failed")
        return failure("exercise_history_failed", "Internal server error", status=500)
