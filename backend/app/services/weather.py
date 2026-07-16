"""
和风天气 API 封装模块 (QWeather)

API 文档：https://dev.qweather.com/docs/api/
基础 URL：
  - 天气查询：https://devapi.qweather.com/v7/weather/
  - 城市查询：https://geoapi.qweather.com/v2/city/lookup

使用前需在环境变量或配置中设置 QWEATHER_KEY。
"""

import os
import time
import httpx
from typing import Any

import jwt

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------
# JWT 认证：使用 Ed25519 签名（推荐方式，比 API Key 更安全）
# 需在 .env 中配置：
#   QWEATHER_PRIVATE_KEY  - Ed25519 私钥（PEM，含 BEGIN/END 标记）
#   QWEATHER_KID          - 凭据 ID（在控制台-项目管理-凭据中查看）
#   QWEATHER_PROJECT_ID   - 项目 ID（同上）
#
# 备用：如果上面三个变量都未配置，回退到旧的 API Key 方式（QWEATHER_KEY）
QWEATHER_PRIVATE_KEY = os.getenv("QWEATHER_PRIVATE_KEY", "").strip()
QWEATHER_KID = os.getenv("QWEATHER_KID", "").strip()
QWEATHER_PROJECT_ID = os.getenv("QWEATHER_PROJECT_ID", "").strip()
QWEATHER_KEY = os.getenv("QWEATHER_KEY", "").strip()

# JWT 有效期：900 秒（15 分钟），比官方推荐的 1 小时更短以提高安全性
JWT_EXPIRE_SECONDS = 900
# JWT 签发时间偏移：提前 30 秒签发，规避本地时钟误差
JWT_IAT_OFFSET = 30

GEO_API_BASE = "https://geoapi.qweather.com/v2/city/lookup"
WEATHER_API_BASE = "https://devapi.qweather.com/v7/weather"

# 默认超时（秒）
DEFAULT_TIMEOUT = 10.0

# 降级值：当某个字段缺失时使用的兜底
FALLBACK_STR = "--"
FALLBACK_INT = -999


# ---------------------------------------------------------------------------
# 内部工具函数
# ---------------------------------------------------------------------------

def _safe_get(obj: dict, *keys: str, default: Any = None) -> Any:
    """安全地从嵌套字典中取值，任一键缺失返回 default。"""
    for key in keys:
        if not isinstance(obj, dict):
            return default
        obj = obj.get(key, default)
    return obj


async def _request(
    url: str,
    params: dict,
    headers: dict | None = None,
    timeout: float = DEFAULT_TIMEOUT,
) -> dict:
    """统一 HTTP GET 请求封装，带超时与基础错误处理。"""
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.get(url, params=params, headers=headers)
        resp.raise_for_status()
        data: dict = resp.json()
    return data


# ---------------------------------------------------------------------------
# JWT 认证
# ---------------------------------------------------------------------------

def _generate_jwt() -> str:
    """生成和风天气 Ed25519 JWT Token。"""
    if not QWEATHER_PRIVATE_KEY or not QWEATHER_KID or not QWEATHER_PROJECT_ID:
        raise RuntimeError(
            "JWT 认证缺少必要配置，请设置 QWEATHER_PRIVATE_KEY / QWEATHER_KID / QWEATHER_PROJECT_ID"
        )
    now = int(time.time()) - JWT_IAT_OFFSET
    payload = {
        "sub": QWEATHER_PROJECT_ID,
        "iat": now,
        "exp": now + JWT_EXPIRE_SECONDS,
    }
    headers_jwt = {
        "alg": "EdDSA",
        "kid": QWEATHER_KID,
    }
    return jwt.encode(payload, QWEATHER_PRIVATE_KEY, algorithm="EdDSA", headers=headers_jwt)


def _auth_headers() -> dict[str, str]:
    """返回当前认证方式的 HTTP 请求头。JWT 优先，fallback 到 API Key。"""
    if QWEATHER_PRIVATE_KEY and QWEATHER_KID and QWEATHER_PROJECT_ID:
        jwt_token = _generate_jwt()
        return {"Authorization": f"Bearer {jwt_token}"}
    if QWEATHER_KEY:
        return {}  # API Key 通过 params 传递，见调用方
    return {}


