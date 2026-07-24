"""
LLM Agent service — semantic schedule parsing for Jarvis Agent (Phase 1).

Primary path: OpenAI-compatible LLM with Few-shot prompt → structured JSON.
Fallback: regex-based keyword extraction when LLM is unavailable.
"""

from __future__ import annotations

import json
import logging
import os
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any

import requests

TZ = timezone(timedelta(hours=8))  # UTC+8

# Try dateutil for flexible parsing; pure datetime fallback if unavailable.
try:
    from dateutil.parser import parse as dateutil_parse  # noqa: F811
    _HAS_DATEUTIL = True
except ImportError:
    _HAS_DATEUTIL = False

logger = logging.getLogger(__name__)

# -- JSON schema enforced in the LLM prompt -----------------------------------

FEW_SHOT_SYSTEM_PROMPT = """You are a schedule-parsing assistant. Your ONLY job is to convert natural-language Chinese scheduling requests into a strict JSON object.

Rules:
1. Output ONLY the JSON object. No markdown fences, no explanation.
2. timezone is UTC+8 (Asia/Shanghai). Today is {today}.
3. datetime_range.start and datetime_range.end MUST be ISO8601 strings in format "YYYY-MM-DDTHH:MM:SS".
4. If the user did NOT provide any time information, set datetime_range to null.
5. is_fuzzy = true when the time is imprecise (e.g. "afternoon", "evening", "next week"), false when exact.
6. confidence: 1.0 for crystal-clear requests, lower for ambiguous ones.
7. intent: "create_event" when the user clearly wants to schedule something, otherwise "unknown".
8. person: extract the person name after 跟/和/与/同; omit if none.
9. location: extract the place name after 在/去/到; omit if none.
10. event_name: a concise summary of what the event is (remove person/location/time parts).
11. Time disambiguation: when the user says an hour (e.g. "十点") without specifying AM/PM (上午/下午/晚上), and the hour in 24h is ≤ the current hour ({current_time}) with a gap < 12 hours, add 12 to the hour (assume PM/night). If the adjusted time is still in the past, push to tomorrow.

Output schema:
{{
  "intent": "create_event | unknown",
  "event_name": "事件名称",
  "person": "人物名字 or null",
  "location": "地点 or null",
  "datetime_range": {{ "start": "ISO8601", "end": "ISO8601" }} or null,
  "is_fuzzy": true/false,
  "confidence": 0.0-1.0
}}

Few-shot examples:

User: 明天下午3点跟老张开项目会
Output: {{"intent":"create_event","event_name":"开项目会","person":"老张","location":null,"datetime_range":{{"start":"{tomorrow}T15:00:00","end":"{tomorrow}T16:00:00"}},"is_fuzzy":false,"confidence":0.95}}

User: 后天下午跟小王喝咖啡
Output: {{"intent":"create_event","event_name":"喝咖啡","person":"小王","location":null,"datetime_range":{{"start":"{day_after_tomorrow}T14:00:00","end":"{day_after_tomorrow}T17:00:00"}},"is_fuzzy":true,"confidence":0.85}}

User: 下周一下午3点在会议室讨论设计方案
Output: {{"intent":"create_event","event_name":"讨论设计方案","person":null,"location":"会议室","datetime_range":{{"start":"{next_monday}T15:00:00","end":"{next_monday}T16:00:00"}},"is_fuzzy":false,"confidence":0.95}}

User: 晚上去健身房
Output: {{"intent":"create_event","event_name":"去健身房","person":null,"location":null,"datetime_range":{{"start":"{today}T18:00:00","end":"{today}T21:00:00"}},"is_fuzzy":true,"confidence":0.75}}

User: 跟小明吃饭
Output: {{"intent":"create_event","event_name":"吃饭","person":"小明","location":null,"datetime_range":null,"is_fuzzy":true,"confidence":0.5}}

User: 今天天气怎么样
Output: {{"intent":"unknown","event_name":"","person":null,"location":null,"datetime_range":null,"is_fuzzy":false,"confidence":0.0}}

User: 周六在图书馆写论文
Output: {{"intent":"create_event","event_name":"写论文","person":null,"location":"图书馆","datetime_range":{{"start":"{next_saturday}T09:00:00","end":"{next_saturday}T12:00:00"}},"is_fuzzy":true,"confidence":0.7}}

User: 明天上午10点半跟李总在星巴克谈合作
Output: {{"intent":"create_event","event_name":"谈合作","person":"李总","location":"星巴克","datetime_range":{{"start":"{tomorrow}T10:30:00","end":"{tomorrow}T11:30:00"}},"is_fuzzy":false,"confidence":0.95}}

User: 十点去吃饭
Output: {{"intent":"create_event","event_name":"去吃饭","person":null,"location":null,"datetime_range":{{"start":"{today}T22:00:00","end":"{today}T23:00:00"}},"is_fuzzy":false,"confidence":0.9}}
"""

