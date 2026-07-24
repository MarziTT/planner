from __future__ import annotations

import logging
from datetime import date, datetime

from flask import Blueprint, current_app, g, request

from ..extensions import db
from ..models import Event, Profile, Tag, Todo
from .common import auth_required, failure, success

logger = logging.getLogger(__name__)

planner_bp = Blueprint("planner", __name__)

MAX_TITLE_LENGTH = 200


def _parse_iso_datetime(value: str) -> datetime | None:
    """Safely parse an ISO datetime string; returns None on failure."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None


def _parse_iso_date(value: str) -> date | None:
    """Safely parse an ISO date string; returns None on failure."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value).date()
    except (ValueError, TypeError):
        return None


def _validate_title(title: str) -> str | None:
    """Return error message if title is invalid, None if valid."""
    if not title or not title.strip():
        return "title is required"
    if len(title) > MAX_TITLE_LENGTH:
        return f"title must not exceed {MAX_TITLE_LENGTH} characters"
    return None


def _event_to_dict(event: Event):
    return {
        "id": event.id,
        "title": event.title,
        "note": event.note,
        "startsAt": event.starts_at.isoformat(),
        "endsAt": event.ends_at.isoformat(),
        "repeatRule": event.repeat_rule,
        "status": event.status,
        "tagId": event.tag_id,
        "tagIds": [event.tag_id] if event.tag_id is not None else [],
    }


def _todo_to_dict(todo: Todo):
    return {
        "id": todo.id,
        "title": todo.title,
        "note": todo.note,
        "dueDate": todo.due_date.isoformat() if todo.due_date else None,
        "dueTime": todo.due_time,
        "repeatRule": todo.repeat_rule,
        "completed": todo.completed,
    }


def _tag_to_dict(tag: Tag):
    return {
        "id": tag.id,
        "name": tag.name,
        "color": tag.color,
        "isRecurring": tag.is_recurring,
        "recurrenceRule": tag.recurrence_rule,
    }


def _paginate_args() -> tuple[int, int]:
    """Extract common pagination params from request.args."""
    try:
        page = max(1, int(request.args.get("page", "1")))
    except (ValueError, TypeError):
        page = 1
    try:
        per_page = max(1, min(200, int(request.args.get("perPage", "50"))))
    except (ValueError, TypeError):
        per_page = 50
    return page, per_page


