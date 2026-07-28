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
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return None, failure("validation_error", "Request body must be a JSON object", status=422)

    # Only null and blank strings are missing. Values such as False and 0 are
    # valid JSON input and must not be rejected by truthiness checks.
    missing = [
        field
        for field in required_fields or []
        if payload.get(field) is None
        or (isinstance(payload.get(field), str) and not payload[field].strip())
    ]
    if missing:
        return None, failure("validation_error", "Missing required fields", {"fields": missing}, 422)
    return payload, None


def auth_required(handler):
    @wraps(handler)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        scheme, _, token = header.partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            return failure("unauthorized", "Missing bearer token", status=401)
        try:
            payload = decode_token(
                token=token.strip(),
                secret=current_app.config["JWT_SECRET_KEY"],
                issuer=current_app.config["JWT_ISSUER"],
                expected_type="access",
            )
            user_id = payload["sub"]
        except Exception:
            return failure("unauthorized", "Invalid or expired token", status=401)

        user = db.session.get(User, user_id)
        if not user:
            return failure("unauthorized", "User not found", status=401)
        g.current_user = user
        # Keep the legacy scalar available while callers migrate to the user
        # object. Several existing blueprints still read g.user_id directly.
        g.user_id = user.id
        return handler(*args, **kwargs)

    return wrapper
