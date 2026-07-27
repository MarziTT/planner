"""
天气 API 端点。

- GET /                    — 当前天气、今日预报和未来逐时天气（保留兼容）
- GET /smart-advisory      — 天气智能管家：天气 + 日程 → LLM 行动建议
"""

from __future__ import annotations

import logging
from datetime import datetime

from flask import Blueprint, current_app, g, request

from ..services import weather_service as ws
from ..services.scheduler_service import _load_day_events
from ..extensions import db
from .common import auth_required, failure, success

weather_bp = Blueprint("weather", __name__)

logger = logging.getLogger(__name__)


# ---- 辅助 ----

def _parse_lat_lon() -> tuple | tuple[None, None, int]:
    """从 query string 解析 lat/lon。成功返回 (lat, lon)，失败返回 (None, None, status)。"""
    lat_str = (request.args.get("lat") or "").strip()
    lon_str = (request.args.get("lon") or "").strip()
    if not lat_str or not lon_str:
        return None, None, 422
    try:
        return float(lat_str), float(lon_str)
    except ValueError:
        return None, None, 422


def _openai_config() -> dict:
    """从 current_app.config 读取 OpenAI 相关配置。"""
    return {
        "OPENAI_API_KEY": current_app.config.get("OPENAI_API_KEY", ""),
        "OPENAI_BASE_URL": current_app.config.get("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        "OPENAI_MODEL": current_app.config.get("OPENAI_MODEL", "gpt-4o-mini"),
    }


# ---- 端点 ----

@weather_bp.get("/")
@auth_required
def weather_now():
    """获取指定经纬度的当前天气、今日预报和未来逐时天气。

    数据源：Open-Meteo + OpenAQ（自适应降级）。
    """
    parsed = _parse_lat_lon()
    if len(parsed) == 3:
        _, _, status = parsed
        return failure("validation_error", "lat and lon are required and must be numbers", status=status)
    lat, lon = parsed

    try:
        openaq_key = current_app.config.get("OPENAQ_API_KEY")
        weather = ws.fetch_weather(lat, lon, openaq_api_key=openaq_key)
    except Exception as exc:
        logger.exception("Weather fetch failed (lat=%s, lon=%s): %s", lat, lon, exc)
        return failure("weather_unavailable", "天气服务暂不可用", status=502)

    return success(weather)


@weather_bp.get("/smart-advisory")
@auth_required
def smart_advisory():
    """
    天气智能管家 — 结合日程与天气，由 LLM 生成行动建议。

    Query 参数:
        lat  (float) — 纬度，必填
        lon  (float) — 经度，必填
        date (str)   — 日期 YYYY-MM-DD，默认今天

    返回:
        {
            "ok": true,
            "data": {
                "timeline": [{time_slot, event, weather, advisory}],
                "summary": "一句当日总结",
                "generated_at": "ISO8601"
            }
        }
    """
    parsed = _parse_lat_lon()
    if len(parsed) == 3:
        _, _, status = parsed
        return failure("validation_error", "lat and lon are required and must be numbers", status=status)
    lat, lon = parsed

    date_str = (request.args.get("date") or "").strip()
    if not date_str:
        date_str = datetime.now().strftime("%Y-%m-%d")
    else:
        try:
            datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            return failure(
                "validation_error",
                "date must be in YYYY-MM-DD format",
                status=422,
            )

    user = g.current_user

    try:
        # ---- 1. 获取天气 ----
        openaq_key = current_app.config.get("OPENAQ_API_KEY")
        weather = ws.fetch_weather(lat, lon, openaq_api_key=openaq_key)

        # ---- 2. 获取当日日程 ----
        day_start = datetime.strptime(date_str, "%Y-%m-%d")
        raw_events = _load_day_events(user.id, day_start)
        events_formatted = _normalize_events(raw_events)

        # ---- 3. 读取用户天气管家语气设置 ----
        from ..models import AppSetting  # noqa: E402
        settings = db.session.get(AppSetting, user.id)
        tone_prompt = settings.weather_tone if settings else None

        # ---- 4. LLM 合成 ----
        config = _openai_config()
        result = ws.generate_advisory(
            lat=lat, lon=lon,
            date_str=date_str,
            events=events_formatted,
            weather=weather,
            openai_config=config,
            tone_prompt=tone_prompt,
        )
    except Exception as exc:
        logger.exception("Smart advisory generation failed: %s", exc)
        return failure("advisory_unavailable", "天气智能建议暂不可用", status=502)

    return success(result)


def _normalize_events(raw_events: list[dict]) -> list[dict]:
    """将 scheduler_service 返回的 events 统一为 ISO8601 字符串格式。"""
    return [
        {
            "title": e.get("title", ""),
            "starts_at": _to_iso(e.get("starts_at")),
            "ends_at": _to_iso(e.get("ends_at")),
        }
        for e in raw_events
    ]


def _to_iso(value) -> str:
    """将 datetime 或字符串转为 ISO8601。"""
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)
