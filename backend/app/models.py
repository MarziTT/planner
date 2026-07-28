from __future__ import annotations

from datetime import datetime, timezone

from .extensions import db


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False)
    updated_at = db.Column(
        db.DateTime,
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )


class User(TimestampMixin, db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    phone = db.Column(db.String(20), unique=True, nullable=False, index=True)
    email = db.Column(db.String(255), nullable=True)
    password_hash = db.Column(db.String(255), nullable=True)
    nickname = db.Column(db.String(80), nullable=False)
    avatar_url = db.Column(db.String(255))
    timezone = db.Column(db.String(64), default="Asia/Shanghai", nullable=False)
    onboarding_done = db.Column(db.Boolean, default=False, nullable=False)
    # Phase 2 — exercise dual-mode (spec §9.1)
    exercise_mode = db.Column(db.String(20), default="self", nullable=False)
    trainer_end_date = db.Column(db.Date)


class SmsCode(db.Model):
    __tablename__ = "sms_codes"

    id = db.Column(db.Integer, primary_key=True)
    phone = db.Column(db.String(20), nullable=False, index=True)
    code = db.Column(db.String(10), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    used = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False)


class RefreshToken(TimestampMixin, db.Model):
    __tablename__ = "refresh_tokens"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    token = db.Column(db.String(512), unique=True, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    revoked_at = db.Column(db.DateTime)


class Tag(TimestampMixin, db.Model):
    __tablename__ = "tags"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    name = db.Column(db.String(64), nullable=False)
    color = db.Column(db.String(16), nullable=False, default="#5B8CFF")
    is_recurring = db.Column(db.Boolean, default=False, nullable=False)
    recurrence_rule = db.Column(db.String(120), default="", nullable=False)


class Event(TimestampMixin, db.Model):
    __tablename__ = "events"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    title = db.Column(db.String(120), nullable=False)
    note = db.Column(db.Text, default="", nullable=False)
    starts_at = db.Column(db.DateTime, nullable=False)
    ends_at = db.Column(db.DateTime, nullable=False)
    repeat_rule = db.Column(db.String(120), default="", nullable=False)
    status = db.Column(db.String(24), default="planned", nullable=False)
    tag_id = db.Column(db.Integer, db.ForeignKey("tags.id"))


class Todo(TimestampMixin, db.Model):
    __tablename__ = "todos"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    title = db.Column(db.String(120), nullable=False)
    note = db.Column(db.Text, default="", nullable=False)
    due_date = db.Column(db.Date)
    due_time = db.Column(db.String(8), default="", nullable=False)
    repeat_rule = db.Column(db.String(120), default="", nullable=False)
    completed = db.Column(db.Boolean, default=False, nullable=False)


class Profile(TimestampMixin, db.Model):
    __tablename__ = "profiles"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), primary_key=True)
    gender = db.Column(db.String(16), default="", nullable=False)
    age = db.Column(db.Integer)
    city = db.Column(db.String(80), default="", nullable=False)
    bio = db.Column(db.String(255), default="", nullable=False)
    fitness_goal = db.Column(db.String(120), default="", nullable=False)
    identity = db.Column(db.String(32), default="worker", nullable=False)
    routine_start = db.Column(db.String(8), default="09:00", nullable=False)
    routine_end = db.Column(db.String(8), default="18:00", nullable=False)
    focus_area = db.Column(db.String(120), default="", nullable=False)
    wants_fitness = db.Column(db.Boolean, default=False, nullable=False)
    fitness_mode = db.Column(db.String(32), default="self", nullable=False)


class AppSetting(TimestampMixin, db.Model):
    __tablename__ = "settings"

    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), primary_key=True)
    theme = db.Column(db.String(32), default="forest", nullable=False)
    theme_mode = db.Column(db.String(16), default="dark", nullable=False)
    notifications_enabled = db.Column(db.Boolean, default=True, nullable=False)
    voice_enabled = db.Column(db.Boolean, default=True, nullable=False)
    update_channel = db.Column(db.String(32), default="stable", nullable=False)
    zzz_enabled = db.Column(db.Boolean, default=False, nullable=False)
    weather_tone = db.Column(db.Text, nullable=True)
    llm_api_key = db.Column(db.Text, nullable=True)
    llm_base_url = db.Column(db.Text, nullable=True)
    llm_model = db.Column(db.String(64), nullable=True)


def register_models() -> None:
    from . import models_habits  # noqa: F401 — ensure Phase 2 tables are known to SQLAlchemy
