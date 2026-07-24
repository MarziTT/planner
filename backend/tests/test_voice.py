import base64

from app import create_app
from app.api import voice
from app.extensions import db


def _login(client):
    """Login a test user and return the access token."""
    resp = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": "13800000001", "code": "888888"},
    )
    assert resp.status_code in (200, 201)
    return resp.get_json()["data"]["tokens"]["accessToken"]


def _auth_headers(client):
    token = _login(client)
    return {"Authorization": f"Bearer {token}"}


class FakeTencentResponse:
    def raise_for_status(self):
        return None

    def json(self):
        return {"Response": {"Result": "今天下午七点去健身"}}


def test_voice_asr_text_mock_still_works():
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    try:
        client = app.test_client()
        headers = _auth_headers(client)

        response = client.post(
            "/api/v1/voice/asr",
            json={"textMock": "明天五点的飞机"},
            headers=headers,
        )

        payload = response.get_json()
        assert response.status_code == 200
        assert payload["data"]["transcript"] == "明天五点的飞机"
        assert payload["data"]["provider"] == "mock"
    finally:
        with app.app_context():
            db.drop_all()


def test_voice_asr_requires_audio_without_mock():
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    try:
        client = app.test_client()
        headers = _auth_headers(client)

        response = client.post(
            "/api/v1/voice/asr",
            json={},
            headers=headers,
        )

        assert response.status_code == 422
        assert response.get_json()["error"]["code"] == "validation_error"
    finally:
        with app.app_context():
            db.drop_all()


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
    with app.app_context():
        db.create_all()
    try:
        client = app.test_client()
        headers = _auth_headers(client)

        response = client.post(
            "/api/v1/voice/asr",
            json={"audioBase64": base64.b64encode(audio).decode("ascii")},
            headers=headers,
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
    finally:
        with app.app_context():
            db.drop_all()