# ---------------------------------------------------------------------------
# 公开 API
# ---------------------------------------------------------------------------

async def get_weather(lat: float, lon: float) -> dict:
    """
    根据经纬度获取天气信息。

    Args:
        lat: 纬度（-90 ~ 90）
        lon: 经度（-180 ~ 180）

    Returns:
        {
            "current":  {"temp": int, "condition": str, "icon_code": str},
            "daily":    {"high": int, "low": int},
            "hourly":   [{"time_offset": int, "condition": str, "temp": float}],
        }

        - time_offset: 相对当前整点的小时偏移（1, 2, 3）
        - 任意字段获取失败时使用兜底值（"--" 或 -999），不会抛出异常
    """

    # ---- 1. 获取城市 ID ---------------------------------------------------
    location_id = await _get_location_id(lat, lon)

    # ---- 2. 并行拉取三类天气数据 -------------------------------------------
    auth_hdrs = _auth_headers()
    base_params: dict[str, str] = {"location": location_id}
    if not auth_hdrs and QWEATHER_KEY:
        base_params["key"] = QWEATHER_KEY

    now_data: dict = {}
    day_data: list[dict] = []
    hour_data: list[dict] = []

    try:
        now_data = await _request(f"{WEATHER_API_BASE}/now", base_params, auth_hdrs or None)
    except Exception:
        pass

    try:
        day_resp = await _request(f"{WEATHER_API_BASE}/7d", base_params, auth_hdrs or None)
        day_data = _safe_get(day_resp, "daily", default=[]) or []
    except Exception:
        pass

    try:
        hour_resp = await _request(f"{WEATHER_API_BASE}/24h", base_params, auth_hdrs or None)
        hour_data = _safe_get(hour_resp, "hourly", default=[]) or []
    except Exception:
        pass

    # ---- 3. 组装 current --------------------------------------------------
    now = _safe_get(now_data, "now", default={}) or {}

    current = {
        "temp": int(_safe_get(now, "temp", default=FALLBACK_STR) or FALLBACK_INT),
        "condition": _safe_get(now, "text", default=FALLBACK_STR) or FALLBACK_STR,
        "icon_code": _safe_get(now, "icon", default=FALLBACK_STR) or FALLBACK_STR,
    }

    # ---- 4. 组装 daily（取今天） -------------------------------------------
    daily = {"high": FALLBACK_INT, "low": FALLBACK_INT}
    if day_data:
        today = day_data[0]
        daily["high"] = int(_safe_get(today, "tempMax", default=FALLBACK_STR) or FALLBACK_INT)
        daily["low"] = int(_safe_get(today, "tempMin", default=FALLBACK_STR) or FALLBACK_INT)

    # ---- 5. 组装 hourly（未来 3 小时） -------------------------------------
    hourly: list[dict] = []
    for offset, item in enumerate(hour_data[:3], start=1):
        hourly.append({
            "time_offset": offset,
            "condition": _safe_get(item, "text", default=FALLBACK_STR) or FALLBACK_STR,
            "temp": float(_safe_get(item, "temp", default=str(FALLBACK_INT)) or FALLBACK_INT),
        })

    return {
        "current": current,
        "daily": daily,
        "hourly": hourly,
    }


# ---------------------------------------------------------------------------
# 城市查询
# ---------------------------------------------------------------------------

async def _get_location_id(lat: float, lon: float) -> str:
    """
    根据经纬度查询和风天气城市 ID。

    Raises:
        RuntimeError: 城市查询完全失败时抛出，调用方应捕获并降级处理。
    """
    auth_hdrs = _auth_headers()
    params: dict[str, str] = {
        "location": f"{lon:.2f},{lat:.2f}",
        "number": "1",
    }
    if not auth_hdrs and QWEATHER_KEY:
        params["key"] = QWEATHER_KEY
    try:
        data = await _request(GEO_API_BASE, params, auth_hdrs or None)
        locations = _safe_get(data, "location", default=[]) or []
        if locations:
            loc_id = locations[0].get("id")
            if loc_id:
                return str(loc_id)
    except Exception as exc:
        raise RuntimeError(f"城市查询失败 (lat={lat}, lon={lon}): {exc}") from exc

    raise RuntimeError(f"城市查询无结果 (lat={lat}, lon={lon})")
