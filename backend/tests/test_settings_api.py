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
