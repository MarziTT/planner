"""
OpenAQ 空气质量数据客户端。

API 文档：https://docs.openaq.org/
端点：GET https://api.openaq.org/v3/locations/{location_id}/latest
      GET https://api.openaq.org/v3/locations?coordinates={lat},{lon}&radius=5000

约定：
- 30 秒超时，失败后重试 1 次
- 返回标准化 dict（字段缺失时以 None 兜底），异常时抛出 OpenAQError
- API Key 通过环境变量 OPENAQ_API_KEY 配置（OpenAQ 免费套餐需要注册）
"""

from __future__ import annotations

import logging
import time
from typing import Any

import httpx

logger = logging.getLogger(__name__)

OPENAQ_BASE = "https://api.openaq.org/v3"

DEFAULT_TIMEOUT = 30.0  # 秒
MAX_ATTEMPTS = 2        # 1 次初始请求 + 1 次重试
RETRY_BACKOFF = 1.0     # 重试前等待（秒）
SEARCH_RADIUS = 5000    # 坐标附近搜索半径（米）

# 关注污染物及单位标准化
POLLUTANT_KEYS: dict[str, str] = {
    "pm25": "pm2_5",
    "pm10": "pm10",
    "o3": "o3",
    "no2": "no2",
}

# OpenAQ 参数名到归一化键的映射
_PARAM_TO_KEY: dict[str, str] = {
    "pm25": "pm2_5",
    "pm10": "pm10",
    "o3": "o3",
    "no2": "no2",
}


class OpenAQError(RuntimeError):
    """OpenAQ 请求失败（重试耗尽）。"""


def _auth_headers(api_key: str | None = None) -> dict[str, str]:
    """构建请求头（可选 API Key）。"""
    import os
    key = api_key or os.getenv("OPENAQ_API_KEY", "")
    headers: dict[str, str] = {}
    if key:
        headers["X-API-Key"] = key
    return headers


def _request_with_retry(
    url: str,
    params: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> dict:
    """带 1 次重试的 GET 请求。"""
    last_exc: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            with httpx.Client(timeout=DEFAULT_TIMEOUT) as client:
                resp = client.get(url, params=params or {}, headers=headers or {})
                resp.raise_for_status()
                body: dict = resp.json()
                return body
        except Exception as exc:
            last_exc = exc
            logger.warning(
                "OpenAQ request failed (attempt %d/%d): %s",
                attempt, MAX_ATTEMPTS, exc,
            )
            if attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_BACKOFF)
    raise OpenAQError(f"OpenAQ request failed after {MAX_ATTEMPTS} attempts: {last_exc}")


def _find_nearest_location(lat: float, lon: float, api_key: str | None = None) -> int | None:
    """按坐标搜索最近监测站，返回 location_id 或 None。"""
    try:
        url = f"{OPENAQ_BASE}/locations"
        params: dict[str, Any] = {
            "coordinates": f"{lat},{lon}",
            "radius": SEARCH_RADIUS,
            "limit": 1,
            "order_by": "distance",
        }
        headers = _auth_headers(api_key)
        body = _request_with_retry(url, params, headers)
        results = body.get("results", [])
        if results:
            return int(results[0]["id"])
    except Exception:
        logger.warning("OpenAQ location search failed (lat=%s, lon=%s)", lat, lon)
    return None


def _normalize_sensors(sensors: list[dict]) -> dict[str, float | None]:
    """从传感器列表中提炼 PM2.5 / PM10 / O3 / NO2（单位统一 μg/m³）。"""
    result: dict[str, float | None] = {
        "pm2_5": None,
        "pm10": None,
        "o3": None,
        "no2": None,
    }
    for sensor in sensors:
        param = sensor.get("parameter") or {}
        param_name = (param.get("name") or "").lower()
        if param_name in _PARAM_TO_KEY:
            key = _PARAM_TO_KEY[param_name]
            value = sensor.get("value")
            if value is not None:
                result[key] = float(value)
    return result


def fetch_air_quality(lat: float, lon: float, api_key: str | None = None) -> dict:
    """
    按经纬度获取空气质量数据。

    流程：
    1. 搜索最近监测站（5km 半径）
    2. 获取该站最新读数
    3. 标准化为统一 dict

    Returns:
        {
            "source": "openaq",
            "location_name": str,
            "pm2_5": float, "pm10": float,
            "o3": float, "no2": float,
        }

    若搜索不到监测站或全字段缺失则返回 "unavailable"。
    """
    # Step 1 — 找最近监测站
    location_id = _find_nearest_location(lat, lon, api_key)
    if location_id is None:
        return {"source": "openaq", "status": "unavailable"}

    # Step 2 — 获取最新读数
    try:
        url = f"{OPENAQ_BASE}/locations/{location_id}/latest"
        headers = _auth_headers(api_key)
        body = _request_with_retry(url, headers=headers)
        results = body.get("results") or []
        if not results:
            return {"source": "openaq", "status": "unavailable"}
        latest = results[0]
        sensors = latest.get("sensors") or []
        normalized = _normalize_sensors(sensors)
        return {
            "source": "openaq",
            "location_name": latest.get("name", "未知站点"),
            **normalized,
        }
    except Exception:
        logger.warning("OpenAQ latest fetch failed (location_id=%s)", location_id)
        return {"source": "openaq", "status": "unavailable"}
