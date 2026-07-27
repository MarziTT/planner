"""
天气智能管家服务 — 多源聚合 + LLM 合成。

流水线：
1. 并行拉取 Open-Meteo（天气）+ OpenAQ（空气质量）
2. 聚合为统一 weather dict
3. 结合用户日程，调用 LLM 生成管家式行动建议

缓存策略：
- 天气原始数据缓存 30 分钟
- LLM 合成结果按 (坐标, 日期, 天气指纹, 事件指纹) 缓存
- 任意源失败时回退到上次缓存标记 stale=true
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any

import requests

from . import open_aq as oaq
from . import open_meteo as om

logger = logging.getLogger(__name__)

# ---- 缓存 ----
_weather_cache: dict[str, tuple[float, dict]] = {}    # cache_key → (timestamp, data)
_ADVISORY_CACHE: dict[str, tuple[float, dict]] = {}    # advisory_key → (timestamp, data)
_CACHE_TTL = 60 * 30          # 30 分钟（秒）

# ---- LLM ----
LLM_TIMEOUT = 20.0            # 秒
MAX_TOKENS = 200
DEFAULT_MODEL = "gpt-4o-mini"

WEATHER_PROMPT = """你是 PixelPlanner，用户的私人生活管家。
用户日程：{events}
天气数据：{weather_data}
请对每个日程时段给出简短的一条行动建议（不超过 20 字），格式：
[时段] [事件] [建议]
最后加一句当日总结。
要求：用中文，用"你"称呼用户，建议代替播报，关心语气。"""


def _cache_key(lat: float, lon: float) -> str:
    """天气缓存键（坐标 2 位小数取整）。"""
    return f"{round(lat, 2):.2f},{round(lon, 2):.2f}"


def _advisory_cache_key(
    lat: float, lon: float, date_str: str, events: list[dict], weather: dict
) -> str:
    """LLM 结果缓存键：坐标+日期+事件指纹+天气指纹的 SHA256。"""
    payload = {
        "lat": round(lat, 2),
        "lon": round(lon, 2),
        "date": date_str,
        "events": sorted(e.get("title", "") for e in events),
        "weather_fingerprint": _weather_fingerprint(weather),
    }
    raw = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _weather_fingerprint(weather: dict) -> str:
    """提取天气关键字段生成指纹（用于 LLM 缓存比对）。"""
    cur = weather.get("current", {})
    daily = weather.get("daily", [{}])
    d0 = daily[0] if daily else {}
    aqi = weather.get("air_quality", {})
    # 为避免每日预报中细微变动导致缓存不命中，只保留小时级温度步长
    parts = [
        str(round(cur.get("temp", 0) or 0)),
        str(cur.get("weather_code", "")),
        str(round((d0.get("temp_max") or 0), 0)),
        str(round((d0.get("temp_min") or 0), 0)),
        str(d0.get("weather_code", "")),
        str(round(d0.get("precipitation_probability_max", 0) or 0)),
        str(round((aqi.get("pm2_5") or 0), 0)),
        str(round((aqi.get("pm10") or 0), 0)),
    ]
    return "|".join(parts)


def fetch_weather(
    lat: float,
    lon: float,
    openaq_api_key: str | None = None,
    force_refresh: bool = False,
) -> dict:
    """
    并行获取天气 + 空气质量，30 分钟缓存。

    返回统一天气 dict：
        {
            "source": "open-meteo+openaq",
            "stale": bool,
            "current": { ... },
            "hourly": [ ... ],
            "daily": [ ... ],
            "air_quality": { "pm2_5": float, "pm10": float, "o3": float, "no2": float }
        }
    """
    key = _cache_key(lat, lon)
    now = time.time()

    if not force_refresh and key in _weather_cache:
        cached_at, cached_data = _weather_cache[key]
        if now - cached_at < _CACHE_TTL:
            cached_data["stale"] = False
            return cached_data

    # 并行请求
    meteo_result: dict | None = None
    aqi_result: dict | None = None

    with ThreadPoolExecutor(max_workers=2) as executor:
        future_meteo = executor.submit(om.fetch_forecast, lat, lon)
        future_aqi = executor.submit(oaq.fetch_air_quality, lat, lon, openaq_api_key)
        for fut in as_completed([future_meteo, future_aqi]):
            try:
                if fut is future_meteo:
                    meteo_result = fut.result()
                else:
                    aqi_result = fut.result()
            except Exception as exc:
                logger.warning("Weather source fetch failed: %s", exc)

    # fallback
    stale = False
    if meteo_result is None:
        if key in _weather_cache:
            _, cached = _weather_cache[key]
            meteo_result = cached.get("raw_meteo") or cached
            stale = True
            logger.info("Open-Meteo failed, using stale cache")
        else:
            raise RuntimeError("Weather unavailable: Open-Meteo failed and no cache")

    if aqi_result is None or aqi_result.get("status") == "unavailable":
        if key in _weather_cache:
            cached_aqi = _weather_cache[key].get("air_quality")
            if cached_aqi:
                aqi_result = {"source": "openaq", **cached_aqi}
                stale = True
        if aqi_result is None:
            aqi_result = {
                "source": "openaq",
                "pm2_5": None, "pm10": None, "o3": None, "no2": None,
            }

    # 组装
    result: dict[str, Any] = {
        "source": "open-meteo+openaq",
        "stale": stale,
        "raw_meteo": meteo_result,
        "current": meteo_result.get("current", {}),
        "hourly": meteo_result.get("hourly", []),
        "daily": meteo_result.get("daily", []),
        "air_quality": {
            k: aqi_result.get(k)
            for k in ("pm2_5", "pm10", "o3", "no2")
        },
    }

    _weather_cache[key] = (now, result)
    return result


def build_timeline(
    events: list[dict],
    weather: dict,
    date_str: str,
) -> list[dict]:
    """
    将日程事件与天气数据按时段对齐，生成 timeline。

    events 格式：[{"title": str, "starts_at": "ISO8601", "ends_at": "ISO8601"}, ...]
    返回：
        [{
            "time_slot": "08:00-09:00",
            "event": "晨跑",
            "weather": { "temp": 22, "weather_text": "晴", "precipitation_probability": 10, ... },
            "advisory": ""
        }, ...]
    """
    hourly = weather.get("hourly", [])
    cur = weather.get("current", {})
    aqi = weather.get("air_quality", {})
    daily = weather.get("daily", [{}])

    # 无日程 → 按早晚三个时间段生成
    if not events:
        periods = [
            ("08:00", "morning"),
            ("12:00", "noon"),
            ("18:00", "evening"),
        ]
        timeline = []
        for time_str, period in periods:
            m = _match_hourly(hourly, time_str)
            timeline.append({
                "time_slot": time_str,
                "event": period,
                "weather": _summarize_slot_weather(m, aqi),
            })
        return timeline

    # 有日程 → 按时段对齐
    timeline = []
    for ev in events:
        starts = ev.get("starts_at", "")
        time_str = _extract_time(starts) or ""
        m = _match_hourly(hourly, time_str) if time_str else {}
        slot_wx = _summarize_slot_weather(m, aqi)
        timeline.append({
            "time_slot": time_str,
            "event": ev.get("title", ""),
            "weather": slot_wx,
        })
    return timeline


def generate_advisory(
    lat: float,
    lon: float,
    date_str: str,
    events: list[dict],
    weather: dict,
    openai_config: dict,
    tone_prompt: str | None = None,
) -> dict:
    """
    LLM 合成天气管家建议。

    Returns:
        {
            "timeline": [...],
            "summary": str,
            "generated_at": str (ISO8601),
        }
    """
    # ---- 构建 timeline ----
    timeline = build_timeline(events, weather, date_str)

    # ---- LLM 缓存检查 ----
    adv_key = _advisory_cache_key(lat, lon, date_str, events, weather)
    now_ts = time.time()
    if adv_key in _ADVISORY_CACHE:
        cached_at, cached = _ADVISORY_CACHE[adv_key]
        if now_ts - cached_at < _CACHE_TTL:
            return cached

    # ---- 调用 LLM ----
    events_text = _format_events(events, timeline)
    weather_text = _format_weather_for_llm(weather)
    prompt = WEATHER_PROMPT.format(events=events_text, weather_data=weather_text)

    llm_output = _call_openai(prompt, openai_config, system_prompt=tone_prompt)
    advisory_map = _parse_advisory(llm_output) if llm_output else {}

    # 填入 advisory 并提炼总结
    for slot in timeline:
        key = slot.get("event", "")
        slot["advisory"] = advisory_map.get(key, "")

    summary = advisory_map.get("$summary", "")
    if not summary:
        # 兜底：从 LLM 输出中取最后一句
        lines = (llm_output or "").strip().splitlines()
        summary = lines[-1] if lines else ""

    result = {
        "timeline": timeline,
        "summary": summary,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S+08:00", time.localtime(now_ts)),
    }
    _ADVISORY_CACHE[adv_key] = (now_ts, result)
    return result


# ---- 内部辅助函数 ----


def _extract_time(iso_str: str) -> str:
    """从 ISO8601 字符串中提取 HH:MM。"""
    try:
        parts = iso_str.replace("T", " ").split()
        if len(parts) >= 2:
            return parts[1][:5]
    except (IndexError, AttributeError):
        pass
    return ""


def _match_hourly(hourly: list[dict], time_str: str) -> dict:
    """从逐小时数据中匹配最接近的时间点。"""
    if not hourly or not time_str:
        return hourly[0] if hourly else {}
    target = time_str[:2]  # HH
    for h in hourly:
        h_time = h.get("time", "")
        if h_time[:13] >= time_str[:13] and h_time[11:13] == target:
            return h
    return hourly[0] if hourly else {}


def _summarize_slot_weather(hourly_point: dict, aqi: dict) -> dict:
    """浓缩时段天气摘要。"""
    return {
        "temp": hourly_point.get("temp"),
        "weather_text": hourly_point.get("weather_text"),
        "weather_code": hourly_point.get("weather_code"),
        "precipitation_probability": hourly_point.get("precipitation_probability"),
        "wind_speed": hourly_point.get("wind_speed"),
        "humidity": hourly_point.get("humidity"),
        "uv_index": hourly_point.get("uv_index"),
        "pm2_5": aqi.get("pm2_5"),
        "pm10": aqi.get("pm10"),
        "o3": aqi.get("o3"),
        "no2": aqi.get("no2"),
    }


def _format_events(events: list[dict], timeline: list[dict]) -> str:
    """格式化日程列表为 LLM prompt 文本。"""
    if not events:
        return "今日暂无日程安排"
    lines = []
    for slot in timeline:
        lines.append(f"- {slot.get('time_slot', '')} {slot.get('event', '')}")
    return "\n".join(lines) if lines else "今日暂无日程安排"


def _format_weather_for_llm(weather: dict) -> str:
    """格式化天气数据为 LLM prompt 文本（精简关键字段）。"""
    cur = weather.get("current", {})
    daily = weather.get("daily", [{}])
    d0 = daily[0] if daily else {}
    aqi = weather.get("air_quality", {})

    parts = [
        f"当前温度：{cur.get('temp', '--')}°C，体感 {cur.get('feels_like', '--')}°C",
        f"天气：{cur.get('weather_text', '--')}",
        f"降水概率：{cur.get('precipitation_probability', '--')}%",
        f"湿度：{cur.get('humidity', '--')}%",
        f"风力：{cur.get('wind_speed', '--')} km/h",
        f"紫外线：{cur.get('uv_index', '--')}",
    ]
    if d0:
        parts.append(f"今日最高 {d0.get('temp_max', '--')}°C，最低 {d0.get('temp_min', '--')}°C")
        parts.append(f"今日降水概率：{d0.get('precipitation_probability_max', '--')}%")

    aqi_parts = []
    if aqi.get("pm2_5") is not None:
        aqi_parts.append(f"PM2.5: {aqi['pm2_5']}")
    if aqi.get("pm10") is not None:
        aqi_parts.append(f"PM10: {aqi['pm10']}")
    if aqi.get("o3") is not None:
        aqi_parts.append(f"O3: {aqi['o3']}")
    if aqi.get("no2") is not None:
        aqi_parts.append(f"NO2: {aqi['no2']}")
    if aqi_parts:
        parts.append(f"空气质量（μg/m³）：{'，'.join(aqi_parts)}")

    return "\n".join(parts)


def _parse_advisory(text: str) -> dict[str, str]:
    """从 LLM 输出中解析 [时段] [事件] [建议] 行 + 总结。

    Returns:
        { event_name: advisory, "$summary": str }
    """
    lines = [l.strip() for l in text.strip().splitlines() if l.strip()]
    result: dict[str, str] = {}
    summary_candidates = []

    for line in lines:
        # 尝试匹配 [时段] [事件] [建议] 格式
        # 使用 [] 作为分隔符
        parts = line.split("]")
        if len(parts) >= 3:
            time_slot = parts[0].lstrip("[").strip() if parts[0].startswith("[") else ""
            event = parts[1].lstrip("[").strip()
            advisory = parts[2].strip()
            if event:
                result[event] = advisory
        else:
            summary_candidates.append(line)

    # 最后一行作为总结
    if summary_candidates:
        result["$summary"] = summary_candidates[-1]
    elif len(lines) >= 1:
        result["$summary"] = lines[-1]

    return result


def _call_openai(prompt: str, config: dict, system_prompt: str | None = None) -> str | None:
    """调用 OpenAI-compatible chat completion，返回文本或 None。"""
    api_key = config.get("OPENAI_API_KEY", "")
    base_url = config.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
    model = config.get("OPENAI_MODEL", DEFAULT_MODEL)

    if not api_key:
        logger.warning("OPENAI_API_KEY not configured, skipping LLM synthesis")
        return None

    url = f"{base_url.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})
    payload: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": MAX_TOKENS,
    }

    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=LLM_TIMEOUT)
        resp.raise_for_status()
        body = resp.json()
        return body["choices"][0]["message"]["content"].strip()
    except Exception as exc:
        logger.warning("LLM advisory call failed: %s", exc)
        return None


def clear_cache() -> None:
    """清除所有缓存（用于测试/调试）。"""
    _weather_cache.clear()
    _ADVISORY_CACHE.clear()
