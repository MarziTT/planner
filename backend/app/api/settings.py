from __future__ import annotations

from flask import Blueprint, g, request

from ..extensions import db
from ..models import AppSetting
from .common import auth_required, success


settings_bp = Blueprint("settings", __name__)


def _settings_to_dict(settings: AppSetting):
    return {
        "theme": settings.theme,
        "themeMode": settings.theme_mode,
        "notificationsEnabled": settings.notifications_enabled,
        "voiceEnabled": settings.voice_enabled,
        "updateChannel": settings.update_channel,
    }


@settings_bp.get("/settings")
@auth_required
def get_settings():
    settings = AppSetting.query.filter_by(user_id=g.current_user.id).first()
    return success({"item": _settings_to_dict(settings)})


@settings_bp.put("/settings")
@auth_required
def update_settings():
    settings = AppSetting.query.filter_by(user_id=g.current_user.id).first()
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
    db.session.commit()
    return success({"item": _settings_to_dict(settings)})
