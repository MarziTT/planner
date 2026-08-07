"""Inspectable and user-controlled personal memory API."""

from __future__ import annotations

from flask import Blueprint, g, request

from ..extensions import db
from ..models_habits import AgentExperience, MemoryFeedback, MemorySetting, UserMemory
from ..services.memory_service import record_feedback, set_memory_enabled
from .common import auth_required, failure, success


memory_bp = Blueprint("memory", __name__)


def _memory_dict(row: UserMemory) -> dict:
    return {
        "id": row.id,
        "category": row.category,
        "key": row.memory_key,
        "summary": row.summary,
        "value": row.value or {},
        "confidence": row.confidence,
        "evidenceCount": row.evidence_count,
        "source": row.source,
        "active": row.active,
        "lastConfirmedAt": row.last_confirmed_at.isoformat() if row.last_confirmed_at else None,
    }


@memory_bp.get("/memories")
@auth_required
def list_memories():
    setting = db.session.get(MemorySetting, g.current_user.id)
    rows = UserMemory.query.filter_by(user_id=g.current_user.id).order_by(
        UserMemory.active.desc(), UserMemory.confidence.desc(), UserMemory.updated_at.desc(),
    ).all()
    return success({
        "learningEnabled": setting is None or setting.learning_enabled,
        "items": [_memory_dict(row) for row in rows],
    })


@memory_bp.put("/memories/settings")
@auth_required
def update_memory_settings():
    payload = request.get_json(silent=True) or {}
    if "learningEnabled" not in payload:
        return failure("validation_error", "learningEnabled is required", status=422)
    setting = set_memory_enabled(g.current_user.id, bool(payload["learningEnabled"]))
    return success({"learningEnabled": setting.learning_enabled})


@memory_bp.post("/memories")
@auth_required
def create_memory():
    payload = request.get_json(silent=True) or {}
    category = str(payload.get("category") or "preference").strip()[:40]
    summary = str(payload.get("summary") or "").strip()
    memory_key = str(payload.get("key") or summary).strip().lower()[:160]
    if not summary or not memory_key:
        return failure("validation_error", "summary is required", status=422)
    row = UserMemory.query.filter_by(
        user_id=g.current_user.id, category=category, memory_key=memory_key,
    ).first()
    if row is None:
        row = UserMemory(
            user_id=g.current_user.id, category=category, memory_key=memory_key,
            summary=summary[:500], value=payload.get("value") or {},
            confidence=1.0, evidence_count=1, source="manual",
        )
        db.session.add(row)
    else:
        row.summary = summary[:500]
        row.value = payload.get("value") or row.value or {}
        row.confidence = 1.0
        row.source = "manual"
        row.active = True
    db.session.commit()
    return success({"item": _memory_dict(row)}, status=201)


@memory_bp.put("/memories/<int:memory_id>")
@auth_required
def update_memory(memory_id: int):
    row = UserMemory.query.filter_by(id=memory_id, user_id=g.current_user.id).first()
    if row is None:
        return failure("not_found", "Memory not found", status=404)
    payload = request.get_json(silent=True) or {}
    if "summary" in payload:
        summary = str(payload["summary"] or "").strip()
        if not summary:
            return failure("validation_error", "summary cannot be blank", status=422)
        row.summary = summary[:500]
    if "value" in payload:
        row.value = payload["value"] or {}
    if "active" in payload:
        row.active = bool(payload["active"])
    row.source = "manual"
    row.confidence = 1.0
    db.session.commit()
    return success({"item": _memory_dict(row)})


@memory_bp.delete("/memories/<int:memory_id>")
@auth_required
def delete_memory(memory_id: int):
    row = UserMemory.query.filter_by(id=memory_id, user_id=g.current_user.id).first()
    if row is None:
        return failure("not_found", "Memory not found", status=404)
    db.session.delete(row)
    db.session.commit()
    return success({"deleted": True})


@memory_bp.delete("/memories")
@auth_required
def clear_memories():
    user_id = g.current_user.id
    deleted = UserMemory.query.filter_by(user_id=user_id).delete(synchronize_session=False)
    AgentExperience.query.filter_by(user_id=user_id).delete(synchronize_session=False)
    MemoryFeedback.query.filter_by(user_id=user_id).delete(synchronize_session=False)
    db.session.commit()
    return success({"deleted": deleted})


@memory_bp.post("/memories/feedback")
@auth_required
def submit_feedback():
    payload = request.get_json(silent=True) or {}
    action = str(payload.get("action") or "").strip()
    if action not in {"confirmed", "modified", "cancelled", "completed", "ignored"}:
        return failure("validation_error", "Unsupported feedback action", status=422)
    row = record_feedback(
        g.current_user.id,
        action,
        entity_type=str(payload.get("entityType") or "agent_action"),
        entity_id=payload.get("entityId"),
        source_text=str(payload.get("sourceText") or ""),
        details=payload.get("details") if isinstance(payload.get("details"), dict) else {},
        learn=action in {"confirmed", "modified", "completed"},
    )
    return success({"feedbackId": row.id}, status=201)
