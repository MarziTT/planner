"""Test dashboard API endpoints."""

from app.extensions import db


def _login(client, phone="13800000001"):
    resp = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": phone, "code": "888888"},
    )
    return {"Authorization": f"Bearer {resp.get_json()['data']['tokens']['accessToken']}"}


def test_dashboard_overview_requires_auth(app_client):
    """GET /dashboard/overview without auth returns 401."""
    _, client = app_client
    resp = client.get("/api/v1/dashboard/overview")
    assert resp.status_code == 401


def test_dashboard_overview_returns_ok(app_client):
    """GET /dashboard/overview returns 200 with all domains."""
    app, client = app_client
    headers = _login(client)
    try:
        resp = client.get("/api/v1/dashboard/overview", headers=headers)
        assert resp.status_code == 200
        payload = resp.get_json()
        assert payload["ok"] is True
        data = payload["data"]
        assert "date" in data
        assert "schedule" in data
        assert "weather" in data
        assert "routine" in data
        assert "meals" in data
        assert "exercise" in data
        assert "transit" in data
    finally:
        with app.app_context():
            db.drop_all()


def test_dashboard_overview_with_coords(app_client):
    """GET /dashboard/overview works with lat/lon params."""
    app, client = app_client
    headers = _login(client)
    try:
        resp = client.get(
            "/api/v1/dashboard/overview?lat=39.90&lon=116.40",
            headers=headers,
        )
        assert resp.status_code == 200
    finally:
        with app.app_context():
            db.drop_all()
