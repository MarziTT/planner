"""
Widget API — PixelPlanner P3-F9.

GET /api/v1/widget/summary — return compact daily summary for home screen widget.
"""

from __future__ import annotations

from flask import Blueprint, g

from .common import auth_required, success
from ..services.widget_service import get_widget_summary

widget_bp = Blueprint("widget", __name__)


@widget_bp.get("/widget/summary")
@auth_required
def summary():
    """Return a compact daily summary for the Android home screen widget.

    Returns header, meals, exercise, schedule, and health in a flat structure.
    """
    user_id = g.current_user.id
    data = get_widget_summary(user_id)
    return success(data)
