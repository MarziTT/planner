"""
Meal service — photo OCR, meal recording, daily summary.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §11
"""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Any

from ..extensions import db
from ..models_habits import MealRecord, OcrCache
from .llm_gateway import chat_completion
from .time_service import get_clock

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Meal OCR vision prompt
# ---------------------------------------------------------------------------

MEAL_OCR_SYSTEM_PROMPT = """You are a Chinese meal photo analyzer. Look at the food image and identify each dish.

For each dish, provide:
1. name: 菜品名称 (Chinese, e.g. "西红柿炒鸡蛋", "米饭", "拿铁咖啡")
2. calories: estimated calories in kcal (integer, rough estimate is fine)
3. category: 分类, one of: "主食", "蔬菜", "肉类", "海鲜", "豆制品", "汤品", "水果", "饮料", "零食", "其他"

Return ONLY a JSON array of objects, like:
[
  {"name": "西红柿炒鸡蛋", "calories": 220, "category": "蔬菜"},
  {"name": "米饭", "calories": 200, "category": "主食"}
]

If the image is not food or you cannot identify anything, return an empty array [].
Do NOT include markdown fences or any other text — ONLY the JSON array."""


def _build_meal_ocr_payload(image_base64: str, api_key: str, base_url: str, model: str) -> dict[str, Any]:
    return {
        "model": model,
        "messages": [
            {"role": "system", "content": MEAL_OCR_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_base64}",
                            "detail": "high",
                        },
                    }
                ],
            },
        ],
        "max_tokens": 1024,
        "temperature": 0.0,
    }


def _call_vision_api(image_bytes: bytes, config: dict[str, str]) -> list[dict[str, Any]]:
    """Call OpenAI vision API and return parsed dish list."""
    image_base64 = base64.b64encode(image_bytes).decode("ascii")
    content = chat_completion(
        _build_meal_ocr_payload(image_base64, "", "", "")["messages"],
        config,
        temperature=0.0,
        max_tokens=1024,
        timeout=60,
    )
    if content is None:
        return []
    content = content.strip()
    if content.startswith("```"):
        content = re.sub(r"^```(?:json)?\s*", "", content)
        content = re.sub(r"\s*```$", "", content)

    try:
        dishes = json.loads(content)
        if not isinstance(dishes, list):
            return []
        # Normalize each dish dict
        result = []
        for d in dishes:
            if isinstance(d, dict) and d.get("name"):
                result.append({
                    "name": str(d.get("name", "")).strip(),
                    "calories": int(d.get("calories", 0)) if d.get("calories") else None,
                    "category": str(d.get("category", "其他")).strip(),
                })
        return result
    except (json.JSONDecodeError, TypeError) as exc:
        logger.warning("Meal OCR JSON parse failed; raw: %s", content[:200])
        return []


# ---------------------------------------------------------------------------
# Service functions
# ---------------------------------------------------------------------------


def ocr_meal(image_bytes: bytes, user_id: int, config: dict[str, str]) -> list[dict[str, Any]]:
    """Run meal OCR on an image, with caching.

    Args:
        image_bytes: Raw image bytes.
        user_id: Requesting user ID.
        config: Flask app config dict.

    Returns:
        List of dish dicts: [{"name": ..., "calories": ..., "category": ...}]
    """
    image_hash = hashlib.sha256(image_bytes).hexdigest()

    # Check cache
    cached = OcrCache.query.filter_by(user_id=user_id, image_hash=image_hash).first()
    if cached is not None and cached.parsed is not None:
        logger.info("Meal OCR cache hit for hash %s", image_hash)
        return cached.parsed if isinstance(cached.parsed, list) else []

    try:
        dishes = _call_vision_api(image_bytes, config)
    except Exception as exc:
        logger.warning("Meal OCR vision call failed: %s", exc)
        dishes = []

    # Cache result
    existing = OcrCache.query.filter_by(user_id=user_id, image_hash=image_hash).first()
    if existing is not None:
        existing.parsed = dishes
        existing.raw_text = json.dumps(dishes, ensure_ascii=False)
        existing.processed_at = get_clock().now_utc()
    else:
        entry = OcrCache(
            user_id=user_id,
            image_hash=image_hash,
            raw_text=json.dumps(dishes, ensure_ascii=False),
            parsed=dishes,
        )
        db.session.add(entry)
    db.session.commit()

    return dishes


