from __future__ import annotations

import logging
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
        result = get_weather(lat, lon)
    except Exception as exc:
        logger = logging.getLogger(__name__)
        logger.error(
            "Weather fetch failed (lat=%s, lon=%s): %s",
            lat, lon, exc,
        )
        return failure(
            "weather_unavailable",
            "Weather service is temporarily unavailable",
            status=502,
        )

    _cache[key] = (now, result)
    return success(result)


@weather_bp.get("/debug")
@auth_required
def weather_debug():
    """诊断和风天气连接状态（需登录，仅返回连接健康信息）。"""
    import logging as _logging
    _logger = _logging.getLogger(__name__)

    result = {
        "configured": bool(QWEATHER_PRIVATE_KEY and QWEATHER_KID),
    }

    # JWT generation check — only report success/failure, no key preview
    try:
        from ..services.weather import _generate_jwt
        _generate_jwt()
        result["jwt_ok"] = True
    except Exception:
        result["jwt_ok"] = False
        _logger.exception("Weather debug: JWT generation failed")

    # API connectivity check — only report status code, no response body
    try:
        from ..services.weather import _auth_headers
        headers = _auth_headers()
        import httpx

        def _test():
            with httpx.Client(timeout=10.0) as c:
                r = c.get(
                    "https://mp5u9xx3e3.re.qweatherapi.com/v7/weather/now",
                    params={"location": "116.41,39.91"},
                    headers=headers or None,
                )
                return r

        resp = _test()
        result["api_status"] = resp.status_code
        result["api_ok"] = resp.status_code < 400
    except Exception:
        result["api_ok"] = False
        _logger.exception("Weather debug: API connectivity test failed")

    return success(result)
