from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from dataclasses import dataclass
from typing import Any

import requests
from flask import Blueprint, current_app, request

from ..extensions import limiter
from .common import auth_required, failure, success


voice_bp = Blueprint("voice", __name__)


@dataclass(frozen=True)
class TencentAsrConfig:
    secret_id: str
    secret_key: str
    region: str
    engine_type: str
    voice_format: str
    endpoint: str = "https://asr.tencentcloudapi.com"

    @property
    def configured(self) -> bool:
        return bool(self.secret_id and self.secret_key)


def _load_tencent_config() -> TencentAsrConfig:
    return TencentAsrConfig(
        secret_id=current_app.config.get("TENCENT_SECRET_ID", ""),
        secret_key=current_app.config.get("TENCENT_SECRET_KEY", ""),
        region=current_app.config.get("TENCENT_ASR_REGION", "ap-shanghai"),
        engine_type=current_app.config.get("TENCENT_ASR_ENGINE_TYPE", "16k_zh"),
        voice_format=current_app.config.get("TENCENT_ASR_VOICE_FORMAT", "wav"),
    )


@voice_bp.post("/asr")
@auth_required
@limiter.limit("10 per minute; 100 per hour")
def recognize_audio():
    payload = request.get_json(silent=True) or {}
    transcript = (payload.get("textMock") or "").strip()
    if transcript:
        return success({"transcript": transcript, "provider": "mock"})

    audio_base64 = (payload.get("audioBase64") or "").strip()
    if not audio_base64:
        return failure(
            "validation_error",
            "audioBase64 is required when textMock is not provided.",
            status=422,
        )

    try:
        audio_bytes = base64.b64decode(audio_base64, validate=True)
    except Exception:
        return failure("validation_error", "audioBase64 is not valid base64.", status=422)

    if not audio_bytes:
        return failure("validation_error", "audioBase64 is empty.", status=422)

    config = _load_tencent_config()
    if not config.configured:
        return failure(
            "not_configured",
            "Tencent ASR credentials are not configured on the server.",
            status=501,
        )

    voice_format = (payload.get("voiceFormat") or config.voice_format).strip().lower()
    engine_type = (payload.get("engineType") or config.engine_type).strip()
    try:
        result = _call_tencent_sentence_recognition(
            config=config,
            audio_base64=audio_base64,
            audio_len=len(audio_bytes),
            voice_format=voice_format,
            engine_type=engine_type,
        )
    except requests.RequestException:
        return failure("asr_network_error", "Tencent ASR request failed.", status=502)
    except ValueError as error:
        return failure("asr_error", str(error), status=502)

    return success({"transcript": result, "provider": "tencent"})


def _call_tencent_sentence_recognition(
    *,
    config: TencentAsrConfig,
    audio_base64: str,
    audio_len: int,
    voice_format: str,
    engine_type: str,
) -> str:
    action = "SentenceRecognition"
    service = "asr"
    version = "2019-06-14"
    timestamp = int(time.time())
    request_payload = {
        "ProjectId": 0,
        "SubServiceType": 2,
        "EngSerViceType": engine_type,
        "SourceType": 1,
        "VoiceFormat": voice_format,
        "UsrAudioKey": f"pixel-planner-{timestamp}",
        "Data": audio_base64,
        "DataLen": audio_len,
    }
    body = json.dumps(request_payload, ensure_ascii=False, separators=(",", ":"))
    headers = _build_tencent_headers(
        config=config,
        service=service,
        action=action,
        version=version,
        timestamp=timestamp,
        body=body,
    )

    response = requests.post(config.endpoint, data=body.encode("utf-8"), headers=headers, timeout=20)
    response.raise_for_status()
    payload: dict[str, Any] = response.json()
    response_data = payload.get("Response") or {}
    if response_data.get("Error"):
        error = response_data["Error"]
        raise ValueError(error.get("Message") or error.get("Code") or "Tencent ASR failed")
    transcript = (response_data.get("Result") or "").strip()
    if not transcript:
        raise ValueError("Tencent ASR returned an empty transcript")
    return transcript


def _build_tencent_headers(
    *,
    config: TencentAsrConfig,
    service: str,
    action: str,
    version: str,
    timestamp: int,
    body: str,
) -> dict[str, str]:
    host = "asr.tencentcloudapi.com"
    algorithm = "TC3-HMAC-SHA256"
    date = time.strftime("%Y-%m-%d", time.gmtime(timestamp))
    content_type = "application/json; charset=utf-8"
    canonical_headers = (
        f"content-type:{content_type}\n"
        f"host:{host}\n"
        f"x-tc-action:{action.lower()}\n"
    )
    signed_headers = "content-type;host;x-tc-action"
    hashed_request_payload = hashlib.sha256(body.encode("utf-8")).hexdigest()
    canonical_request = "\n".join(
        [
            "POST",
            "/",
            "",
            canonical_headers,
            signed_headers,
            hashed_request_payload,
        ]
    )
    credential_scope = f"{date}/{service}/tc3_request"
    string_to_sign = "\n".join(
        [
            algorithm,
            str(timestamp),
            credential_scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    secret_date = _hmac_sha256(("TC3" + config.secret_key).encode("utf-8"), date)
    secret_service = _hmac_sha256(secret_date, service)
    secret_signing = _hmac_sha256(secret_service, "tc3_request")
    signature = hmac.new(
        secret_signing,
        string_to_sign.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    authorization = (
        f"{algorithm} Credential={config.secret_id}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )
    return {
        "Authorization": authorization,
        "Content-Type": content_type,
        "Host": host,
        "X-TC-Action": action,
        "X-TC-Version": version,
        "X-TC-Timestamp": str(timestamp),
        "X-TC-Region": config.region,
    }


def _hmac_sha256(key: bytes, message: str) -> bytes:
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()