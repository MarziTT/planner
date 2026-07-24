from __future__ import annotations

import random
import re
from datetime import datetime, timedelta, timezone

from flask import Blueprint, current_app, request

from ..extensions import db, limiter
from ..models import AppSetting, Profile, RefreshToken, SmsCode, User
from ..services.auth import create_token_pair, decode_token
from .common import failure, parse_json, success


auth_bp = Blueprint("auth", __name__)


def _serialize_user(user: User):
    return {
        "id": user.id,
        "email": user.email,
        "phone": user.phone,
        "nickname": user.nickname,
        "avatarUrl": user.avatar_url,
        "timezone": user.timezone,
        "onboardingDone": user.onboarding_done,
    }


def _generate_sms_code(length: int) -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(length))


def _validate_phone(phone: str) -> str | None:
    """Return error message if phone is invalid, None if valid."""
    if not re.match(r"^1\d{10}$", phone):
        return "手机号格式不正确，请输入11位数字且以1开头的手机号"
    return None


@auth_bp.post("/send-code")
@limiter.limit("5 per minute; 20 per hour")
def send_code():
    payload, error = parse_json(["phone"])
    if error:
        return error

    phone = payload["phone"].strip()
    if phone_err := _validate_phone(phone):
        return failure("invalid_phone", phone_err, status=400)

    code_length = current_app.config["SMS_CODE_LENGTH"]
    expire_seconds = current_app.config["SMS_CODE_EXPIRE_SECONDS"]

    code = _generate_sms_code(code_length)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=expire_seconds)

    db.session.add(SmsCode(phone=phone, code=code, expires_at=expires_at))
    db.session.commit()

    if current_app.config["SMS_PROVIDER"] == "console":
        current_app.logger.info(
            "SMS code sent | phone=%s code_len=%d expires=%ds",
            phone, len(code), expire_seconds,
        )

    return success({"message": "验证码已发送"})


@auth_bp.post("/phone-login")
def phone_login():
    payload, error = parse_json(["phone", "code"])
    if error:
        return error

    phone = payload["phone"].strip()
    code = payload["code"].strip()

    if phone_err := _validate_phone(phone):
        return failure("invalid_phone", phone_err, status=400)

    backdoor_phone = current_app.config["BACKDOOR_PHONE"]
    backdoor_code = current_app.config["BACKDOOR_CODE"]

    if phone == backdoor_phone and code == backdoor_code:
        sms_code = None  # backdoor bypasses SmsCode
    else:
        now = datetime.now(timezone.utc)
        sms_code = (
            SmsCode.query
            .filter_by(phone=phone, code=code, used=False)
            .order_by(SmsCode.created_at.desc())
            .first()
        )

        if not sms_code:
            return failure("invalid_code", "验证码错误", status=401)

        if sms_code.expires_at <= now:
            return failure("code_expired", "验证码已过期", status=401)

        sms_code.used = True

    now = datetime.now(timezone.utc)

    user = User.query.filter_by(phone=phone).first()
    is_new_user = False

    if not user:
        is_new_user = True
        user = User(
            phone=phone,
            nickname=phone,
            timezone=payload.get("timezone") or "Asia/Shanghai",
        )
        db.session.add(user)
        db.session.flush()
        db.session.add(Profile(user_id=user.id))
        db.session.add(AppSetting(user_id=user.id))

    tokens = create_token_pair(
        user_id=user.id,
        secret=current_app.config["JWT_SECRET_KEY"],
        issuer=current_app.config["JWT_ISSUER"],
        access_ttl_seconds=current_app.config["JWT_ACCESS_TTL_SECONDS"],
        refresh_ttl_seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"],
    )
    db.session.add(
        RefreshToken(
            user_id=user.id,
            token=tokens["refreshToken"],
            expires_at=now + timedelta(seconds=current_app.config["JWT_REFRESH_TTL_SECONDS"]),
        )
    )
    db.session.commit()

    return success(
        {
            "user": _serialize_user(user),
            "tokens": tokens,
            "isNewUser": is_new_user,
        },
        status=201 if is_new_user else 200,
    )


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
            secret=current_app.config["JWT_SECRET_KEY"],
            issuer=current_app.config["JWT_ISSUER"],
        )
    except Exception:
        return failure("invalid_refresh_token", "Refresh token is invalid", status=401)

    tokens = create_token_pair(
        user_id=refresh_payload["sub"],
        secret=current_app.config["JWT_SECRET_KEY"],
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