# -- Helpers ------------------------------------------------------------------

_today = date.today()
_TODAY_SLOTS = {
    "today": _today.isoformat(),
    "tomorrow": (_today + timedelta(days=1)).isoformat(),
    "day_after_tomorrow": (_today + timedelta(days=2)).isoformat(),
    "next_monday": (_today + timedelta(days=(7 - _today.weekday()) % 7 or 7)).isoformat(),
    "next_saturday": (_today + timedelta(days=(5 - _today.weekday()) % 7 or 7)).isoformat(),
}


def _build_system_prompt() -> str:
    now = datetime.now(TZ)
    slots = dict(_TODAY_SLOTS)
    slots["current_time"] = f"{now.hour:02d}:{now.minute:02d}"
    slots["current_hour"] = now.hour
    return FEW_SHOT_SYSTEM_PROMPT.format(**slots)


def _call_openai(text: str, config: dict) -> dict | None:
    """Call an OpenAI-compatible chat completion endpoint; return parsed JSON or None."""
    api_key = config.get("OPENAI_API_KEY", "")
    base_url = config.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
    model = config.get("OPENAI_MODEL", "gpt-4o-mini")

    if not api_key:
        logger.warning("OPENAI_API_KEY not configured, skipping LLM call")
        return None

    url = f"{base_url.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": _build_system_prompt()},
            {"role": "user", "content": text},
        ],
        "temperature": 0.0,
        "max_tokens": 500,
    }

    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=15)
        resp.raise_for_status()
        body = resp.json()
        raw = body["choices"][0]["message"]["content"].strip()
        # Strip accidental markdown fences
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
        return json.loads(raw)
    except Exception as exc:
        logger.warning("LLM call failed: %s", exc)
        return None


# -- Regex fallback parser ---------------------------------------------------

# Day-of-week mapping (Chinese → weekday 0=Mon..6=Sun)
_WEEKDAY_MAP: dict[str, int] = {
    "一": 0, "二": 1, "三": 2, "四": 3, "五": 4,
    "六": 5, "日": 6, "天": 6,
}

# Fuzzy time-of-day ranges: (start_hour, start_min, end_hour, end_min)
_FUZZY_TIMES: dict[str, tuple[int, int, int, int]] = {
    "上午": (8, 0, 12, 0),
    "中午": (12, 0, 13, 0),
    "下午": (14, 0, 17, 0),
    "傍晚": (17, 0, 19, 0),
    "晚上": (18, 0, 22, 0),
}

_RELATIVE_DAYS: list[tuple[str, int]] = [
    ("大后天", 3),
    ("后天", 2),
    ("明天", 1),
    ("今天", 0),
]

_WEEKDAY_PATTERN = re.compile(r"下周([一二三四五六日天])")
_MONTH_DAY_PATTERN = re.compile(r"(\d{1,2})月(\d{1,2})[日号]")
_TIME_HHMM = re.compile(r"(\d{1,2})[:：](\d{2})")
_TIME_HOUR = re.compile(r"(\d{1,2})点(半|(\d{1,2})分)?")
_PERSON_PATTERN = re.compile(r"[跟和与同](.+?)(?:在[^A-Za-z0-9]|去|到|$)")
_LOCATION_PATTERN = re.compile(r"在(.+?)(?:开会|见面|碰头|讨论|谈|写|做|喝|吃|去|$)")

# Words to strip when extracting event name
_NOISE_WORDS = {"一下", "一个", "帮我", "我要", "我想", "安排", "记得", "提醒我", "提醒"}


