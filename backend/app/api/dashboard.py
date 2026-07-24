"""
Dashboard API — Jarvis Agent Phase 2.

GET /api/v1/dashboard/overview — aggregate all 6 domains + pattern announcement.
GET /api/v1/dashboard/health — multi-day health trends (JSON).
GET /api/v1/dashboard/health-csv — multi-day health trends (CSV download).

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md
"""

from __future__ import annotations

import csv
import io

from flask import Blueprint, g, request, Response

from .common import auth_required, success
from ..services.dashboard_service import get_dashboard_overview
from ..services.health_service import get_health_trends

dashboard_bp = Blueprint("dashboard", __name__)


@dashboard_bp.get("/dashboard/overview")
@auth_required
def overview():
    """Return aggregated dashboard data for all 6 life domains.

    Query params (optional):
        lat: float — latitude for weather
        lon: float — longitude for weather

    Returns:
        date, schedule, weather, routine, meals, exercise, transit, pattern_announcement
    """
    user_id = g.current_user.id

    lat = None
    lon = None
    try:
        lat_str = request.args.get("lat", "").strip()
        lon_str = request.args.get("lon", "").strip()
        if lat_str and lon_str:
            lat = float(lat_str)
            lon = float(lon_str)
    except (ValueError, TypeError):
        pass

    data = get_dashboard_overview(user_id, lat=lat, lon=lon)
    return success(data)


@dashboard_bp.get("/dashboard/health")
@auth_required
def health():
    """Return multi-day health trends for exercise, meals, routine, and standing.

    Query params (optional):
        days: int — lookback window (default 7, max 90)

    Returns:
        period, exercise{daily[], summary}, meals{daily[], summary},
        routine{daily[], summary}, standing{daily[], summary}
    """
    user_id = g.current_user.id
    days = request.args.get("days", 7, type=int)
    data = get_health_trends(user_id, days=days)
    return success(data)


@dashboard_bp.get("/dashboard/health-csv")
@auth_required
def health_csv():
    """Export health trends as a CSV file download.

    Query params (optional):
        days: int — lookback window (default 7, max 90)

    Returns:
        text/csv attachment with one row per day per domain.
    """
    user_id = g.current_user.id
    days = request.args.get("days", 7, type=int)
    data = get_health_trends(user_id, days=days)

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "date", "exercise_minutes", "exercise_calories", "exercise_steps",
        "meal_calories", "meal_count", "breakfast_cal", "lunch_cal",
        "dinner_cal", "snack_cal", "protein_g", "carb_g", "fat_g",
        "wake_time", "sleep_time", "sleep_hours",
        "standing_total", "standing_completed", "standing_skipped",
        "standing_rate",
    ])

    ex_daily = data.get("exercise", {}).get("daily", [])
    ml_daily = data.get("meals", {}).get("daily", [])
    rt_daily = data.get("routine", {}).get("daily", [])
    st_daily = data.get("standing", {}).get("daily", [])

    for i in range(len(ex_daily)):
        ex = ex_daily[i] if i < len(ex_daily) else {}
        ml = ml_daily[i] if i < len(ml_daily) else {}
        rt = rt_daily[i] if i < len(rt_daily) else {}
        st = st_daily[i] if i < len(st_daily) else {}
        writer.writerow([
            ex.get("date", ""),
            ex.get("total_minutes", 0),
            ex.get("total_calories", 0),
            ex.get("total_steps", 0),
            ml.get("total_calories", 0),
            ml.get("meal_count", 0),
            ml.get("breakfast", 0),
            ml.get("lunch", 0),
            ml.get("dinner", 0),
            ml.get("snack", 0),
            ml.get("protein_g", 0),
            ml.get("carb_g", 0),
            ml.get("fat_g", 0),
            rt.get("wake_time", ""),
            rt.get("sleep_time", ""),
            rt.get("sleep_hours", ""),
            st.get("total", 0),
            st.get("completed", 0),
            st.get("skipped", 0),
            st.get("completion_rate", 0),
        ])

    csv_data = output.getvalue()
    period = data.get("period", {})
    filename = f"health_{period.get('start', '')}_{period.get('end', '')}.csv"
    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
