from __future__ import annotations

import logging

from flask import Blueprint, g, request
from sqlalchemy import inspect, text

from ..extensions import db
from ..models import AppSetting
from .common import auth_required, failure, success


settings_bp = Blueprint("settings", __name__)
logger = logging.getLogger(__name__)


_BASE_THEMES = ["sakuraSeason", "ocean", "forest", "desertDusk", "aurora"]
_ZZZ_THEME = "kamenRiderZzz"


def _mask_secret(value: str | None) -> str:
    """Expose only a short suffix so API responses never contain an LLM key."""
    if not value:
        return ""
    return f"****{value[-4:]}" if len(value) > 4 else "****"


def _get_or_create_settings() -> AppSetting:
    """获取当前用户的设置记录，不存在时自动创建默认记录。"""
    _ensure_settings_butler_tone_column()
    settings = AppSetting.query.filter_by(user_id=g.current_user.id).first()
    if settings is None:
        settings = AppSetting(user_id=g.current_user.id)
        db.session.add(settings)
        db.session.flush()
    return settings


def _ensure_settings_butler_tone_column() -> None:
    """Lazy-repair older settings tables that still miss butler_tone."""
    try:
        inspector = inspect(db.engine)
        if "settings" not in inspector.get_table_names():
            return
        columns = {column["name"] for column in inspector.get_columns("settings")}
        if "butler_tone" in columns:
            return
        dialect = db.engine.dialect.name
        if dialect not in {"postgresql", "sqlite"}:
            return
        db.session.execute(text("ALTER TABLE settings ADD COLUMN butler_tone TEXT"))
        if "weather_tone" in columns:
            db.session.execute(text(
                "UPDATE settings SET butler_tone = weather_tone WHERE butler_tone IS NULL"
            ))
        db.session.commit()
        logger.info("Lazy migration: added butler_tone to settings (dialect=%s)", dialect)
    except Exception:
        db.session.rollback()
        logger.exception("Lazy migration failed: settings.butler_tone")


def _settings_to_dict(settings: AppSetting):
    available = list(_BASE_THEMES)
    if settings.zzz_enabled:
        available.append(_ZZZ_THEME)
    return {
        "theme": settings.theme,
        "themeMode": settings.theme_mode,
        "notificationsEnabled": settings.notifications_enabled,
        "voiceEnabled": settings.voice_enabled,
        "updateChannel": settings.update_channel,
        "availableThemes": available,
        "zzzEnabled": settings.zzz_enabled,
        "llmApiKey": _mask_secret(settings.llm_api_key),
        "llmApiKeyConfigured": bool(settings.llm_api_key),
        "llmBaseUrl": settings.llm_base_url or "",
        "llmModel": settings.llm_model or "",
    }


@settings_bp.get("/settings")
@auth_required
def get_settings():
    try:
        settings = _get_or_create_settings()
        return success({"item": _settings_to_dict(settings)})
    except Exception:
        db.session.rollback()
        logger.exception("Failed to load settings for user %s", g.current_user.id)
        return failure("settings_unavailable", "Settings are temporarily unavailable", status=500)


@settings_bp.put("/settings")
@auth_required
def update_settings():
    settings = _get_or_create_settings()
    payload = request.get_json(silent=True) or {}
    if "theme" in payload:
        settings.theme = payload["theme"] or settings.theme
    if "themeMode" in payload:
        settings.theme_mode = payload["themeMode"] or settings.theme_mode
    if "notificationsEnabled" in payload:
        settings.notifications_enabled = bool(payload["notificationsEnabled"])
    if "voiceEnabled" in payload:
        settings.voice_enabled = bool(payload["voiceEnabled"])
    if "updateChannel" in payload:
        settings.update_channel = payload["updateChannel"] or settings.update_channel
    if "zzzEnabled" in payload:
        settings.zzz_enabled = bool(payload["zzzEnabled"])
    if "llmApiKey" in payload:
        # Keep the stored secret when the client sends back our masked value.
        incoming_key = str(payload["llmApiKey"] or "").strip()
        if incoming_key and not incoming_key.startswith("****"):
            settings.llm_api_key = incoming_key
        elif not incoming_key:
            settings.llm_api_key = None
    if "llmBaseUrl" in payload:
        settings.llm_base_url = payload["llmBaseUrl"] or None
    if "llmModel" in payload:
        settings.llm_model = payload["llmModel"] or None
    db.session.commit()
    return success({"item": _settings_to_dict(settings)})


@settings_bp.get("/settings/butler-tone")
@auth_required
def get_butler_tone():
    settings = _get_or_create_settings()
    return success({"butler_tone": settings.butler_tone})


@settings_bp.put("/settings/butler-tone")
@auth_required
def update_butler_tone():
    settings = _get_or_create_settings()
    payload = request.get_json(silent=True) or {}
    tone = payload.get("butler_tone")
    if tone is not None:
        settings.butler_tone = tone if tone.strip() else None
    db.session.commit()
    return success({"butler_tone": settings.butler_tone})


@settings_bp.get("/settings/weather-tone")
@auth_required
def get_weather_tone_compat():
    settings = _get_or_create_settings()
    return success({
        "butler_tone": settings.butler_tone,
        "weather_tone": settings.butler_tone,
    })


@settings_bp.put("/settings/weather-tone")
@auth_required
def update_weather_tone_compat():
    settings = _get_or_create_settings()
    payload = request.get_json(silent=True) or {}
    tone = payload.get("butler_tone", payload.get("weather_tone"))
    if tone is not None:
        settings.butler_tone = tone if tone.strip() else None
    db.session.commit()
    return success({
        "butler_tone": settings.butler_tone,
        "weather_tone": settings.butler_tone,
    })