def _resolve_date(text: str) -> date | None:
    """Resolve a relative or absolute date from Chinese text."""
    now = datetime.now(TZ).date()

    # Relative: 今天/明天/后天/大后天
    for word, delta in _RELATIVE_DAYS:
        if word in text:
            return now + timedelta(days=delta)

    # Next week: 下周X
    m = _WEEKDAY_PATTERN.search(text)
    if m:
        target_wd = _WEEKDAY_MAP.get(m.group(1), -1)
        if target_wd >= 0:
            days_ahead = target_wd - now.weekday()
            if days_ahead <= 0:
                days_ahead += 7
            return now + timedelta(days=days_ahead)

    # Standalone: 周X (resolves to nearest future occurrence)
    standalone_weekday = re.search(r"周([一二三四五六日天])", text)
    if standalone_weekday:
        target_wd = _WEEKDAY_MAP.get(standalone_weekday.group(1), -1)
        if target_wd >= 0:
            days_ahead = target_wd - now.weekday()
            if days_ahead <= 0:
                days_ahead += 7
            return now + timedelta(days=days_ahead)

    # Month-Day: X月X日
    m = _MONTH_DAY_PATTERN.search(text)
    if m:
        try:
            month, day = int(m.group(1)), int(m.group(2))
            resolved = date(now.year, month, day)
            if resolved < now:
                resolved = date(now.year + 1, month, day)
            return resolved
        except ValueError:
            pass

    # Try dateutil as last resort
    if _HAS_DATEUTIL:
        try:
            return dateutil_parse(text, fuzzy=True, default=datetime(now.year, 1, 1)).date()
        except Exception:
            logger.debug("dateutil parse failed for text: %s", text)

    return None


def _resolve_time(text: str) -> tuple[int | None, int | None, int | None, int | None, bool]:
    """Extract time range from text. Returns (start_h, start_m, end_h, end_m, is_fuzzy)."""
    # Detect time-of-day modifier for hour adjustment
    tod_modifier = 0  # 0 = none, 12 = afternoon/evening shift
    for word, offset in [("下午", 12), ("晚上", 12), ("傍晚", 12)]:
        if word in text:
            tod_modifier = offset
            break

    # Exact HH:MM
    m = _TIME_HHMM.search(text)
    if m:
        h, minute = int(m.group(1)), int(m.group(2))
        if 0 <= h <= 23 and 0 <= minute <= 59:
            if tod_modifier and h < 12:
                h += tod_modifier
            elif tod_modifier == 0 and h < 12:
                # Time disambiguation: no AM/PM modifier, compare with current time.
                # If the stated hour has already passed today, assume PM (+12).
                now = datetime.now(TZ)
                if h <= now.hour and (now.hour - h) < 12:
                    h += 12
            end_h = h + 1 if h < 23 else h
            return h, minute, end_h, minute, False

    # X点半 / X点XX分
    m = _TIME_HOUR.search(text)
    if m:
        h = int(m.group(1))
        if 0 <= h <= 23:
            # group(2) is the full alternation capture: "半" or "XX分" or None
            captured = m.group(2)
            if captured == "半":
                minute = 30
            elif captured and captured.endswith("分"):
                minute = int(captured.replace("分", ""))
            else:
                minute = 0
            if tod_modifier and h < 12:
                h += tod_modifier
            elif tod_modifier == 0 and h < 12:
                # Time disambiguation: no AM/PM modifier, compare with current time.
                # If the stated hour has already passed today, assume PM (+12).
                now = datetime.now(TZ)
                if h <= now.hour and (now.hour - h) < 12:
                    h += 12
            end_h = h + 1 if h < 23 else h
            return h, minute, end_h, minute, False

    # Fuzzy: 上午/下午/晚上/中午/傍晚
    for word, (sh, sm, eh, em) in _FUZZY_TIMES.items():
        if word in text:
            return sh, sm, eh, em, True

    return None, None, None, None, False


