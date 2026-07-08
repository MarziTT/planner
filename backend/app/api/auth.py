from __future__ import annotations

from datetime import datetime, timedelta, timezone

from flask import Blueprint, current_app, request
from werkzeug.security import check_password_hash, generate_password_hash

from ..extensions import db
from ..models import AppSetting, Profile, RefreshToken, User
from ..services.auth import create_token_pair, decode_token
from .common import failure, parse_json, success


auth_bp = Blueprint("auth", __name__)


def _serialize_user(user: User):
    return {
        "id": user.id,
        "email": user.email,
        "nickname": user.nickname,
        "avatarUrl": user.avatar_url,
        "timezone": user.timezone,
        "onboardingDone": user.onboarding_done,
    }


@auth_bp.post("/register")
def register():
    payload, error = parse_json(["email", "password", "nickname"])
    if error:
        return error

    existing = User.query.filter_by(email=payload["email"].strip().lower()).first()
    if existing:
        return failure("email_exists", "Email already registered", status=409)

    user = User(
        email=payload["email"].strip().lower(),
        nickname=payload["nickname"].strip(),
        password_hash=generate_password_hash(payload["password"]),
        timezone=payload.get("timezone") or "Asia/Shanghai",
    )
    db.session.add(user)
    db.session.flush()
    db.session.add(Profile(user_id=user.id))
    db.session.add(AppSetting(user_id=user.id))

    tokens = create_token_pair(
        user_id=user.id,
        secret=current_app.config["SECRET_KEY"],
        issuer=current_app.config["JWT_ISSUER"],
        access_ttl_seconds=current_app.config["JWT_ACCESS_TTL_SECONDS"],
        refresh_ttl_seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"],
    )
    db.session.add(
        RefreshToken(
            user_id=user.id,
            token=tokens["refreshToken"],
            expires_at=datetime.now(timezone.utc)
            + timedelta(seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"]),
        )
    )
    db.session.commit()
    return success({"user": _serialize_user(user), "tokens": tokens}, status=201)


@auth_bp.post("/login")
def login():
    payload, error = parse_json(["email", "password"])
    if error:
        return error

    user = User.query.filter_by(email=payload["email"].strip().lower()).first()
    if not user or not check_password_hash(user.password_hash, payload["password"]):
        return failure("invalid_credentials", "Email or password is incorrect", status=401)

    tokens = create_token_pair(
        user_id=user.id,
        secret=current_app.config["SECRET_KEY"],
        issuer=current_app.config["JWT_ISSUER"],
        access_ttl_seconds=current_app.config["JWT_ACCESS_TTL_SECONDS"],
        refresh_ttl_seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"],
    )
    db.session.add(
        RefreshToken(
            user_id=user.id,
            token=tokens["refreshToken"],
            expires_at=datetime.now(timezone.utc)
            + timedelta(seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"]),
        )
    )
    db.session.commit()
    return success({"user": _serialize_user(user), "tokens": tokens})


@auth_bp.post("/refresh")
def refresh():
    payload, error = parse_json(["refreshToken"])
    if error:
        return error

    stored = RefreshToken.query.filter_by(token=payload["refreshToken"]).first()
    if not stored or stored.revoked_at is not None or stored.expires_at <= datetime.now(timezone.utc):
        return failure("invalid_refresh_token", "Refresh token is invalid", status=401)

    try:
        refresh_payload = decode_token(
            token=payload["refreshToken"],
            secret=current_app.config["SECRET_KEY"],
            issuer=current_app.config["JWT_ISSUER"],
        )
    except Exception:
        return failure("invalid_refresh_token", "Refresh token is invalid", status=401)

    tokens = create_token_pair(
        user_id=refresh_payload["sub"],
        secret=current_app.config["SECRET_KEY"],
        issuer=current_app.config["JWT_ISSUER"],
        access_ttl_seconds=current_app.config["JWT_ACCESS_TTL_SECONDS"],
        refresh_ttl_seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"],
    )
    stored.revoked_at = datetime.now(timezone.utc)
    db.session.add(
        RefreshToken(
            user_id=refresh_payload["sub"],
            token=tokens["refreshToken"],
            expires_at=datetime.now(timezone.utc)
            + timedelta(seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"]),
        )
    )
    db.session.commit()
    return success({"tokens": tokens})


@auth_bp.post("/logout")
def logout():
    payload = request.get_json(silent=True) or {}
    refresh_token = payload.get("refreshToken")
    if refresh_token:
        stored = RefreshToken.query.filter_by(token=refresh_token).first()
        if stored and stored.revoked_at is None:
            stored.revoked_at = datetime.now(timezone.utc)
            db.session.commit()
    return success({"loggedOut": True})
