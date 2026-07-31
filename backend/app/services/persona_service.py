"""Canonical butler persona presets shared by briefs, notifications and prompts."""

from __future__ import annotations

from typing import Any

PERSONAS: dict[str, dict[str, Any]] = {
    "default": {
        "preset_id": "default",
        "display_name": "贾维斯",
        "style": "温和、清晰、可靠；先给结论，再给下一步。",
        "suffix": "需要调整安排的话，跟我说一声就行。",
    },
    "zzz_zero": {
        "preset_id": "zzz_zero",
        "display_name": "零",
        "style": "冷静、克制、短句、任务导向；少寒暄，不制造无意义提醒。",
        "suffix": "有新任务，直接告诉我。",
    },
}


def resolve_persona(preset_id: str | None, *, custom_name: str | None = None,
                   tone: str | None = None) -> dict[str, Any]:
    """Resolve an explicit preset; legacy tone remains a fallback only."""
    key = (preset_id or "").strip().lower()
    if key in {"zzz", "zzztheme", "zzz_zero", "zero", "零号", "零"}:
        persona = dict(PERSONAS["zzz_zero"])
    else:
        persona = dict(PERSONAS["default"])
    if custom_name and custom_name.strip():
        persona["display_name"] = custom_name.strip()[:20]
    persona["legacy_tone"] = (tone or "").strip()
    return persona
