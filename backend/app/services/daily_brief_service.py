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
    comfort: list[str] = []
    travel: list[str] = []
    if weather.get("available"):
        condition = weather.get("condition", "天气")
        high, low = weather.get("high", "--"), weather.get("low", "--")
        parts.append(f"今天{condition}，{low}–{high}℃。")
        if weather.get("rain") or "雨" in str(condition):
            travel.append("带伞")
        temp_high = _number(weather.get("high"))
        temp_low = _number(weather.get("low"))
        if temp_high is not None and temp_high >= 30:
            comfort.append("天气偏热，注意补水")
        if temp_low is not None and temp_low <= 10:
            comfort.append("天气偏冷，出门加外套")
        humidity = _number(weather.get("humidity"))
        if humidity is not None and humidity >= 80:
            comfort.append("湿度较高，注意通风")
        uv = _number(weather.get("uv_index"))
        if uv is not None and uv >= 6:
            comfort.append("紫外线较强，注意防晒")
        air_quality = _number(weather.get("air_quality_index"))
        if air_quality is not None and air_quality >= 100:
            travel.append("空气质量一般，减少户外剧烈运动")
    upcoming = schedule.get("upcoming") or []
    if upcoming:
        first = upcoming[0]
        parts.append(f"最近安排是 {first.get('time', '')} 的{first.get('title', '日程')}。")
        if first.get("time"):
            travel.append(f"至少提前 15 分钟准备 {first.get('title', '日程')}")
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
    sleep_hours = _number(routine.get("sleep_hours"))
    if sleep_hours is not None and sleep_hours < 6:
        parts.append("昨晚睡眠不足，今天运动以散步和拉伸为主。")
        comfort.append("优先补充休息")
    if routine.get("auto_stopped"):
        parts.append("站立提醒今天已自动停止，可以按需恢复。")
    if comfort:
        parts.append("；".join(comfort) + "。")
    if travel:
        parts.append("出行提示：" + "，".join(travel) + "。")

    summary = "".join(parts) or "今天一切平稳，按自己的节奏推进就好。"
    return {
        "date": overview.get("date"),
        "summary": summary,
        "compact_summary": summary[:120],
        "comfort_tips": comfort,
        "travel_tips": travel,
        "sections": {
            "weather": weather,
            "schedule": schedule,
            "exercise": exercise,
            "meals": meals,
            "routine": routine,
        },
    }


def _number(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
