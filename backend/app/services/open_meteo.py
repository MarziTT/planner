"""
Open-Meteo 天气数据客户端 (免费、免密钥)。

API 文档：https://open-meteo.com/en/docs
端点：GET https://api.open-meteo.com/v1/forecast

约定：
- 30 秒超时，失败后重试 1 次
- 返回标准化 dict（字段缺失时以 None 兜底），异常时抛出 OpenMeteoError
"""

from __future__ import annotations

import logging
import time
from typing import Any

import httpx

logger = logging.getLogger(__name__)

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"

DEFAULT_TIMEOUT = 30.0  # 秒
MAX_ATTEMPTS = 2        # 1 次初始请求 + 1 次重试
RETRY_BACKOFF = 1.0     # 重试前等待（秒）

CURRENT_FIELDS = (
    "temperature_2m,apparent_temperature,precipitation_probability,"
    "weather_code,wind_speed_10m,relative_humidity_2m,uv_index"
)
HOURLY_FIELDS = "precipitation_probability,temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,uv_index"
DAILY_FIELDS = (
    "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code"
)

# WMO Weather interpretation codes → 中文描述
# https://open-meteo.com/en/docs#weathervariables
WMO_CODE_TEXT: dict[int, str] = {
    0: "晴",
    1: "大部晴朗",
    2: "局部多云",
    3: "阴",
    45: "雾",
    48: "冻雾",
    51: "小毛毛雨",
    53: "毛毛雨",
    55: "大毛毛雨",
    56: "冻毛毛雨",
    57: "强冻毛毛雨",
    61: "小雨",
    63: "中雨",
    65: "大雨",
    66: "冻雨",
    67: "强冻雨",
    71: "小雪",
    73: "中雪",
    75: "大雪",
    77: "雪粒",
    80: "小阵雨",
    81: "阵雨",
    82: "强阵雨",
    85: "小阵雪",
    86: "大阵雪",
    95: "雷暴",
    96: "雷暴伴小冰雹",
    99: "雷暴伴大冰雹",
}


class OpenMeteoError(RuntimeError):
    """Open-Meteo 请求失败（重试耗尽）。"""


def weather_code_text(code: int | None) -> str:
    """WMO 天气代码转中文描述，未知代码返回 '未知'。"""
    if code is None:
        return "未知"
    return WMO_CODE_TEXT.get(int(code), "未知")


def _request_with_retry(params: dict[str, Any]) -> dict:
    """带 1 次重试的 GET 请求。"""
    last_exc: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                resp = client.get(FORECAST_URL, params=params)
                resp.raise_for_status()
                return resp.json()
        except Exception as exc:  # httpx.HTTPError / JSON 解析错误
            last_exc = exc
            logger.warning(
                "Open-Meteo request failed (attempt %d/%d): %s",
                attempt, MAX_ATTEMPTS, exc,
            )
            if attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_BACKOFF)
    raise OpenMeteoError(f"Open-Meteo request failed after {MAX_ATTEMPTS} attempts: {last_exc}")


def _pick(values: list | None, index: int) -> Any:
    """从并列数组安全取值。"""
    if not isinstance(values, list) or index >= len(values):
        return None
    return values[index]


def fetch_forecast(lat: float, lon: float) -> dict:
    """
    拉取指定经纬度的天气预报并标准化。

    Returns:
        {
            "source": "open-meteo",
            "timezone": str,
            "current": {
                "time": str, "temp": float, "feels_like": float,
                "precipitation_probability": int, "weather_code": int,
                "weather_text": str, "wind_speed": float,
                "humidity": int, "uv_index": float,
            },
            "hourly": [{
                "time": str, "temp": float,
                "precipitation_probability": int,
                "weather_code": int, "weather_text": str,
                "wind_speed": float, "humidity": int, "uv_index": float,
            }],
            "daily": [{
                "date": str, "temp_max": float, "temp_min": float,
                "precipitation_probability_max": int,
                "weather_code": int, "weather_text": str,
            }],
        }

    Raises:
        OpenMeteoError: 请求重试耗尽仍失败。
    """
    params: dict[str, Any] = {
        "latitude": lat,
        "longitude": lon,
        "current": CURRENT_FIELDS,
        "hourly": HOURLY_FIELDS,
        "daily": DAILY_FIELDS,
        "timezone": "auto",
        "forecast_days": 3,
    }
    data = _request_with_retry(params)

    # ---- current ----------------------------------------------------------
    cur = data.get("current") or {}
    current = {
        "time": cur.get("time"),
        "temp": cur.get("temperature_2m"),
        "feels_like": cur.get("apparent_temperature"),
        "precipitation_probability": cur.get("precipitation_probability"),
        "weather_code": cur.get("weather_code"),
        "weather_text": weather_code_text(cur.get("weather_code")),
        "wind_speed": cur.get("wind_speed_10m"),
        "humidity": cur.get("relative_humidity_2m"),
        "uv_index": cur.get("uv_index"),
    }

    # ---- hourly -----------------------------------------------------------
    hourly_raw = data.get("hourly") or {}
    hourly_times = hourly_raw.get("time") or []
    hourly: list[dict] = []
    for i, ts in enumerate(hourly_times):
        code = _pick(hourly_raw.get("weather_code"), i)
        hourly.append({
            "time": ts,
            "temp": _pick(hourly_raw.get("temperature_2m"), i),
            "precipitation_probability": _pick(hourly_raw.get("precipitation_probability"), i),
            "weather_code": code,
            "weather_text": weather_code_text(code),
            "wind_speed": _pick(hourly_raw.get("wind_speed_10m"), i),
            "humidity": _pick(hourly_raw.get("relative_humidity_2m"), i),
            "uv_index": _pick(hourly_raw.get("uv_index"), i),
        })

    # ---- daily ------------------------------------------------------------
    daily_raw = data.get("daily") or {}
    daily_dates = daily_raw.get("time") or []
    daily: list[dict] = []
    for i, d in enumerate(daily_dates):
        code = _pick(daily_raw.get("weather_code"), i)
        daily.append({
            "date": d,
            "temp_max": _pick(daily_raw.get("temperature_2m_max"), i),
            "temp_min": _pick(daily_raw.get("temperature_2m_min"), i),
            "precipitation_probability_max": _pick(
                daily_raw.get("precipitation_probability_max"), i
            ),
            "weather_code": code,
            "weather_text": weather_code_text(code),
        })

    return {
        "source": "open-meteo",
        "timezone": data.get("timezone"),
        "current": current,
        "hourly": hourly,
        "daily": daily,
    }
