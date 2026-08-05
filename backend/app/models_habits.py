"""
Phase 2 (Jarvis life-butler) models — habits engine, notifications, records.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §5
"""

from __future__ import annotations

from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import synonym

from .extensions import db
from .models import TimestampMixin, utc_now

# JSON column that becomes JSONB on PostgreSQL and plain JSON on SQLite.
JSONVariant = db.JSON().with_variant(JSONB(), "postgresql")


class EventHistory(db.Model):
    """Actual timestamps for reminded events — raw material for the habits engine."""

    __tablename__ = "event_history"

    id = db.Column(db.Integer, primary_key=True)
    event_id = db.Column(db.Integer, db.ForeignKey("events.id"), index=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    notify_type = db.Column(db.String(50), default="", nullable=False, index=True)
    planned_time = db.Column(db.DateTime, nullable=False)
    reminded_at = db.Column(db.DateTime)
    completed_at = db.Column(db.DateTime)
    delayed_count = db.Column(db.Integer, default=0, nullable=False)
    skipped = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=utc_now, nullable=False)


class UserPattern(TimestampMixin, db.Model):
    """A learned habit produced by the sliding-window pattern detector."""

    __tablename__ = "user_patterns"
    __table_args__ = (
        db.UniqueConstraint("user_id", "pattern_type", "pattern_key", name="uq_user_pattern"),
    )

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    pattern_type = db.Column(
        db.String(50), default="wake_time", nullable=False
    )  # 'wake_time' / 'meal_time' / 'transit_mode' ...
    pattern_key = db.Column(db.String(100), default="", nullable=False)
    pattern_value = db.Column(JSONVariant)
    confidence = db.Column(db.Float, default=0.0, nullable=False)
    sample_count = db.Column(db.Integer, default=0, nullable=False)
    # Kept as a first-class field for the scene engine and older clients that
    # persisted the learned wake time directly.
    wake_time = db.Column(db.String(5), nullable=True)


class AgentExperience(TimestampMixin, db.Model):
    """Confirmed or high-confidence language examples for offline agent parsing."""

    __tablename__ = "agent_experiences"
    __table_args__ = (
        db.UniqueConstraint(
            "user_id", "normalized_text", name="uq_agent_experience_text"
        ),
    )

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    source_text = db.Column(db.Text, default="", nullable=False)
    normalized_text = db.Column(db.String(240), default="", nullable=False, index=True)
    intent = db.Column(db.String(40), default="", nullable=False, index=True)
    parsed = db.Column(JSONVariant)
    sample_count = db.Column(db.Integer, default=1, nullable=False)
    last_used_at = db.Column(db.DateTime, default=utc_now, nullable=False)


class NotifyPreference(TimestampMixin, db.Model):
    """Per-user notification preference; may be overridden by the habits engine."""

    __tablename__ = "notify_preferences"
    __table_args__ = (
        db.UniqueConstraint("user_id", "notify_type", name="uq_notify_pref"),
    )

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    notify_type = db.Column(db.String(50), nullable=False)  # 'transit' / 'standing' / 'meal' ...
    lead_minutes = db.Column(db.Integer)
    enabled = db.Column(db.Boolean, default=True, nullable=False)
    quiet_hours_start = db.Column(db.Time)
    quiet_hours_end = db.Column(db.Time)


class OcrCache(db.Model):
    """OCR result cache — stores only the SHA-256 hash of the image, never the image."""

    __tablename__ = "ocr_cache"
    __table_args__ = (
        db.UniqueConstraint("user_id", "image_hash", name="uq_ocr_cache_hash"),
    )

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    image_hash = db.Column(db.String(64), nullable=False, index=True)  # SHA-256 hex
    raw_text = db.Column(db.Text, default="", nullable=False)
    parsed = db.Column(JSONVariant)
    processed_at = db.Column(db.DateTime, default=utc_now, nullable=False)


class MealRecord(db.Model):
    """Meal log entry from photo recognition, tap confirmation or voice input."""

    __tablename__ = "meal_records"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    meal_type = db.Column(db.String(20), nullable=False)  # 'breakfast' / 'lunch' / 'dinner' / 'snack'
    items = db.Column(JSONVariant)  # [{"name": "牛肉面", "portion": "large"}]
    recorded_at = db.Column(db.DateTime, default=utc_now, nullable=False, index=True)
    source = db.Column(db.String(20), default="photo", nullable=False)  # 'photo' / 'tap' / 'voice'


class ExerciseRecord(db.Model):
    """Exercise log entry from sensors or manual input."""

    __tablename__ = "exercise_records"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    exercise_type = db.Column(db.String(50), nullable=False)
    duration_minutes = db.Column(db.Integer, default=0, nullable=False)
    calories = db.Column(db.Integer)
    steps = db.Column(db.Integer)
    recorded_at = db.Column(db.DateTime, default=utc_now, nullable=False, index=True)
    source = db.Column(db.String(20), default="auto", nullable=False)  # 'auto' / 'manual'

    # Compatibility aliases used by the original scene-engine contract.
    completed_at = synonym("recorded_at")
    calories_burned = synonym("calories")
