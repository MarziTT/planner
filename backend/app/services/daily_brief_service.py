"""Personalized daily life brief assembled from existing dashboard domains."""

from __future__ import annotations

from typing import Any

from .dashboard_service import get_dashboard_overview


def build_daily_brief(user_id: int, *, lat: float | None = None, lon: float | None = None) -> dict[str, Any]:
    overview = get_dashboard_overview(user_id, lat=lat, lon=lon)
    weather = overview.get("weather") or {}
    schedule = overview.get("schedule") or {}
    exercise = overview.get("exercise") or {}
    meals = overview.get("meals") or {}
    routine = overview.get("routine") or {}

    parts: list[str] = []
    if weather.get("available"):
        condition = weather.get("condition", "天气")
        high, low = weather.get("high", "--"), weather.get("low", "--")
        parts.append(f"今天{condition}，{low}–{high}℃。")
        if weather.get("rain") or "雨" in str(condition):
            parts.append("出门记得带伞。")
    upcoming = schedule.get("upcoming") or []
    if upcoming:
        first = upcoming[0]
        parts.append(f"最近安排是 {first.get('time', '')} 的{first.get('title', '日程')}。")
    elif schedule.get("pending_count", 0) == 0:
        parts.append("今天暂时没有固定安排。")
    if exercise.get("total_minutes", 0) >= 30:
        parts.append("今天运动已经达标，保持得很好。")
    elif exercise.get("total_minutes", 0) == 0:
        parts.append("今天还没有运动记录，晚些时候可以散步一会儿。")
    if meals.get("meal_count", 0) == 0:
        parts.append("今天还没有饮食记录，下一餐记得补充记录。")
    elif meals.get("total_calories", 0) > 0:
        parts.append(f"今天已记录约 {meals['total_calories']} kcal。")
    if routine.get("auto_stopped"):
        parts.append("站立提醒今天已自动停止，可以按需恢复。")

    summary = "".join(parts) or "今天一切平稳，按自己的节奏推进就好。"
    return {
        "date": overview.get("date"),
        "summary": summary,
        "compact_summary": summary[:120],
        "sections": {
            "weather": weather,
            "schedule": schedule,
            "exercise": exercise,
            "meals": meals,
            "routine": routine,
        },
    }