@planner_bp.get("/events")
@auth_required
def list_events():
    query = Event.query.filter_by(user_id=g.current_user.id)
    status = request.args.get("status", "").strip()
    if status:
        query = query.filter_by(status=status)
    page, per_page = _paginate_args()
    pagination = query.order_by(Event.starts_at.asc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return success({
        "items": [_event_to_dict(item) for item in pagination.items],
        "page": pagination.page,
        "perPage": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    })


@planner_bp.post("/events")
@auth_required
def create_event():
    payload = request.get_json(silent=True) or {}
    title_err = _validate_title(payload.get("title", ""))
    if title_err:
        return failure("validation_error", title_err, status=422)
    starts_at = _parse_iso_datetime(payload.get("startsAt", ""))
    ends_at = _parse_iso_datetime(payload.get("endsAt", ""))
    if not starts_at or not ends_at:
        return failure("validation_error", "startsAt and endsAt must be valid ISO datetime strings", status=422)
    event = Event(
        user_id=g.current_user.id,
        title=payload["title"].strip(),
        note=(payload.get("note") or "").strip(),
        starts_at=starts_at,
        ends_at=ends_at,
        repeat_rule=payload.get("repeatRule") or "",
        status=payload.get("status") or "planned",
        tag_id=payload.get("tagId"),
    )
    db.session.add(event)
    db.session.commit()
    return success({"item": _event_to_dict(event)}, status=201)


@planner_bp.put("/events/<int:event_id>")
@auth_required
def update_event(event_id: int):
    event = Event.query.filter_by(id=event_id, user_id=g.current_user.id).first()
    if not event:
        return failure("not_found", "Event not found", status=404)
    payload = request.get_json(silent=True) or {}
    if "title" in payload:
        title_err = _validate_title(payload["title"])
        if title_err:
            return failure("validation_error", title_err, status=422)
        event.title = payload["title"].strip()
    if "note" in payload:
        event.note = (payload["note"] or "").strip()
    if "startsAt" in payload:
        val = _parse_iso_datetime(payload["startsAt"])
        if val is None:
            return failure("validation_error", "startsAt must be a valid ISO datetime", status=422)
        event.starts_at = val
    if "endsAt" in payload:
        val = _parse_iso_datetime(payload["endsAt"])
        if val is None:
            return failure("validation_error", "endsAt must be a valid ISO datetime", status=422)
        event.ends_at = val
    if "repeatRule" in payload:
        event.repeat_rule = payload["repeatRule"] or ""
    if "status" in payload:
        event.status = payload["status"] or "planned"
    if "tagId" in payload:
        event.tag_id = payload["tagId"]
    elif "tagIds" in payload and payload["tagIds"] is not None:
        try:
            ids = [int(x) for x in payload["tagIds"] if x is not None]
        except (ValueError, TypeError):
            return failure("validation_error", "tagIds must be a list of integers", status=422)
        event.tag_id = ids[0] if ids else None
    db.session.commit()
    return success({"item": _event_to_dict(event)})


@planner_bp.delete("/events/<int:event_id>")
@auth_required
def delete_event(event_id: int):
    event = Event.query.filter_by(id=event_id, user_id=g.current_user.id).first()
    if not event:
        return failure("not_found", "Event not found", status=404)
    db.session.delete(event)
    db.session.commit()
    return success({"deleted": True})


@planner_bp.get("/todos")
@auth_required
def list_todos():
    query = Todo.query.filter_by(user_id=g.current_user.id)
    completed = request.args.get("completed", "")
    if completed in {"true", "false"}:
        query = query.filter_by(completed=(completed == "true"))
    page, per_page = _paginate_args()
    pagination = query.order_by(Todo.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    return success({
        "items": [_todo_to_dict(item) for item in pagination.items],
        "page": pagination.page,
        "perPage": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    })


@planner_bp.post("/todos")
@auth_required
def create_todo():
    payload = request.get_json(silent=True) or {}
    title_err = _validate_title(payload.get("title", ""))
    if title_err:
        return failure("validation_error", title_err, status=422)
    due_date = None
    if payload.get("dueDate"):
        due_date = _parse_iso_date(payload["dueDate"])
        if due_date is None:
            return failure("validation_error", "dueDate must be a valid ISO date string", status=422)
    todo = Todo(
        user_id=g.current_user.id,
        title=payload["title"].strip(),
        note=(payload.get("note") or "").strip(),
        due_date=due_date,
        due_time=payload.get("dueTime") or "",
        repeat_rule=payload.get("repeatRule") or "",
        completed=bool(payload.get("completed", False)),
    )
    db.session.add(todo)
    db.session.commit()
    return success({"item": _todo_to_dict(todo)}, status=201)


@planner_bp.put("/todos/<int:todo_id>")
@auth_required
def update_todo(todo_id: int):
    todo = Todo.query.filter_by(id=todo_id, user_id=g.current_user.id).first()
    if not todo:
        return failure("not_found", "Todo not found", status=404)
    payload = request.get_json(silent=True) or {}
    if "title" in payload:
        title_err = _validate_title(payload["title"])
        if title_err:
            return failure("validation_error", title_err, status=422)
    for field, attr in [("title", "title"), ("note", "note"), ("dueTime", "due_time"), ("repeatRule", "repeat_rule")]:
        if field in payload:
            setattr(todo, attr, (payload[field] or "").strip() if isinstance(payload[field], str) else payload[field])
    if "dueDate" in payload:
        todo.due_date = _parse_iso_date(payload["dueDate"]) if payload["dueDate"] else None
    if "completed" in payload:
        todo.completed = bool(payload["completed"])
    db.session.commit()
    return success({"item": _todo_to_dict(todo)})


@planner_bp.delete("/todos/<int:todo_id>")
@auth_required
def delete_todo(todo_id: int):
    todo = Todo.query.filter_by(id=todo_id, user_id=g.current_user.id).first()
    if not todo:
        return failure("not_found", "Todo not found", status=404)
    db.session.delete(todo)
    db.session.commit()
    return success({"deleted": True})


@planner_bp.get("/tags")
@auth_required
def list_tags():
    items = Tag.query.filter_by(user_id=g.current_user.id).order_by(Tag.created_at.asc()).all()
    return success({"items": [_tag_to_dict(item) for item in items]})


@planner_bp.post("/tags")
@auth_required
def create_tag():
    payload = request.get_json(silent=True) or {}
    if not payload.get("name"):
        return failure("validation_error", "name is required", status=422)
    tag = Tag(
        user_id=g.current_user.id,
        name=payload["name"].strip(),
        color=payload.get("color") or "#5B8CFF",
        is_recurring=bool(payload.get("isRecurring", False)),
        recurrence_rule=payload.get("recurrenceRule") or "",
    )
    db.session.add(tag)
    db.session.commit()
    return success({"item": _tag_to_dict(tag)}, status=201)


@planner_bp.put("/tags/<int:tag_id>")
@auth_required
def update_tag(tag_id: int):
    tag = Tag.query.filter_by(id=tag_id, user_id=g.current_user.id).first()
    if not tag:
        return failure("not_found", "Tag not found", status=404)
    payload = request.get_json(silent=True) or {}
    if "name" in payload:
        tag.name = payload["name"].strip()
    if "color" in payload:
        tag.color = payload["color"] or "#5B8CFF"
    if "isRecurring" in payload:
        tag.is_recurring = bool(payload["isRecurring"])
    if "recurrenceRule" in payload:
        tag.recurrence_rule = payload["recurrenceRule"] or ""
    db.session.commit()
    return success({"item": _tag_to_dict(tag)})


@planner_bp.delete("/tags/<int:tag_id>")
@auth_required
def delete_tag(tag_id: int):
    tag = Tag.query.filter_by(id=tag_id, user_id=g.current_user.id).first()
    if not tag:
        return failure("not_found", "Tag not found", status=404)
    db.session.delete(tag)
    db.session.commit()
    return success({"deleted": True})


@planner_bp.get("/stats")
@auth_required
def get_stats():
    events_total = Event.query.filter_by(user_id=g.current_user.id).count()
    todos_total = Todo.query.filter_by(user_id=g.current_user.id).count()
    todos_completed = Todo.query.filter_by(user_id=g.current_user.id, completed=True).count()
    return success(
        {
            "eventsTotal": events_total,
            "todosTotal": todos_total,
            "todosCompleted": todos_completed,
            "completionRate": round((todos_completed / todos_total) * 100, 1) if todos_total else 0,
        }
    )


@planner_bp.get("/export")
@auth_required
def export_data():
    profile = Profile.query.filter_by(user_id=g.current_user.id).first()
    return success(
        {
            "user": {
                "id": g.current_user.id,
                "email": g.current_user.email,
                "nickname": g.current_user.nickname,
            },
            "profile": {
                "gender": profile.gender,
                "age": profile.age,
                "city": profile.city,
                "bio": profile.bio,
                "fitnessGoal": profile.fitness_goal,
            } if profile else None,
            "events": [_event_to_dict(item) for item in Event.query.filter_by(user_id=g.current_user.id).order_by(Event.starts_at.asc()).all()],
            "todos": [_todo_to_dict(item) for item in Todo.query.filter_by(user_id=g.current_user.id).order_by(Todo.created_at.desc()).all()],
            "tags": [_tag_to_dict(item) for item in Tag.query.filter_by(user_id=g.current_user.id).order_by(Tag.created_at.asc()).all()],
        }
    )


@planner_bp.post("/import")
@auth_required
def import_data():
    payload = request.get_json(silent=True) or {}
    events = payload.get("events") or []
    todos = payload.get("todos") or []
    tags = payload.get("tags") or []

    for tag_data in tags:
        tag = Tag(
            user_id=g.current_user.id,
            name=(tag_data.get("name") or "未命名标签").strip(),
            color=tag_data.get("color") or "#5B8CFF",
        )
        db.session.add(tag)

    for event_data in events:
        if not event_data.get("title") or not event_data.get("startsAt") or not event_data.get("endsAt"):
            continue
        starts_at = _parse_iso_datetime(event_data["startsAt"])
        ends_at = _parse_iso_datetime(event_data["endsAt"])
        if not starts_at or not ends_at:
            continue
        db.session.add(
            Event(
                user_id=g.current_user.id,
                title=event_data["title"].strip(),
                note=(event_data.get("note") or "").strip(),
                starts_at=starts_at,
                ends_at=ends_at,
                repeat_rule=event_data.get("repeatRule") or "",
                status=event_data.get("status") or "planned",
            )
        )

    for todo_data in todos:
        if not todo_data.get("title"):
            continue
        db.session.add(
            Todo(
                user_id=g.current_user.id,
                title=todo_data["title"].strip(),
                note=(todo_data.get("note") or "").strip(),
                due_date=_parse_iso_date(todo_data.get("dueDate")),
                due_time=todo_data.get("dueTime") or "",
                repeat_rule=todo_data.get("repeatRule") or "",
                completed=bool(todo_data.get("completed", False)),
            )
        )

    db.session.commit()
    return success({"imported": True, "events": len(events), "todos": len(todos), "tags": len(tags)}, status=201)