def _build_datetime_range(text: str) -> tuple[dict | None, bool]:
    """Build ISO8601 datetime_range and is_fuzzy flag."""
    resolved_date = _resolve_date(text)
    date_was_explicit = resolved_date is not None
    sh, sm, eh, em, is_fuzzy = _resolve_time(text)

    if resolved_date is None:
        if sh is not None:
            resolved_date = datetime.now(TZ).date()
            is_fuzzy = True
        else:
            return None, True

    if sh is not None:
        start_dt = datetime(resolved_date.year, resolved_date.month, resolved_date.day,
                            sh, sm or 0, 0, tzinfo=TZ)
        end_dt = datetime(resolved_date.year, resolved_date.month, resolved_date.day,
                          eh or (sh + 1), em or 0, 0, tzinfo=TZ)
        # If the resolved time is already past and date wasn't explicitly specified,
        # push to tomorrow (e.g. user says "十点" at 23:00 → tomorrow 10:00).
        if start_dt <= datetime.now(TZ) and not date_was_explicit:
            start_dt += timedelta(days=1)
            end_dt += timedelta(days=1)
        return {
            "start": start_dt.isoformat(),
            "end": end_dt.isoformat(),
        }, is_fuzzy

    # No time at all → full day
    start_dt = datetime(resolved_date.year, resolved_date.month, resolved_date.day,
                        0, 0, 0, tzinfo=TZ)
    end_dt = start_dt + timedelta(hours=23, minutes=59, seconds=59)
    return {
        "start": start_dt.isoformat(),
        "end": end_dt.isoformat(),
    }, True


def _extract_person(text: str) -> str | None:
    m = _PERSON_PATTERN.search(text)
    if m:
        name = m.group(1).strip()
        # Filter out obviously non-person phrases
        if len(name) <= 10 and not re.match(r"^[\d\s,，、]+$", name):
            return name
    return None


def _extract_location(text: str) -> str | None:
    m = _LOCATION_PATTERN.search(text)
    if m:
        loc = m.group(1).strip()
        if loc and len(loc) <= 30:
            return loc
    return None


def _extract_event_name(text: str, person: str | None, location: str | None) -> str:
    """Extract a concise event name by removing known parts."""
    name = text
    # Remove person prefix
    if person:
        name = re.sub(rf"[跟和与同]\s*{re.escape(person)}", "", name)
    # Remove location
    if location:
        name = re.sub(rf"在\s*{re.escape(location)}", "", name)
    # Remove time keywords
    for word in ["明天", "后天", "大后天", "今天", "上午", "下午", "晚上", "中午", "傍晚"]:
        name = name.replace(word, "")
    # Remove remaining time patterns
    name = _TIME_HHMM.sub("", name)
    name = _TIME_HOUR.sub("", name)
    name = _MONTH_DAY_PATTERN.sub("", name)
    name = _WEEKDAY_PATTERN.sub("", name)
    # Remove noise words
    for w in _NOISE_WORDS:
        name = name.replace(w, "")
    # Clean up
    name = re.sub(r"\s+", "", name).strip("，,。.!！?？ ")
    return name or text


def _parse_with_regex(text: str) -> dict:
    """Fallback: regex-based keyword extraction with lower confidence."""
    person = _extract_person(text)
    location = _extract_location(text)
    datetime_range, is_fuzzy = _build_datetime_range(text)
    event_name = _extract_event_name(text, person, location)

    has_time = datetime_range is not None
    confidence = 0.6 if has_time else 0.3

    intent = "create_event" if (event_name and has_time) else "unknown"

    return {
        "intent": intent,
        "event_name": event_name,
        "person": person,
        "location": location,
        "datetime_range": datetime_range,
        "is_fuzzy": is_fuzzy,
        "confidence": confidence,
    }


# -- Public API ---------------------------------------------------------------