def create_meal_record(
    user_id: int,
    meal_type: str,
    items: list[dict[str, Any]],
    source: str = "photo",
    recorded_at: datetime | None = None,
) -> MealRecord:
    """Create a meal record in the database.

    Args:
        user_id: User ID.
        meal_type: 'breakfast' / 'lunch' / 'dinner' / 'snack'.
        items: List of dish dicts like [{"name": "米饭", "calories": 200}].
        source: 'photo' / 'manual' / 'popup'.
        recorded_at: When the meal was actually eaten (defaults to now).

    Returns:
        The created MealRecord.
    """
    record = MealRecord(
        user_id=user_id,
        meal_type=meal_type,
        items=items,
        source=source,
        recorded_at=recorded_at or get_clock().now_utc(),
    )
    db.session.add(record)
    db.session.commit()
    return record


def get_today_meals(user_id: int) -> list[dict[str, Any]]:
    """Get today's meal records for a user.

    Args:
        user_id: User ID.

    Returns:
        List of meal record dicts.
    """
    today_start = get_clock().now_utc().replace(hour=0, minute=0, second=0, microsecond=0)
    records = (
        MealRecord.query
        .filter_by(user_id=user_id)
        .filter(MealRecord.recorded_at >= today_start)
        .order_by(MealRecord.recorded_at.asc())
        .all()
    )
    return [_meal_to_dict(r) for r in records]


def get_meal_history(user_id: int, days: int = 7) -> list[dict[str, Any]]:
    """Get meal history for the past N days.

    Args:
        user_id: User ID.
        days: Number of days to look back.

    Returns:
        List of meal record dicts.
    """
    since = get_clock().now_utc() - timedelta(days=days)
    records = (
        MealRecord.query
        .filter_by(user_id=user_id)
        .filter(MealRecord.recorded_at >= since)
        .order_by(MealRecord.recorded_at.desc())
        .all()
    )
    return [_meal_to_dict(r) for r in records]


def get_daily_summary(user_id: int) -> dict[str, Any]:
    """Get a summary of today's meals with calorie totals.

    Args:
        user_id: User ID.

    Returns:
        Dict with records, total_calories, by_type.
    """
    today_start = get_clock().now_utc().replace(hour=0, minute=0, second=0, microsecond=0)
    records = (
        MealRecord.query
        .filter_by(user_id=user_id)
        .filter(MealRecord.recorded_at >= today_start)
        .order_by(MealRecord.recorded_at.asc())
        .all()
    )

    total_calories = 0
    by_type: dict[str, dict[str, Any] | None] = {
        "breakfast": None,
        "lunch": None,
        "dinner": None,
        "snack": None,
    }

    for r in records:
        d = _meal_to_dict(r)
        by_type[r.meal_type] = d
        total_calories += _calories_from_items(r.items)

    return {
        "date": today_start.isoformat(),
        "total_calories": total_calories,
        "meal_count": len(records),
        "by_type": by_type,
        "records": [_meal_to_dict(r) for r in records],
    }


def get_weekly_average_calories(user_id: int) -> float:
    """Get average daily calories over the past 7 days."""
    since = get_clock().now_utc() - timedelta(days=7)
    records = (
        MealRecord.query
        .filter_by(user_id=user_id)
        .filter(MealRecord.recorded_at >= since)
        .all()
    )

    # Group by date
    by_date: dict[str, int] = {}
    for r in records:
        date_key = r.recorded_at.strftime("%Y-%m-%d")
        by_date[date_key] = by_date.get(date_key, 0) + _calories_from_items(r.items)

    if not by_date:
        return 0.0

    total = sum(by_date.values())
    # Count distinct days with at least one record
    return round(total / max(len(by_date), 1), 1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _calories_from_items(items: list | None) -> int:
    """Sum calories from a list of item dicts."""
    if not items or not isinstance(items, list):
        return 0
    return sum(
        (item.get("calories") or 0)
        for item in items
        if isinstance(item, dict)
    )


def _meal_to_dict(record: MealRecord) -> dict[str, Any]:
    return {
        "id": record.id,
        "meal_type": record.meal_type,
        "items": record.items if isinstance(record.items, list) else [],
        "recorded_at": record.recorded_at.isoformat() if record.recorded_at else None,
        "source": record.source,
    }
