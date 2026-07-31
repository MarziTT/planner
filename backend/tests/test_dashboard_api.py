"""Test dashboard API endpoints."""

from datetime import datetime, timedelta

from app.extensions import db
from app.models import Event, User
from app.services.dashboard_service import _get_schedule_snapshot
from app.services.time_service import SHANGHAI_TZ


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


def test_schedule_snapshot_counts_all_events_beyond_preview_limit(app_client):
    """The count includes every event even though only three are previewed."""
    app, _ = app_client
    with app.app_context():
        user = User(phone="13800000009", nickname="Count Test")
        db.session.add(user)
        db.session.flush()

        day = datetime(2026, 7, 29, tzinfo=SHANGHAI_TZ)
        for index in range(11):
            starts_at = day + timedelta(minutes=index * 10)
            db.session.add(Event(
                user_id=user.id,
                title=f"Event {index}",
                starts_at=starts_at,
                ends_at=starts_at + timedelta(minutes=5),
            ))
        db.session.commit()

        snapshot = _get_schedule_snapshot(
            user.id,
            day.replace(hour=0, minute=0, second=0),
            day.replace(hour=23, minute=59, second=59),
        )

        assert snapshot["event_count"] == 11
        assert snapshot["pending_count"] == 11
        assert len(snapshot["upcoming"]) == 3
