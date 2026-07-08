from __future__ import annotations

from functools import wraps

from flask import current_app, g, request

from ..extensions import db
from ..models import User
from ..services.auth import decode_token


def success(data=None, meta=None, status=200):
    return {"ok": True, "data": data, "error": None, "meta": meta or {}}, status


def failure(code: str, message: str, details=None, status=400):
    return {
        "ok": False,
        "data": None,
        "error": {"code": code, "message": message, "details": details or {}},
        "meta": {},
    }, status


def parse_json(required_fields: list[str] | None = None):
    payload = request.get_json(silent=True) or {}
    missing = [field for field in required_fields or [] if not payload.get(field)]
    if missing:
        return None, failure("validation_error", "Missing required fields", {"fields": missing}, 422)
    return payload, None


def auth_required(handler):
    @wraps(handler)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return failure("unauthorized", "Missing bearer token", status=401)
        token = header.split(" ", 1)[1]
        try:
            payload = decode_token(
                token=token,
                secret=current_app.config["SECRET_KEY"],
                issuer=current_app.config["JWT_ISSUER"],
            )
        except Exception:
            return failure("unauthorized", "Invalid or expired token", status=401)

        user = db.session.get(User, payload["sub"])
        if not user:
            return failure("unauthorized", "User not found", status=401)
        g.current_user = user
        return handler(*args, **kwargs)

    return wrapper
