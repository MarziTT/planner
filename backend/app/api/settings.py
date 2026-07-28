from __future__ import annotations

from flask import Blueprint, g, request

from ..extensions import db
from ..models import AppSetting
from .common import auth_required, success


settings_bp = Blueprint("settings", __name__)


_BASE_THEMES = ["sakuraSeason", "ocean", "forest", "desertDusk", "aurora"]
_ZZZ_THEME = "kamenRiderZzz"


def _get_or_create_settings() -> AppSetting:
    """获取当前用户的设置记录，不存在时自动创建默认记录。"""
    settings = AppSetting.query.filter_by(user_id=g.current_user.id).first()
    if settings is None:
        settings = AppSetting(user_id=g.current_user.id)
        db.session.add(settings)
        db.session.flush()
    return settings


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
    }


@settings_bp.get("/settings")
@auth_required
def get_settings():
    try:
        settings = _get_or_create_settings()
        return success({"item": _settings_to_dict(settings)})
    except Exception as e:
        import traceback
        return {"ok": False, "data": None, "error": {"message": str(e), "trace": traceback.format_exc()}, "meta": {}}, 500


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
    db.session.commit()
    return success({"item": _settings_to_dict(settings)})


@settings_bp.get("/settings/weather-tone")
@auth_required
def get_weather_tone():
    settings = _get_or_create_settings()
    return success({"weather_tone": settings.weather_tone})


@settings_bp.put("/settings/weather-tone")
@auth_required
def update_weather_tone():
    settings = _get_or_create_settings()
    payload = request.get_json(silent=True) or {}
    tone = payload.get("weather_tone")
    if tone is not None:
        settings.weather_tone = tone if tone.strip() else None
    db.session.commit()
    return success({"weather_tone": settings.weather_tone})
