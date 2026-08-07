"""Controlled per-user memory built only from explicit behavior signals."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

from ..extensions import db
from ..models_habits import AgentExperience, MemoryFeedback, MemorySetting, UserMemory


def memory_enabled(user_id: int) -> bool:
    setting = db.session.get(MemorySetting, user_id)
    return setting is None or setting.learning_enabled


def set_memory_enabled(user_id: int, enabled: bool) -> MemorySetting:
    setting = db.session.get(MemorySetting, user_id)
    if setting is None:
        setting = MemorySetting(user_id=user_id)
        db.session.add(setting)
    setting.learning_enabled = enabled
    db.session.commit()
    return setting


def record_feedback(
    user_id: int,
    action: str,
    *,
    entity_type: str = "agent_action",
    entity_id: int | str | None = None,
    source_text: str = "",
    details: dict[str, Any] | None = None,
    learn: bool = True,
) -> MemoryFeedback:
    feedback = MemoryFeedback(
        user_id=user_id,
        action=action[:32],
        entity_type=entity_type[:32],
        entity_id=str(entity_id)[:64] if entity_id is not None else None,
        source_text=source_text.strip()[:500],
        details=details or {},
    )
    db.session.add(feedback)
    if learn and action in {"confirmed", "modified", "completed"} and memory_enabled(user_id):
        _learn_from_details(user_id, details or {}, source_text)
    db.session.commit()
    return feedback


def _learn_from_details(user_id: int, details: dict[str, Any], source_text: str) -> None:
    intent = str(details.get("intent") or "")
    if intent == "create_event":
        title = str(details.get("event_name") or details.get("title") or "").strip()
        start = _parse_datetime(details.get("start") or (details.get("datetime_range") or {}).get("start"))
        end = _parse_datetime(details.get("end") or (details.get("datetime_range") or {}).get("end"))
        if title and start:
            duration = int((end - start).total_seconds() // 60) if end and end > start else 60
            value = {"title": title, "hour": start.hour, "minute": start.minute,
                     "weekday": start.weekday(), "duration_minutes": duration}
            summary = f"用户确认过在{start.strftime('%H:%M')}安排{title}，通常持续约{duration}分钟"
            _upsert_memory(user_id, "schedule", _normalize_key(title), summary, value)
    elif intent == "log_exercise":
        exercise = str(details.get("exercise_type") or "运动").strip()
        duration = int(details.get("duration_minutes") or 30)
        _upsert_memory(
            user_id, "exercise", _normalize_key(exercise),
            f"用户记录过{exercise}，常见时长约{duration}分钟",
            {"exercise_type": exercise, "duration_minutes": duration},
        )
    elif intent == "log_meal":
        meal_type = str(details.get("meal_type") or "餐食").strip()
        food = str(details.get("food_name") or "").strip()
        if food:
            _upsert_memory(
                user_id, "meal", _normalize_key(f"{meal_type}:{food}"),
                f"用户确认记录过{meal_type}：{food}",
                {"meal_type": meal_type, "food_name": food},
            )
    elif intent == "log_routine":
        routine = str(details.get("routine_type") or "routine").strip()
        value = str(details.get("routine_value") or "").strip()
        if value:
            _upsert_memory(
                user_id, "routine", _normalize_key(routine),
                f"用户确认的{routine}习惯时间为{value}",
                {"routine_type": routine, "routine_value": value},
            )

    if source_text and intent and intent not in {"unknown", "query"}:
        _remember_confirmed_expression(user_id, source_text, intent, details)


def _upsert_memory(
    user_id: int,
    category: str,
    memory_key: str,
    summary: str,
    value: dict[str, Any],
) -> UserMemory:
    row = UserMemory.query.filter_by(
        user_id=user_id, category=category, memory_key=memory_key,
    ).first()
    now = datetime.now(timezone.utc)
    if row is None:
        row = UserMemory(
            user_id=user_id, category=category, memory_key=memory_key,
            summary=summary[:500], value=value, confidence=0.6,
            evidence_count=1, last_confirmed_at=now,
        )
        db.session.add(row)
    else:
        row.summary = summary[:500]
        row.value = value
        row.evidence_count += 1
        row.confidence = min(0.95, 0.55 + row.evidence_count * 0.08)
        row.last_confirmed_at = now
        row.active = True
    return row


def relevant_memory_context(user_id: int | None, text: str, limit: int = 6) -> str:
    if not user_id or not memory_enabled(user_id):
        return ""
    rows = UserMemory.query.filter_by(user_id=user_id, active=True).order_by(
        UserMemory.confidence.desc(), UserMemory.last_confirmed_at.desc(),
    ).limit(40).all()
    tokens = set(re.findall(r"[\w\u4e00-\u9fff]+", text.lower()))
    ranked = sorted(
        rows,
        key=lambda row: (
            any(token in (row.summary or "").lower() for token in tokens),
            row.confidence,
            row.evidence_count,
        ),
        reverse=True,
    )[:max(1, min(limit, 10))]
    if not ranked:
        return ""
    return "\n".join(f"- {row.summary}" for row in ranked)


def _remember_confirmed_expression(user_id: int, source_text: str, intent: str, parsed: dict[str, Any]) -> None:
    from .agent import _normalize_experience_text

    normalized = _normalize_experience_text(source_text)
    if not normalized:
        return
    row = AgentExperience.query.filter_by(user_id=user_id, normalized_text=normalized).first()
    cleaned = {key: value for key, value in parsed.items() if key not in {"llm_warning", "source_text"}}
    if row is None:
        db.session.add(AgentExperience(
            user_id=user_id, source_text=source_text[:500], normalized_text=normalized,
            intent=intent, parsed=cleaned,
        ))
    else:
        row.source_text = source_text[:500]
        row.intent = intent
        row.parsed = cleaned
        row.sample_count += 1
        row.last_used_at = datetime.now(timezone.utc)


def _normalize_key(value: str) -> str:
    return re.sub(r"\s+", "", value.strip().lower())[:160] or "default"


def _parse_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value))
    except ValueError:
        return None