def parse_schedule(text: str, config: dict | None = None) -> dict:
    """Parse natural-language Chinese text into a structured schedule dict.

    Primary: call OpenAI-compatible LLM with Few-shot prompt.
    Fallback: regex-based keyword extraction.

    Returns a dict conforming to the fixed JSON schema:
        {
            "intent": "create_event" | "unknown",
            "event_name": str,
            "person": str | null,
            "location": str | null,
            "datetime_range": { "start": ISO8601, "end": ISO8601 } | null,
            "is_fuzzy": bool,
            "confidence": float  # 0.0 - 1.0
        }
    """
    if config is None:
        config = {
            "OPENAI_API_KEY": os.getenv("OPENAI_API_KEY", ""),
            "OPENAI_BASE_URL": os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
            "OPENAI_MODEL": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
        }

    # Try LLM first
    if config.get("OPENAI_API_KEY"):
        result = _call_openai(text, config)
        if result is not None:
            # Ensure all expected keys are present
            for key in ("intent", "event_name", "person", "location",
                        "datetime_range", "is_fuzzy", "confidence"):
                if key not in result:
                    result[key] = None if key in ("person", "location", "datetime_range") else (
                        False if key == "is_fuzzy" else 0.0
                    )
            return result

    # Fallback to regex
    logger.info("Falling back to regex parser for: %s", text)
    return _parse_with_regex(text)


# ============================================================================
# Phase 4: Multi-intent NLU (voice butler)
# ============================================================================

MULTI_INTENT_SYSTEM_PROMPT = """You are a butler assistant for a personal lifestyle app. Your job is to classify natural-language Chinese user requests into ONE of these intents and extract structured fields.

Intents:
- **create_event**: scheduling a meeting/appointment/task (existing)
- **log_meal**: user ate/drank something, wants to log a meal record
- **log_exercise**: user exercised/did sports, wants to log exercise
- **log_routine**: user reports wake time, sleep time, or standing
- **query**: user asks about their own data (calories, exercise, schedule, health)
- **create_reminder**: user wants a reminder/todo for something non-scheduled
- **unknown**: none of the above

Rules:
1. Output ONLY the JSON object. No markdown fences, no explanation.
2. timezone is UTC+8 (Asia/Shanghai). Today is {today}.
3. For create_event: follow the same schema as before (event_name, person, location, datetime_range, is_fuzzy).
4. For log_meal: extract meal_type (早餐/午餐/晚餐/加餐/零食), food_name (what they ate), estimated calories.
5. For log_exercise: extract exercise_type (跑步/游泳/健身/骑行/散步 etc.), duration_minutes (integer), intensity (轻/中/高).
6. For log_routine: extract routine_type (wake/sleep/standing), time_value (HH:MM format for wake/sleep, or just "done" for standing).
7. For query: extract query_type (calories_today/exercise_today/schedule_today/health_summary/general), query_text (the verbatim question).
8. For create_reminder: extract reminder_text (what to remind about), and optionally datetime_range for when.
9. confidence: 1.0 for clear requests, lower for ambiguous ones.

Output schema (pick the intent that matches, include only relevant fields):
{{
  "intent": "create_event | log_meal | log_exercise | log_routine | query | create_reminder | unknown",

  "event_name": "str or null",
  "person": "str or null",
  "location": "str or null",
  "datetime_range": {{"start":"ISO8601","end":"ISO8601"}} or null,
  "is_fuzzy": true/false,

  "meal_type": "str or null",
  "food_name": "str or null",
  "calories_estimate": int or null,

  "exercise_type": "str or null",
  "duration_minutes": int or null,
  "intensity": "str or null",

  "routine_type": "str or null",
  "routine_value": "str or null",

  "query_type": "str or null",
  "query_text": "str or null",

  "reminder_text": "str or null",

  "confidence": 0.0-1.0
}}

Few-shot examples:

User: 我吃了一碗牛肉面
Output: {{"intent":"log_meal","meal_type":"午餐","food_name":"牛肉面","calories_estimate":550,"confidence":0.9}}

User: 早上喝了一杯豆浆和两个包子
Output: {{"intent":"log_meal","meal_type":"早餐","food_name":"豆浆加包子","calories_estimate":400,"confidence":0.85}}

User: 晚上吃了沙拉
Output: {{"intent":"log_meal","meal_type":"晚餐","food_name":"沙拉","calories_estimate":200,"confidence":0.9}}

User: 我跑了30分钟
Output: {{"intent":"log_exercise","exercise_type":"跑步","duration_minutes":30,"intensity":"中","confidence":0.95}}

User: 游泳游了1个小时
Output: {{"intent":"log_exercise","exercise_type":"游泳","duration_minutes":60,"intensity":"高","confidence":0.95}}

User: 散步走了5000步
Output: {{"intent":"log_exercise","exercise_type":"散步","duration_minutes":40,"intensity":"轻","confidence":0.85}}

User: 我今天7点起的床
Output: {{"intent":"log_routine","routine_type":"wake","routine_value":"07:00","confidence":0.95}}

User: 晚上11点睡的
Output: {{"intent":"log_routine","routine_type":"sleep","routine_value":"23:00","confidence":0.95}}

User: 站了一会儿
Output: {{"intent":"log_routine","routine_type":"standing","routine_value":"done","confidence":0.85}}

User: 我今天吃了多少卡路里
Output: {{"intent":"query","query_type":"calories_today","query_text":"我今天吃了多少卡路里","confidence":0.95}}

User: 今天运动达标了吗
Output: {{"intent":"query","query_type":"exercise_today","query_text":"今天运动达标了吗","confidence":0.9}}

User: 我今天有什么安排
Output: {{"intent":"query","query_type":"schedule_today","query_text":"我今天有什么安排","confidence":0.95}}

User: 我今天的健康状态怎么样
Output: {{"intent":"query","query_type":"health_summary","query_text":"健康状态","confidence":0.85}}

User: 记得提醒我晚上买牛奶
Output: {{"intent":"create_reminder","reminder_text":"买牛奶","datetime_range":{{"start":"{today}T20:00:00","end":"{today}T21:00:00"}},"confidence":0.85}}

User: 提醒我明天交报告
Output: {{"intent":"create_reminder","reminder_text":"交报告","datetime_range":{{"start":"{tomorrow}T10:00:00","end":"{tomorrow}T12:00:00"}},"confidence":0.85}}

User: 明天下午3点跟老张开项目会
Output: {{"intent":"create_event","event_name":"开项目会","person":"老张","location":null,"datetime_range":{{"start":"{tomorrow}T15:00:00","end":"{tomorrow}T16:00:00"}},"is_fuzzy":false,"confidence":0.95}}

User: 你好
Output: {{"intent":"unknown","confidence":0.0}}
"""


