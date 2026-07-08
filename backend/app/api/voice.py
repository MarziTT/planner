from __future__ import annotations

from flask import Blueprint, request

from .common import failure, success


voice_bp = Blueprint("voice", __name__)


@voice_bp.post("/asr")
def recognize_audio():
    payload = request.get_json(silent=True) or {}
    transcript = (payload.get("textMock") or "").strip()
    if transcript:
        return success({"transcript": transcript, "provider": "mock"})
    return failure(
        "not_configured",
        "ASR provider is not configured yet. Send textMock during local development.",
        status=501,
    )
