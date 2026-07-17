from __future__ import annotations

import asyncio
import time

from flask import Blueprint, current_app, request

from ..services.weather import get_weather, QWEATHER_PRIVATE_KEY, QWEATHER_KID, QWEATHER_PROJECT_ID
from .common import auth_required, failure, success

weather_bp = Blueprint("weather", __name__)

# 内存缓存：{(lat, lon): (timestamp, result)}
_cache: dict[tuple[float, float], tuple[float, dict]] = {}
_CACHE_TTL = 3600  # 1 小时（秒）


def _cache_key(lat: float, lon: float) -> tuple[float, float]:
    """按 2 位小数精度取整，避免浮点噪点导致缓存未命中。"""
    return (round(lat, 2), round(lon, 2))


@weather_bp.get("/")
@auth_required
def weather_now():
    """获取指定经纬度的当前天气、今日预报和未来 3 小时逐时天气。"""
    lat_str = request.args.get("lat", "").strip()
    lon_str = request.args.get("lon", "").strip()

    if not lat_str or not lon_str:
        return failure("validation_error", "lat and lon are required", status=422)

    try:
        lat = float(lat_str)
        lon = float(lon_str)
    except ValueError:
        return failure("validation_error", "lat and lon must be valid numbers", status=422)

    key = _cache_key(lat, lon)
    now = time.time()

    if key in _cache:
        cached_at, cached_result = _cache[key]
        if now - cached_at < _CACHE_TTL:
            return success(cached_result)

    try:
        result = asyncio.run(get_weather(lat, lon))
    except Exception as exc:
        import logging
        import traceback
        logging.getLogger(__name__).error(
            "Weather fetch failed (lat=%s, lon=%s): %s\n%s",
            lat, lon, exc, traceback.format_exc(),
        )
        result = {
            "current": {
                "temp": -999,
                "feels_like": -999,
                "condition": {"code": -999, "text": "--"},
                "humidity": -999,
                "wind_speed": -999,
            },
            "daily": [],
            "hourly": [],
        }

    _cache[key] = (now, result)
    return success(result)


@weather_bp.get("/debug")
def weather_debug():
    """诊断和风天气连接状态，不要求登录。"""
    import traceback as tb_module
    result = {
        "kid": QWEATHER_KID,
        "project_id": QWEATHER_PROJECT_ID,
        "private_key_len": len(QWEATHER_PRIVATE_KEY),
        "private_key_starts": QWEATHER_PRIVATE_KEY[:30] if QWEATHER_PRIVATE_KEY else "(empty)",
    }
    try:
        from ..services.weather import _generate_jwt, _request, _get_location_id
        jwt_token = _generate_jwt()
        result["jwt_ok"] = True
        result["jwt_preview"] = jwt_token[:20] + "..."
    except Exception as e:
        result["jwt_ok"] = False
        result["jwt_error"] = str(e)
        result["jwt_traceback"] = tb_module.format_exc()

    try:
        from ..services.weather import WEATHER_API_BASE, _auth_headers
        headers = _auth_headers()
        resp = asyncio.run(_request(
            f"{WEATHER_API_BASE}/now",
            {"location": "116.41,39.91"},
            headers or None,
            timeout=10.0,
        ))
        result["api_ok"] = True
        result["api_code"] = resp.get("code", "N/A")
    except Exception as e:
        result["api_ok"] = False
        result["api_error"] = str(e)

    return success(result)
