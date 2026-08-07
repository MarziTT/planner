from sqlalchemy import text

from app.extensions import db
from app.models import AppSetting


def _login(client):
    response = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": "13800000001", "code": "888888"},
    )
    return {"Authorization": f"Bearer {response.get_json()['data']['tokens']['accessToken']}"}


def test_settings_masks_llm_key_and_preserves_masked_round_trip(app_client):
    app, client = app_client
    headers = _login(client)
    try:
        first = client.put(
            "/api/v1/settings",
            json={"llmApiKey": "sk-super-secret-value", "llmModel": "model-a"},
            headers=headers,
        )
        item = first.get_json()["data"]["item"]
        assert item["llmApiKey"] == "****alue"
        assert item["llmApiKeyConfigured"] is True
        assert "sk-super-secret" not in first.get_data(as_text=True)

        second = client.put(
            "/api/v1/settings",
            json={"llmApiKey": item["llmApiKey"], "llmModel": "model-b"},
            headers=headers,
        )
        assert second.get_json()["data"]["item"]["llmApiKey"] == "****alue"

        with app.app_context():
            setting = AppSetting.query.filter_by(user_id=1).first()
            assert setting is not None
            assert setting.llm_api_key == "sk-super-secret-value"
    finally:
        with app.app_context():
            db.drop_all()


def test_butler_tone_round_trip_and_compatibility(app_client):
    app, client = app_client
    headers = _login(client)
    try:
        get_response = client.get("/api/v1/settings/butler-tone", headers=headers)
        assert get_response.status_code == 200
        assert get_response.get_json()["data"]["butler_tone"] in (None, "")

        save_response = client.put(
            "/api/v1/settings/butler-tone",
            json={"butler_tone": "温和、简洁、先结论后建议"},
            headers=headers,
        )
        assert save_response.status_code == 200
        assert save_response.get_json()["data"]["butler_tone"] == "温和、简洁、先结论后建议"

        compat_response = client.get("/api/v1/settings/weather-tone", headers=headers)
        compat_data = compat_response.get_json()["data"]
        assert compat_data["butler_tone"] == "温和、简洁、先结论后建议"
        assert compat_data["weather_tone"] == "温和、简洁、先结论后建议"
    finally:
        with app.app_context():
            db.drop_all()


def test_settings_endpoint_repairs_partial_legacy_table(app_client):
    app, client = app_client
    headers = _login(client)
    try:
        with app.app_context():
            db.session.execute(text("DROP TABLE settings"))
            db.session.execute(text("""
                CREATE TABLE settings (
                    user_id INTEGER PRIMARY KEY,
                    theme VARCHAR(32) NOT NULL DEFAULT 'forest',
                    theme_mode VARCHAR(16) NOT NULL DEFAULT 'dark',
                    notifications_enabled BOOLEAN NOT NULL DEFAULT 1,
                    voice_enabled BOOLEAN NOT NULL DEFAULT 1,
                    update_channel VARCHAR(32) NOT NULL DEFAULT 'stable',
                    weather_tone TEXT,
                    created_at DATETIME,
                    updated_at DATETIME
                )
            """))
            db.session.execute(text("""
                INSERT INTO settings (
                    user_id, theme, theme_mode, notifications_enabled,
                    voice_enabled, update_channel, weather_tone
                ) VALUES (1, 'forest', 'dark', 1, 1, 'stable', '温和旧语气')
            """))
            db.session.commit()

        response = client.get("/api/v1/settings", headers=headers)

        assert response.status_code == 200
        item = response.get_json()["data"]["item"]
        assert item["llmApiKey"] == ""
        assert item["llmBaseUrl"] == ""
        assert item["llmModel"] == ""

        tone_response = client.get("/api/v1/settings/butler-tone", headers=headers)
        assert tone_response.status_code == 200
        assert tone_response.get_json()["data"]["butler_tone"] == "温和旧语气"
    finally:
        with app.app_context():
            db.drop_all()