def _build_multi_intent_prompt() -> str:
    now = datetime.now(TZ)
    slots = dict(_TODAY_SLOTS)
    slots["current_time"] = f"{now.hour:02d}:{now.minute:02d}"
    slots["current_hour"] = now.hour
    return MULTI_INTENT_SYSTEM_PROMPT.format(**slots)


def _call_openai_multi(text: str, config: dict) -> dict | None:
    """Call LLM with multi-intent prompt; return parsed JSON or None."""
    api_key = config.get("OPENAI_API_KEY", "")
    base_url = config.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
    model = config.get("OPENAI_MODEL", "gpt-4o-mini")

    if not api_key:
        logger.warning("OPENAI_API_KEY not configured, skipping LLM call")
        return None

    url = f"{base_url.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": _build_multi_intent_prompt()},
            {"role": "user", "content": text},
        ],
        "temperature": 0.0,
        "max_tokens": 500,
    }

    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=15)
        resp.raise_for_status()
        body = resp.json()
        raw = body["choices"][0]["message"]["content"].strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
        return json.loads(raw)
    except Exception as exc:
        logger.warning("Multi-intent LLM call failed: %s", exc)
        return None


# -- Multi-intent regex fallback ------------------------------------------------

# Keywords for intent detection in regex fallback
_MEAL_KEYWORDS = ["吃了", "喝", "早餐", "午饭", "午餐", "晚饭", "晚餐", "加餐", "零食", "饭", "菜", "面", "包子",
                   "饺子", "沙拉", "水果", "鸡", "鱼", "牛", "猪", "虾", "蛋", "奶", "豆浆", "咖啡", "茶"]
_EXERCISE_KEYWORDS = ["跑", "游泳", "健身", "锻炼", "运动", "骑", "散步", "走", "步", "瑜伽", "跳绳", "举铁", "打球"]
_ROUTINE_KEYWORDS = ["起床", "起", "醒来", "睡", "入睡", "站"]
_QUERY_KEYWORDS = ["多少", "怎么样", "如何", "什么", "状态", "达标", "安排", "计划", "卡路里", "热量", "健康"]
_REMINDER_KEYWORDS = ["提醒", "记得", "别忘了", "别忘了", "帮我记"]

