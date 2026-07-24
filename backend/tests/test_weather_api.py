"""Test weather API endpoints."""

from app.extensions import db


def _login(client, phone="13800000001"):
    resp = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": phone, "code": "888888"},
    )
    return {"Authorization": f"Bearer {resp.get_json()['data']['tokens']['accessToken']}"}


def test_weather_requires_auth(app_client):
    """GET /weather/ without auth returns 401."""
    _, client = app_client
    resp = client.get("/api/v1/weather/?lat=39.90&lon=116.40")
    assert resp.status_code == 401


def test_weather_missing_coords(app_client):
    """GET /weather/ without lat/lon returns 422."""
    _, client = app_client
    headers = _login(client)
    resp = client.get("/api/v1/weather/", headers=headers)
    assert resp.status_code == 422
    assert resp.get_json()["error"]["code"] == "validation_error"


def test_weather_invalid_coords(app_client):
    """GET /weather/ with non-numeric lat/lon returns 422."""
    _, client = app_client
    headers = _login(client)
    resp = client.get("/api/v1/weather/?lat=abc&lon=xyz", headers=headers)
    assert resp.status_code == 422
    assert resp.get_json()["error"]["code"] == "validation_error"


def test_weather_debug_requires_auth(app_client):
    """GET /weather/debug without auth returns 401."""
    _, client = app_client
    resp = client.get("/api/v1/weather/debug")
    assert resp.status_code == 401


def test_weather_debug_returns_ok(app_client):
    """GET /weather/debug returns connection health info."""
    app, client = app_client
    headers = _login(client)
    try:
        resp = client.get("/api/v1/weather/debug", headers=headers)
        assert resp.status_code == 200
        payload = resp.get_json()
        assert payload["ok"] is True
        data = payload["data"]
        assert "api_ok" in data or "kid_configured" in data
        # No sensitive data leaked
        assert "private_key" not in str(data).lower()
    finally:
        with app.app_context():
            db.drop_all()
