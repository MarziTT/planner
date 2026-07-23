"""
Agent API blueprint — Jarvis Agent (Phase 1) endpoints.

POST /api/v1/agent/parse   — LLM semantic schedule parsing
POST /api/v1/agent/schedule — create calendar event from parsed result
"""

from __future__ import annotations

from datetime import datetime

from flask import Blueprint, current_app, g, request

from ..extensions import db
from ..models import Event
from ..services.agent import parse_schedule
from .common import auth_required, failure, success

agent_bp = Blueprint("agent", __name__)


def _read_llm_config() -> dict:
    """Read LLM credentials from Flask app config."""
    return {
        "OPENAI_API_KEY": current_app.config.get("OPENAI_API_KEY", ""),
        "OPENAI_BASE_URL": current_app.config.get("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        "OPENAI_MODEL": current_app.config.get("OPENAI_MODEL", "gpt-4o-mini"),
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
    return success(result)


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

    # reminder_minutes is accepted but not persisted (Event model has no reminder field yet).
    _ = reminder_minutes

    return success(
        {"event_id": event.id, "status": "created"},
        status=201,
    )