_FOOD_PATTERN = re.compile(r"(?:吃了?|喝了?)(.+?)(?:[，,。.]|$)")
_MEAL_TYPE_PATTERN = re.compile(r"(早餐|午饭|午餐|晚饭|晚餐|加餐|零食)")
_DURATION_PATTERN = re.compile(r"(\d+)\s*(分钟|小时|个?小时)?")
_STEPS_PATTERN = re.compile(r"(\d+)\s*步")
_EXERCISE_TYPE_PATTERN = re.compile(r"(跑步|游泳|健身|骑行|散步|瑜伽|跳绳|打球|举铁)")
_CALORIE_QUERY = re.compile(r"(?:多少|几个|几).*(?:卡路里|热量|大卡|千卡)")
_EXERCISE_QUERY = re.compile(r"运动.*(?:怎么样|达标|多少|够)")
_SCHEDULE_QUERY = re.compile(r"(?:今天|今日|明天).*(?:安排|计划|日程|行程|做什么)")
_TIME_PATTERN = re.compile(r"(\d{1,2})[点:：](\d{2})?")


def _detect_intent_regex(text: str) -> str:
    """Quick keyword-based intent detection for regex fallback."""
    # Query patterns (check first - can overlap with others)
    if _CALORIE_QUERY.search(text):
        return "query"
    if _EXERCISE_QUERY.search(text):
        return "query"
    if _SCHEDULE_QUERY.search(text):
        return "query"
    if any(kw in text for kw in _QUERY_KEYWORDS) and (
        "?" in text or "？" in text or "吗" in text or "了" not in text[:4]
    ):
        return "query"

    # Reminder
    if any(kw in text for kw in _REMINDER_KEYWORDS):
        return "create_reminder"

    # Meal
    if any(kw in text for kw in _MEAL_KEYWORDS):
        return "log_meal"

    # Exercise
    if any(kw in text for kw in _EXERCISE_KEYWORDS):
        return "log_exercise"

    # Routine
    if any(kw in text for kw in _ROUTINE_KEYWORDS):
        return "log_routine"

    # Fallback: treat as schedule if it has time info, else unknown
    has_time = bool(_TIME_PATTERN.search(text)) or any(
        w in text for w in ["今天", "明天", "后天", "上午", "下午", "晚上", "周"]
    )
    return "create_event" if has_time else "unknown"


def _parse_meal_regex(text: str) -> dict:
    """Regex fallback for log_meal intent."""
    meal_type = None
    mt = _MEAL_TYPE_PATTERN.search(text)
    if mt:
        meal_type = mt.group(1)
    else:
        # Infer meal type by time of day
        now = datetime.now(TZ)
        if now.hour < 10:
            meal_type = "早餐"
        elif now.hour < 14:
            meal_type = "午餐"
        else:
            meal_type = "晚餐"

    food_name = ""
    fm = _FOOD_PATTERN.search(text)
    if fm:
        food_name = fm.group(1).strip()
    else:
        # Use the whole text minus known prefixes
        food_name = text
        for prefix in ["我", "刚刚", "刚才", "中午", "早上", "晚上"]:
            food_name = food_name.replace(prefix, "", 1)
        food_name = food_name.strip()

    # Rough calorie estimate based on food keywords
    calories = 300  # default
    high_cal = ["牛", "猪", "鸡腿", "炸", "炒", "红烧", "油", "肉", "面", "饭"]
    low_cal = ["沙拉", "水果", "蔬菜", "水", "茶", "咖啡"]
    if any(kw in text for kw in high_cal):
        calories = 600
    if any(kw in text for kw in low_cal):
        calories = 200

    return {
        "intent": "log_meal",
        "meal_type": meal_type,
        "food_name": food_name if food_name else text,
        "calories_estimate": calories,
        "confidence": 0.6,
    }


