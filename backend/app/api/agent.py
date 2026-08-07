"""
Agent API blueprint — Jarvis Agent (Phase 1 + Phase 4) endpoints.

POST /api/v1/agent/parse        — LLM semantic schedule parsing (legacy)
POST /api/v1/agent/parse-multi  — Multi-intent NLU (voice butler)
POST /api/v1/agent/execute      — Execute parsed intent action
POST /api/v1/agent/schedule     — create calendar event from parsed result
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, timedelta

from flask import Blueprint, current_app, g, request

from ..extensions import db
from ..models import Event, Todo
from ..models_habits import ExerciseRecord, MealRecord
from ..services.agent import parse_schedule, parse_text, suggest_commands
from ..services.meal_service import create_meal_record
from ..services import exercise_service
from ..services.routine_service import record_wake
from ..services.memory_service import record_feedback

from .common import auth_required, failure, success

logger = logging.getLogger(__name__)

agent_bp = Blueprint("agent", __name__)

TZ = timezone(timedelta(hours=8))


def _read_llm_config() -> dict:
    """Read LLM credentials — user settings first, then app config / env."""
    from ..models import AppSetting

    fallback = {
        "OPENAI_API_KEY": current_app.config.get("OPENAI_API_KEY", ""),
        "OPENAI_BASE_URL": current_app.config.get("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        "OPENAI_MODEL": current_app.config.get("OPENAI_MODEL", "gpt-4o-mini"),
        "OPENAI_MODELS": current_app.config.get("OPENAI_MODELS", ""),
        "OPENAI_VISION_MODELS": current_app.config.get("OPENAI_VISION_MODELS", ""),
        "LLM_PROVIDERS": current_app.config.get("LLM_PROVIDERS", ""),
        "DEEPSEEK_API_BASE_URL": current_app.config.get("DEEPSEEK_API_BASE_URL", ""),
        "DEEPSEEK_MODEL": current_app.config.get("DEEPSEEK_MODEL", "deepseek-r1:7b"),
        "DEEPSEEK_API_KEY": current_app.config.get("DEEPSEEK_API_KEY", ""),
        "DEEPSEEK_TIMEOUT_SECONDS": current_app.config.get("DEEPSEEK_TIMEOUT_SECONDS", 120),
    }

    try:
        user_settings = AppSetting.query.filter_by(user_id=g.current_user.id).first()
    except Exception:
        return fallback

    if user_settings is None:
        return fallback

    return {
        "OPENAI_API_KEY": user_settings.llm_api_key or fallback["OPENAI_API_KEY"],
        "OPENAI_BASE_URL": user_settings.llm_base_url or fallback["OPENAI_BASE_URL"],
        "OPENAI_MODEL": user_settings.llm_model or fallback["OPENAI_MODEL"],
        "OPENAI_MODELS": fallback["OPENAI_MODELS"],
        "OPENAI_VISION_MODELS": fallback["OPENAI_VISION_MODELS"],
        "LLM_PROVIDERS": fallback["LLM_PROVIDERS"],
        "DEEPSEEK_API_BASE_URL": fallback["DEEPSEEK_API_BASE_URL"],
        "DEEPSEEK_MODEL": fallback["DEEPSEEK_MODEL"],
        "DEEPSEEK_API_KEY": fallback["DEEPSEEK_API_KEY"],
        "DEEPSEEK_TIMEOUT_SECONDS": fallback["DEEPSEEK_TIMEOUT_SECONDS"],
    }


@agent_bp.post("/parse")
@auth_required
def parse():
    """Semantically parse a natural-language scheduling request.

    Request:  {"text": "后天下午跟老张喝咖啡"}
    Response: {"intent":"create_event","event_name":"喝咖啡","person":"老张",...}
    """
    payload = request.get_json(silent=True) or {}
    text = (payload.get("text") or "").strip()
    if not text:
        return failure("validation_error", "text is required", status=422)

    config = _read_llm_config()
    result = parse_schedule(text, config)
    result["source_text"] = text
    return success(result)


@agent_bp.post("/parse-multi")
@auth_required
def parse_multi():
    """Multi-intent NLU — classify ANY natural-language request.

    Supports: create_event, log_meal, log_exercise, log_routine, query, create_reminder.

    Request:  {"text": "我吃了一碗牛肉面"}
    Response: {"intent":"log_meal","meal_type":"午餐","food_name":"牛肉面","calories_estimate":550,...}
    """
    payload = request.get_json(silent=True) or {}
    text = (payload.get("text") or "").strip()
    persona_preset = (payload.get("persona_preset") or "default").strip()
    if not text:
        return failure("validation_error", "text is required", status=422)

    config = _read_llm_config()
    result = parse_text(
        text,
        config,
        user_id=g.current_user.id,
        persona_preset=persona_preset,
    )
    result["source_text"] = text
    return success(result)


@agent_bp.post("/execute")
@auth_required
def execute():
    """Execute a parsed intent — the ACT part of the voice butler loop.

    Receives the parsed JSON from /parse-multi (or anything with an "intent" field)
    and performs the corresponding action.

    Supported intents:
      - log_meal     → create MealRecord
      - log_exercise → create ExerciseRecord
      - log_routine  → record wake/sleep/standing
      - create_event → create Event (same as /schedule)
      - create_reminder → create Todo
      - query        → aggregate and return answer

    Request:  {"intent":"log_meal","meal_type":"午餐","food_name":"牛肉面","calories_estimate":550}
    Response: {"action":"meal_logged","record_id":42,"summary":"已记录午餐：牛肉面 (~550kcal)"}
    """
    payload = request.get_json(silent=True) or {}
    intent = (payload.get("intent") or "").strip()

    if not intent:
        return failure("validation_error", "intent is required", status=422)

    user_id = g.current_user.id

    try:
        if intent == "log_meal":
            response = _execute_log_meal(user_id, payload)
        elif intent == "log_exercise":
            response = _execute_log_exercise(user_id, payload)
        elif intent == "log_routine":
            response = _execute_log_routine(user_id, payload)
        elif intent == "create_event":
            response = _execute_create_event(user_id, payload)
        elif intent == "create_reminder":
            response = _execute_create_reminder(user_id, payload)
        elif intent == "query":
            return _execute_query(user_id, payload)
        else:
            return failure(
                "unknown_intent",
                f"Intent '{intent}' is not executable; try re-phrasing",
                status=422,
            )
        if response[1] < 300:
            data = response[0].get("data") or {}
            entity_id = data.get("event_id") or data.get("todo_id") or data.get("record_id")
            record_feedback(
                user_id,
                "confirmed",
                entity_type=intent,
                entity_id=entity_id,
                source_text=str(payload.get("source_text") or ""),
                details=payload,
            )
        return response
    except Exception:
        logger.exception("Execute intent '%s' failed", intent)
        return failure("execute_failed", "Failed to execute action", status=500)


# -- Intent executors ----------------------------------------------------------

def _execute_log_meal(user_id: int, payload: dict) -> tuple:
    meal_type_map = {
        "早餐": "breakfast", "午饭": "lunch", "午餐": "lunch",
        "晚饭": "dinner", "晚餐": "dinner", "加餐": "snack", "零食": "snack",
    }
    raw_type = (payload.get("meal_type") or "午餐")
    meal_type = meal_type_map.get(raw_type, "lunch")

    food_name = (payload.get("food_name") or "").strip()
    calories = payload.get("calories_estimate") or 300

    items = [{"name": food_name or "未命名餐食", "calories": int(calories)}]
    record = create_meal_record(
        user_id=user_id,
        meal_type=meal_type,
        items=items,
        source="voice",
    )

    summary = f"已记录{raw_type}：{food_name or '餐食'} (~{int(calories)}kcal)"
    return success({"action": "meal_logged", "record_id": record.id, "summary": summary}, status=201)


def _execute_log_exercise(user_id: int, payload: dict) -> tuple:
    exercise_type = (payload.get("exercise_type") or "运动").strip()
    duration = payload.get("duration_minutes") or 30
    intensity = payload.get("intensity") or "中"

    # Map intensity to rough calories estimate
    cal_per_min = {"轻": 4, "中": 7, "高": 10}
    calories = int(duration) * cal_per_min.get(intensity, 7)

    record = ExerciseRecord(
        user_id=user_id,
        exercise_type=exercise_type,
        duration_minutes=int(duration),
        calories=calories,
        source="voice",
    )
    db.session.add(record)
    db.session.commit()

    summary = f"已记录运动：{exercise_type} {int(duration)}分钟 (~{calories}kcal)"
    return success({"action": "exercise_logged", "record_id": record.id, "summary": summary}, status=201)


def _execute_log_routine(user_id: int, payload: dict) -> tuple:
    routine_type = (payload.get("routine_type") or "wake")
    routine_value = (payload.get("routine_value") or "")

    if routine_type == "wake":
        time_str = routine_value or "08:00"
        try:
            # Validate format
            parts = time_str.split(":")
            int(parts[0]), int(parts[1]) if len(parts) > 1 else 0
            record_wake(user_id, time_str)
            summary = f"已记录起床时间：{time_str}"
        except (ValueError, IndexError):
            return failure("invalid_time", f"Cannot parse time: {time_str}", status=422)

    elif routine_type == "sleep":
        summary = f"已记录睡眠：{routine_value or '已确认'}"

    elif routine_type == "standing":
        summary = "已记录站立完成"

    else:
        summary = f"已记录作息：{routine_type}"

    return success({"action": "routine_logged", "routine_type": routine_type, "summary": summary}, status=201)


def _execute_create_event(user_id: int, payload: dict) -> tuple:
    title = (payload.get("event_name") or payload.get("title") or "").strip()
    if not title:
        return failure("validation_error", "event_name is required", status=422)

    dr = payload.get("datetime_range") or {}
    start_raw = (dr.get("start") or payload.get("start") or "").strip()
    end_raw = (dr.get("end") or payload.get("end") or "").strip()

    if not start_raw or not end_raw:
        return failure("validation_error", "start and end times are required", status=422)

    try:
        starts_at = datetime.fromisoformat(start_raw)
        ends_at = datetime.fromisoformat(end_raw)
    except ValueError as exc:
        return failure("validation_error", f"Invalid datetime: {exc}", status=422)

    person = (payload.get("person") or "")
    location = (payload.get("location") or "")
    note_parts = [p for p in [person, location] if p]
    note = " · ".join(note_parts) if note_parts else ""

    event = Event(
        user_id=user_id,
        title=title,
        note=note,
        starts_at=starts_at,
        ends_at=ends_at,
        status="planned",
    )
    db.session.add(event)
    db.session.commit()

    is_fuzzy = payload.get("is_fuzzy", False)
    fuzzy_note = " (时间已自动补全)" if is_fuzzy else ""
    summary = f"已安排：{title}{fuzzy_note}"
    return success({"action": "event_created", "event_id": event.id, "summary": summary}, status=201)


def _execute_create_reminder(user_id: int, payload: dict) -> tuple:
    reminder_text = (payload.get("reminder_text") or "").strip()
    if not reminder_text:
        return failure("validation_error", "reminder_text is required", status=422)

    dr = payload.get("datetime_range") or {}
    due_raw = (dr.get("start") or dr.get("end") or "")

    todo = Todo(
        user_id=user_id,
        title=reminder_text,
    )
    if due_raw:
        try:
            todo.due_date = datetime.fromisoformat(due_raw)
        except ValueError:
            pass  # Soft fail — still create without due date

    db.session.add(todo)
    db.session.commit()

    summary = f"已创建提醒：{reminder_text}"
    return success({"action": "reminder_created", "todo_id": todo.id, "summary": summary}, status=201)


def _execute_query(user_id: int, payload: dict) -> tuple:
    query_type = (payload.get("query_type") or "general")
    query_text = (payload.get("query_text") or "")

    answer = _build_query_answer(user_id, query_type, query_text)
    return success({"action": "query_answered", "query_type": query_type, "answer": answer})


def _build_query_answer(user_id: int, query_type: str, query_text: str) -> str:
    """Build a natural-language answer for a query intent."""
    now = datetime.now(TZ)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    if query_type == "calories_today":
        meals = MealRecord.query.filter(
            MealRecord.user_id == user_id,
            MealRecord.recorded_at >= today_start,
        ).all()
        total_cal = 0
        for m in meals:
            items = m.items or []
            if isinstance(items, list):
                total_cal += sum(item.get("calories", 0) for item in items if isinstance(item, dict))
        return f"你今天已经摄入了约 {total_cal} kcal。" + (
            f" 记录了 {len(meals)} 餐。" if meals else " 还没记录任何餐食哦。"
        )

    if query_type == "exercise_today":
        exercises = ExerciseRecord.query.filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.recorded_at >= today_start,
        ).all()
        total_min = sum(e.duration_minutes or 0 for e in exercises)
        total_cal = sum(e.calories or 0 for e in exercises)
        if exercises:
            types = ", ".join(set(e.exercise_type for e in exercises if e.exercise_type))
            return f"今天运动了 {total_min} 分钟（{types}），消耗约 {total_cal} kcal。" + (
                " 达标了，很棒！" if total_min >= 30 else " 还差一点就达标，加油！"
            )
        return "今天还没有运动记录，动起来吧！"

    if query_type in ("schedule_today", "schedule_tomorrow"):
        day_offset = 1 if query_type == "schedule_tomorrow" else 0
        range_start = today_start + timedelta(days=day_offset)
        range_end = range_start + timedelta(days=1)
        events = Event.query.filter(
            Event.user_id == user_id,
            Event.starts_at >= range_start,
            Event.starts_at < range_end,
            Event.status != "cancelled",
        ).order_by(Event.starts_at).all()
        day_label = "明天" if day_offset else "今天"
        if events:
            lines = [f"· {e.starts_at.strftime('%H:%M')} {e.title}" for e in events[:5]]
            return f"{day_label}有这些安排：\n" + "\n".join(lines)
        return f"{day_label}还没有日程安排。"

    if query_type == "health_summary":
        return _build_query_answer(user_id, "calories_today", "") + "\n" + \
               _build_query_answer(user_id, "exercise_today", "")

    return f"关于「{query_text}」，管家正在努力理解中。你可以试试问：今天吃了多少、运动达标了吗、有什么安排。"


@agent_bp.post("/schedule")
@auth_required
def schedule():
    """Create a calendar event from a parsed or manually-provided schedule.

    Request:  {"event_name":"...","start":"ISO8601","end":"ISO8601","reminder_minutes":30}
    Response: {"event_id":123,"status":"created"}
    """
    payload = request.get_json(silent=True) or {}

    title = (payload.get("event_name") or payload.get("title") or "").strip()
    start_raw = (payload.get("start") or payload.get("startsAt") or "").strip()
    end_raw = (payload.get("end") or payload.get("endsAt") or "").strip()
    note = (payload.get("note") or "").strip()
    reminder_minutes = payload.get("reminder_minutes", 0)

    if not title or not start_raw or not end_raw:
        return failure(
            "validation_error",
            "event_name, start and end are required",
            status=422,
        )

    try:
        starts_at = datetime.fromisoformat(start_raw)
        ends_at = datetime.fromisoformat(end_raw)
    except ValueError as exc:
        return failure("validation_error", f"Invalid datetime format: {exc}", status=422)

    event = Event(
        user_id=g.current_user.id,
        title=title,
        note=note,
        starts_at=starts_at,
        ends_at=ends_at,
        status="planned",
    )
    db.session.add(event)
    db.session.commit()

    record_feedback(
        g.current_user.id,
        "confirmed",
        entity_type="create_event",
        entity_id=event.id,
        source_text=str(payload.get("source_text") or ""),
        details={
            **payload,
            "intent": "create_event",
            "event_name": title,
            "start": start_raw,
            "end": end_raw,
        },
    )

    # reminder_minutes is accepted but not persisted (Event model has no reminder field yet).
    _ = reminder_minutes

    return success(
        {"event_id": event.id, "status": "created"},
        status=201,
    )


@agent_bp.post("/suggest")
@auth_required
def suggest():
    """Generate contextual quick-command suggestions for the butler chat page.

    Request:  {"butler_name": "贾维斯"} (optional, defaults to "贾维斯")

    Response: {"suggestions": ["短语1", "短语2", ...]}
    """
    payload = request.get_json(silent=True) or {}
    butler_name = (payload.get("butler_name") or "贾维斯").strip()
    persona_preset = (payload.get("persona_preset") or "default").strip()

    config = _read_llm_config()
    suggestions = suggest_commands(butler_name=butler_name, config=config, persona_preset=persona_preset)
    return success({"suggestions": suggestions})
