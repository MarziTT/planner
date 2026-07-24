"""Tests for Widget API — PixelPlanner P3-F9."""

from datetime import datetime, timedelta, timezone

import jwt

from app.extensions import db
from app.models import Event
from app.models_habits import EventHistory, ExerciseRecord, MealRecord

TZ = timezone(timedelta(hours=8))


def _decode_user_id(app, token):
    """Decode JWT from auth header to get user_id."""
    raw = token.removeprefix("Bearer ")
    payload = jwt.decode(raw, app.config["JWT_SECRET_KEY"], algorithms=["HS256"])
    return payload["sub"]


class TestWidgetSummary:
    """GET /api/v1/widget/summary — compact daily summary for home screen widget."""

    def test_requires_auth(self, app_client):
        _, client = app_client
        resp = client.get("/api/v1/widget/summary")
        assert resp.status_code == 401

    def test_returns_summary_structure(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["ok"] is True
        summary = data["data"]

        # All required sections present
        for key in ("header", "meals", "exercise", "schedule", "health"):
            assert key in summary, f"Missing key: {key}"

        # Header fields
        header = summary["header"]
        assert "date" in header
        assert "weekday" in header
        assert "greeting" in header

        # Meals fields
        meals = summary["meals"]
        assert "summary" in meals
        assert "total_calories" in meals
        assert "count" in meals
        assert meals["count"] == 0  # no meals recorded yet

        # Exercise fields
        exercise = summary["exercise"]
        assert "summary" in exercise
        assert "minutes" in exercise
        assert "status" in exercise

        # Schedule fields
        schedule = summary["schedule"]
        assert "next" in schedule
        assert "count" in schedule
        assert "summary" in schedule

        # Health fields
        health = summary["health"]
        assert "stand_completed" in health
        assert "stand_label" in health

    def test_returns_meals_when_present(self, app_client, auth_headers, db_session):
        app, client = app_client
        user_id = _decode_user_id(app, auth_headers["Authorization"])
        now = datetime.now(TZ)
        meal = MealRecord(
            user_id=user_id,
            meal_type="午餐",
            items=[{"name": "牛肉面", "calories": 650, "category": "主食"}],
            recorded_at=now,
        )
        db_session.add(meal)
        db_session.commit()

        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        meals = resp.get_json()["data"]["meals"]
        assert meals["count"] == 1
        assert meals["total_calories"] == 650
        assert "已记录 1 餐" in meals["summary"]

    def test_returns_exercise_when_present(self, app_client, auth_headers, db_session):
        app, client = app_client
        user_id = _decode_user_id(app, auth_headers["Authorization"])
        now = datetime.now(TZ)
        record = ExerciseRecord(
            user_id=user_id,
            exercise_type="跑步",
            duration_minutes=40,
            calories=300,
            recorded_at=now,
        )
        db_session.add(record)
        db_session.commit()

        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        exercise = resp.get_json()["data"]["exercise"]
        assert exercise["minutes"] == 40
        assert exercise["calories"] == 300
        assert exercise["status"] == "今日达标"

    def test_returns_upcoming_events(self, app_client, auth_headers, db_session):
        app, client = app_client
        user_id = _decode_user_id(app, auth_headers["Authorization"])
        now = datetime.now(TZ)
        future = now + timedelta(hours=2)

        event = Event(
            user_id=user_id,
            title="项目评审",
            starts_at=future,
            ends_at=future + timedelta(hours=1),
        )
        db_session.add(event)
        db_session.commit()

        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        schedule = resp.get_json()["data"]["schedule"]
        assert schedule["count"] == 1
        assert schedule["next"] is not None
        assert "项目评审" in schedule["next"]

    def test_no_upcoming_events_shows_none(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        schedule = resp.get_json()["data"]["schedule"]
        assert schedule["count"] == 0
        assert schedule["next"] is None
        assert "今日无日程" in schedule["summary"]

    def test_standing_status(self, app_client, auth_headers, db_session):
        app, client = app_client
        user_id = _decode_user_id(app, auth_headers["Authorization"])
        now = datetime.now(TZ)

        # Add 2 completed standing events + 1 skipped
        for _ in range(2):
            e = EventHistory(
                user_id=user_id,
                notify_type="standing",
                planned_time=now,
                completed_at=now,
                skipped=False,
            )
            db_session.add(e)
        e_skip = EventHistory(
            user_id=user_id,
            notify_type="standing",
            planned_time=now,
            completed_at=None,
            skipped=True,
        )
        db_session.add(e_skip)
        db_session.commit()

        resp = client.get("/api/v1/widget/summary", headers=auth_headers)
        assert resp.status_code == 200
        health = resp.get_json()["data"]["health"]
        assert health["stand_total"] == 3
        assert health["stand_completed"] == 2
        assert health["stand_skipped"] == 1
        assert "2 次" in health["stand_label"]
