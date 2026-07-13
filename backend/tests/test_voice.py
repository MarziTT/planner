import base64

from app import create_app
from app.api import voice


class FakeTencentResponse:
    def raise_for_status(self):
        return None

    def json(self):
        return {"Response": {"Result": "今天下午七点去健身"}}


def test_voice_asr_text_mock_still_works():
    app = create_app("testing")
    client = app.test_client()

    response = client.post("/api/v1/voice/asr", json={"textMock": "明天五点的飞机"})

    payload = response.get_json()
    assert response.status_code == 200
    assert payload["data"]["transcript"] == "明天五点的飞机"
    assert payload["data"]["provider"] == "mock"


def test_voice_asr_requires_audio_without_mock():
    app = create_app("testing")
    client = app.test_client()

    response = client.post("/api/v1/voice/asr", json={})

    assert response.status_code == 422
    assert response.get_json()["error"]["code"] == "validation_error"


def test_voice_asr_calls_tencent_when_configured(monkeypatch):
    calls = []

    def fake_post(url, data, headers, timeout):
        calls.append({"url": url, "data": data, "headers": headers, "timeout": timeout})
        return FakeTencentResponse()

    monkeypatch.setattr(voice.requests, "post", fake_post)
    monkeypatch.setattr(voice.time, "time", lambda: 1760000000)
    audio = b"fake-wav-bytes"
    app = create_app("testing")
    app.config.update(
        TENCENT_SECRET_ID="secret-id",
        TENCENT_SECRET_KEY="secret-key",
        TENCENT_ASR_REGION="ap-guangzhou",
        TENCENT_ASR_ENGINE_TYPE="16k_zh",
        TENCENT_ASR_VOICE_FORMAT="wav",
    )
    client = app.test_client()

    response = client.post(
        "/api/v1/voice/asr",
        json={"audioBase64": base64.b64encode(audio).decode("ascii")},
    )

    payload = response.get_json()
    assert response.status_code == 200
    assert payload["data"] == {"transcript": "今天下午七点去健身", "provider": "tencent"}
    assert len(calls) == 1
    assert calls[0]["url"] == "https://asr.tencentcloudapi.com"
    assert calls[0]["timeout"] == 20
    assert calls[0]["headers"]["X-TC-Action"] == "SentenceRecognition"
    assert calls[0]["headers"]["X-TC-Region"] == "ap-guangzhou"
    assert "Credential=secret-id/" in calls[0]["headers"]["Authorization"]
    assert b'"DataLen":14' in calls[0]["data"]
    assert b'"VoiceFormat":"wav"' in calls[0]["data"]