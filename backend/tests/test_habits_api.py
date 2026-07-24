"""Test habits API endpoints."""

from app.extensions import db


def _login(client, phone="13800000001"):
    resp = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": phone, "code": "888888"},
    )
    return {"Authorization": f"Bearer {resp.get_json()['data']['tokens']['accessToken']}"}


def test_habits_summary_requires_auth(app_client):
    """GET /habits/summary without auth returns 401."""
    _, client = app_client
    resp = client.get("/api/v1/habits/summary")
    assert resp.status_code == 401


def test_habits_summary_returns_ok(app_client):
    """GET /habits/summary returns 200 with learned habits."""
    app, client = app_client
    headers = _login(client)
    try:
        resp = client.get("/api/v1/habits/summary", headers=headers)
        assert resp.status_code == 200
        payload = resp.get_json()
        assert payload["ok"] is True
    finally:
        with app.app_context():
            db.drop_all()


def test_notify_preferences_requires_auth(app_client):
    """PUT /notify/preferences without auth returns 401."""
    _, client = app_client
    resp = client.put("/api/v1/notify/preferences", json={"enable_smart_push": True})
    assert resp.status_code == 401


def test_notify_preferences_update(app_client):
    """PUT /notify/preferences stores and retrieves preferences."""
    app, client = app_client
    headers = _login(client)
    try:
        # Update preferences
        resp = client.put(
            "/api/v1/notify/preferences",
            headers=headers,
            json={
                "notify_type": "standing",
                "enabled": True,
                "lead_minutes": 5,
                "quiet_hours_start": "22:00",
                "quiet_hours_end": "07:00",
            },
        )
        assert resp.status_code == 200

        # Verify stored in habits summary
        summary = client.get("/api/v1/habits/summary", headers=headers)
        assert summary.status_code == 200
        pref = summary.get_json()["data"].get("notify_preferences")
        assert pref is not None
        assert len(pref) > 0
        assert pref[0]["enabled"] is True
        assert pref[0]["lead_minutes"] == 5
    finally:
        with app.app_context():
            db.drop_all()
