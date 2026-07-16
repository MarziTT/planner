from __future__ import annotations

import asyncio
import time

from flask import Blueprint, request

from ..services.weather import get_weather
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
    except RuntimeError:
        # 城市查询失败 → 降级为空数据，但不报 500
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