def _parse_exercise_regex(text: str) -> dict:
    """Regex fallback for log_exercise intent."""
    exercise_type = "运动"
    et = _EXERCISE_TYPE_PATTERN.search(text)
    if et:
        exercise_type = et.group(1)

    duration = 30
    dm = _DURATION_PATTERN.search(text)
    if dm:
        val = int(dm.group(1))
        unit = dm.group(2) or ""
        if "小时" in unit:
            duration = val * 60
        else:
            duration = val

    sm = _STEPS_PATTERN.search(text)
    if sm:
        steps = int(sm.group(1))
        duration = max(steps // 100, 20)

    # Intensity heuristic
    if "散步" in text or "走" in text:
        intensity = "轻"
    elif "跑" in text or "游泳" in text:
        intensity = "高"
    else:
        intensity = "中"

    return {
        "intent": "log_exercise",
        "exercise_type": exercise_type,
        "duration_minutes": duration,
        "intensity": intensity,
        "confidence": 0.65,
    }


def _parse_routine_regex(text: str) -> dict:
    """Regex fallback for log_routine intent."""
    routine_type = "wake"
    routine_value = None

    if "睡" in text or "入睡" in text:
        routine_type = "sleep"
    elif "��" in text:
        routine_type = "standing"
        routine_value = "done"
    else:
        routine_type = "wake"

    if routine_type in ("wake", "sleep"):
        tm = _TIME_PATTERN.search(text)
        if tm:
            h = int(tm.group(1))
            m = int(tm.group(2)) if tm.group(2) else 0
            routine_value = f"{h:02d}:{m:02d}"

    return {
        "intent": "log_routine",
        "routine_type": routine_type,
        "routine_value": routine_value,
        "confidence": 0.6,
    }


def _parse_query_regex(text: str) -> dict:
    """Regex fallback for query intent."""
    if _CALORIE_QUERY.search(text):
        query_type = "calories_today"
    elif _EXERCISE_QUERY.search(text):
        query_type = "exercise_today"
    elif _SCHEDULE_QUERY.search(text):
        query_type = "schedule_today"
    else:
        query_type = "general"

    return {
        "intent": "query",
        "query_type": query_type,
        "query_text": text,
        "confidence": 0.55,
    }


def _parse_reminder_regex(text: str) -> dict:
    """Regex fallback for create_reminder intent."""
    # Strip reminder keywords to get the actual reminder text
    reminder_text = text
    for kw in ["提醒我", "提醒", "记得", "别忘了", "别忘了", "帮我记"]:
        reminder_text = reminder_text.replace(kw, "", 1)
    reminder_text = reminder_text.strip()

    datetime_range, _ = _build_datetime_range(text)

    return {
        "intent": "create_reminder",
        "reminder_text": reminder_text,
        "datetime_range": datetime_range,
        "confidence": 0.55,
    }


def _parse_multi_regex(text: str) -> dict:
    """Regex fallback for all intents."""
    intent = _detect_intent_regex(text)

    if intent == "log_meal":
        return _parse_meal_regex(text)
    if intent == "log_exercise":
        return _parse_exercise_regex(text)
    if intent == "log_routine":
        return _parse_routine_regex(text)
    if intent == "query":
        return _parse_query_regex(text)
    if intent == "create_reminder":
        return _parse_reminder_regex(text)
    if intent == "create_event":
        return _parse_with_regex(text)

    return {"intent": "unknown", "confidence": 0.0}


# -- Public API: multi-intent ------------------------------------------------

def parse_text(text: str, config: dict | None = None) -> dict:
    """Parse natural-language Chinese text with multi-intent NLU.

    Supports: create_event, log_meal, log_exercise, log_routine, query, create_reminder.

    Primary: call OpenAI-compatible LLM with multi-intent Few-shot prompt.
    Fallback: keyword-based regex intent detection + entity extraction.

    Returns a dict with at minimum:
        {"intent": "...", "confidence": 0.0-1.0}
    plus intent-specific fields.
    """
    if config is None:
        config = {
            "OPENAI_API_KEY": os.getenv("OPENAI_API_KEY", ""),
            "OPENAI_BASE_URL": os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
            "OPENAI_MODEL": os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
        }

    # Try LLM first with multi-intent prompt
    if config.get("OPENAI_API_KEY"):
        result = _call_openai_multi(text, config)
        if result is not None:
            if "intent" not in result:
                result["intent"] = "unknown"
            if "confidence" not in result:
                result["confidence"] = 0.5
            return result

    # Fallback to regex
    logger.info("Falling back to multi-intent regex parser for: %s", text)
    return _parse_multi_regex(text)
