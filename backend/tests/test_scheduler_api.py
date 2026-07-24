"""Tests for POST /api/v1/scheduler/suggest and /api/v1/scheduler/conflicts."""

from datetime import datetime, timezone

UTC = timezone.utc


# ---------------------------------------------------------------------------
#  /scheduler/suggest
# ---------------------------------------------------------------------------


class TestSuggest:
    def test_unauthenticated_returns_401(self, app_client):
        _app, client = app_client
        resp = client.post("/api/v1/scheduler/suggest", json={"date": "2026-07-09"})
        assert resp.status_code == 401

    def test_missing_date_returns_422(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/suggest", json={}, headers=auth_headers
        )
        assert resp.status_code == 422
        assert resp.get_json()["error"]["code"] == "validation_error"

    def test_invalid_date_format_returns_422(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": "2026/07/09"},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_invalid_period_returns_422(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": "2026-07-09", "preferred_period": "midnight"},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_basic_suggest_returns_slots(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": "2026-07-09", "duration_minutes": 60},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()["data"]
        assert data["date"] == "2026-07-09"
        assert data["duration_minutes"] == 60
        assert "suggestions" in data
        assert isinstance(data["suggestions"], list)
        assert len(data["suggestions"]) > 0
        for s in data["suggestions"]:
            assert "starts_at" in s
            assert "ends_at" in s
            assert "period" in s
            assert "score" in s
            assert 0 <= s["score"] <= 100

    def test_suggest_respects_preferred_period(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/suggest",
            json={
                "date": "2026-07-09",
                "duration_minutes": 60,
                "preferred_period": "morning",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()["data"]
        for s in data["suggestions"]:
            start_hour = datetime.fromisoformat(s["starts_at"]).hour
            assert 7 <= start_hour < 12, (
                f"Expected morning slot, got hour={start_hour}"
            )

    def test_suggest_different_durations(self, app_client, auth_headers):
        """Longer duration → fewer slots available."""
        _app, client = app_client
        resp30 = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": "2026-07-09", "duration_minutes": 30},
            headers=auth_headers,
        )
        resp180 = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": "2026-07-09", "duration_minutes": 180},
            headers=auth_headers,
        )
        assert resp30.status_code == 200
        assert resp180.status_code == 200
        count30 = len(resp30.get_json()["data"]["suggestions"])
        count180 = len(resp180.get_json()["data"]["suggestions"])
        assert count30 >= count180, (
            f"30min={count30} should have >= slots than 180min={count180}"
        )

    def test_suggest_with_existing_event_excludes_conflicts(
        self, app_client, auth_headers
    ):
        """Create an event at 10:00–11:00, verify that slot is excluded."""
        _app, client = app_client
        today = datetime.now(UTC).strftime("%Y-%m-%d")

        # Create a conflicting event
        create_resp = client.post(
            "/api/v1/events",
            json={
                "title": "Test event",
                "startsAt": f"{today}T10:00:00+00:00",
                "endsAt": f"{today}T11:00:00+00:00",
            },
            headers=auth_headers,
        )
        assert create_resp.status_code == 201

        suggest_resp = client.post(
            "/api/v1/scheduler/suggest",
            json={"date": today, "duration_minutes": 60},
            headers=auth_headers,
        )
        assert suggest_resp.status_code == 200
        data = suggest_resp.get_json()["data"]
        for s in data["suggestions"]:
            start = datetime.fromisoformat(s["starts_at"])
            assert start.hour != 10, f"Slot at 10:00 should be excluded: {s}"


# ---------------------------------------------------------------------------
#  /scheduler/conflicts
# ---------------------------------------------------------------------------


class TestConflicts:
    def test_unauthenticated_returns_401(self, app_client):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/conflicts",
            json={
                "starts_at": "2026-07-09T14:00:00",
                "ends_at": "2026-07-09T15:00:00",
            },
        )
        assert resp.status_code == 401

    def test_missing_fields_returns_422(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/conflicts", json={}, headers=auth_headers
        )
        assert resp.status_code == 422

    def test_invalid_end_order_returns_422(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/conflicts",
            json={
                "starts_at": "2026-07-09T15:00:00",
                "ends_at": "2026-07-09T14:00:00",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_no_conflicts_when_empty(self, app_client, auth_headers):
        _app, client = app_client
        resp = client.post(
            "/api/v1/scheduler/conflicts",
            json={
                "starts_at": "2026-07-09T14:00:00",
                "ends_at": "2026-07-09T15:00:00",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()["data"]
        assert data["has_conflicts"] is False
        assert data["conflicts"] == []

    def test_detects_overlap(self, app_client, auth_headers):
        """Create an event, verify conflict detection finds it."""
        _app, client = app_client
        today = datetime.now(UTC).strftime("%Y-%m-%d")

        create_resp = client.post(
            "/api/v1/events",
            json={
                "title": "Conflict test",
                "startsAt": f"{today}T14:00:00+00:00",
                "endsAt": f"{today}T15:00:00+00:00",
            },
            headers=auth_headers,
        )
        assert create_resp.status_code == 201

        resp = client.post(
            "/api/v1/scheduler/conflicts",
            json={
                "starts_at": f"{today}T14:30:00+00:00",
                "ends_at": f"{today}T15:30:00+00:00",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()["data"]
        assert data["has_conflicts"] is True
        assert len(data["conflicts"]) == 1
        assert data["conflicts"][0]["title"] == "Conflict test"
        assert data["conflicts"][0]["overlap_minutes"] == 30

    def test_exclude_event_id(self, app_client, auth_headers):
        """Exclude an event from conflict detection (for rescheduling)."""
        _app, client = app_client
        today = datetime.now(UTC).strftime("%Y-%m-%d")

        create_resp = client.post(
            "/api/v1/events",
            json={
                "title": "Self event",
                "startsAt": f"{today}T14:00:00+00:00",
                "endsAt": f"{today}T15:00:00+00:00",
            },
            headers=auth_headers,
        )
        event_id = create_resp.get_json()["data"]["item"]["id"]

        resp = client.post(
            "/api/v1/scheduler/conflicts",
            json={
                "starts_at": f"{today}T14:00:00+00:00",
                "ends_at": f"{today}T15:00:00+00:00",
                "exclude_event_id": event_id,
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()["data"]
        assert data["has_conflicts"] is False
