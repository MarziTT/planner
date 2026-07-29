"""Tests for /scene/check — P6 scene linkage."""

from datetime import datetime, timedelta, timezone

from app.extensions import db
from app.models import Event, User
from app.models_habits import ExerciseRecord, MealRecord, UserPattern

TZ = timezone(timedelta(hours=8))


def _get_user_id(app_client) -> int:
    """Get user_id from existing test user created by auth_headers."""
    app, _ = app_client
    with app.app_context():
        user = db.session.query(User).filter(User.phone == "13800000001").first()
        return user.id


class TestSceneCheck:
    """Basic endpoint behaviour."""

    def test_requires_auth(self, app_client):
        _, client = app_client
        resp = client.get("/api/v1/scene/check")
        assert resp.status_code == 401

    def test_returns_no_unexpected_cards_for_new_user(self, app_client, auth_headers, fixed_clock):
        """A new user has no weather/schedule cards at the fixed test time.

        The scene engine intentionally creates exercise/meal nudges after
        their configured thresholds.  This test must therefore control the
        clock instead of assuming the wall clock is before those thresholds.
        """
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["ok"] is True
        assert "cards" in data["data"]
        assert data["data"]["cards"] == []

    def test_formatted_response(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check?weather=中雨",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["ok"] is True
        cards = data["data"]["cards"]
        assert isinstance(cards, list)


class TestWeatherScene:
    """Weather warning scenarios."""

    def test_rain_triggers_weather_warning(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check?weather=中雨，15°C-22°C",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        cards = resp.get_json()["data"]["cards"]
        weather_cards = [c for c in cards if c["type"] == "weather_warning"]
        assert len(weather_cards) == 1
        assert weather_cards[0]["priority"] == "high"
        assert "🌧" in weather_cards[0]["icon"]

    def test_sunny_no_warning(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check?weather=晴，22°C-30°C",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        weather_cards = [c for c in cards if c["type"] == "weather_warning"]
        assert len(weather_cards) == 0

    def test_snow_triggers_warning(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check?weather=大雪，-5°C-0°C",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        weather_cards = [c for c in cards if c["type"] == "weather_warning"]
        assert len(weather_cards) == 1


class TestExerciseScene:
    """Exercise nudge scenarios."""

    def test_no_exercise_triggers_nudge(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        exercise_cards = [c for c in cards if c["type"] == "exercise_nudge"]
        now = fixed_now
        if now.hour >= 16:
            assert len(exercise_cards) == 1
            assert exercise_cards[0]["title"] == "今天还没有运动哦"
        else:
            assert len(exercise_cards) == 0

    def test_enough_exercise_no_nudge(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)
        now = fixed_now

        with app_client[0].app_context():
            record = ExerciseRecord(
                user_id=uid,
                exercise_type="跑步",
                duration_minutes=30,
                calories_burned=210,
                completed_at=now,
            )
            db.session.add(record)
            db.session.commit()

        resp = client.get(
            "/api/v1/scene/check",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        exercise_cards = [c for c in cards if c["type"] == "exercise_nudge"]
        assert len(exercise_cards) == 0


class TestMealScene:
    """Meal reminder scenarios."""

    def test_no_dinner_triggers_reminder(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        resp = client.get(
            "/api/v1/scene/check",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        meal_cards = [c for c in cards if c["type"] == "meal_reminder"]
        now = fixed_now
        if now.hour >= 19:
            assert len(meal_cards) == 1
        else:
            assert len(meal_cards) == 0

    def test_dinner_logged_no_reminder(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)
        now = fixed_now

        with app_client[0].app_context():
            meal = MealRecord(
                user_id=uid,
                meal_type="晚餐",
                recorded_at=now,
                items='[{"name": "米饭", "calories": 300}]',
            )
            db.session.add(meal)
            db.session.commit()

        resp = client.get(
            "/api/v1/scene/check",
            headers=auth_headers,
        )
        cards = resp.get_json()["data"]["cards"]
        meal_cards = [c for c in cards if c["type"] == "meal_reminder"]
        assert len(meal_cards) == 0


class TestConflictScene:
    """Schedule conflict scenarios."""

    def test_overlapping_events_trigger_conflict(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)
        now = fixed_now
        today_start = datetime(now.year, now.month, now.day, tzinfo=TZ)

        with app_client[0].app_context():
            e1 = Event(
                user_id=uid,
                title="项目评审",
                starts_at=today_start + timedelta(hours=14),
                ends_at=today_start + timedelta(hours=15, minutes=30),
            )
            e2 = Event(
                user_id=uid,
                title="团队会议",
                starts_at=today_start + timedelta(hours=15),
                ends_at=today_start + timedelta(hours=16),
            )
            db.session.add_all([e1, e2])
            db.session.commit()

            resp = client.get(
                "/api/v1/scene/check",
                headers=auth_headers,
            )
        cards = resp.get_json()["data"]["cards"]
        conflict_cards = [c for c in cards if c["type"] == "conflict_alert"]
        assert len(conflict_cards) == 1
        assert conflict_cards[0]["priority"] == "high"

    def test_non_overlapping_no_conflict(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)
        now = fixed_now
        today_start = datetime(now.year, now.month, now.day, tzinfo=TZ)

        with app_client[0].app_context():
            e1 = Event(
                user_id=uid,
                title="项目评审",
                starts_at=today_start + timedelta(hours=10),
                ends_at=today_start + timedelta(hours=11),
            )
            e2 = Event(
                user_id=uid,
                title="团队会议",
                starts_at=today_start + timedelta(hours=14),
                ends_at=today_start + timedelta(hours=15),
            )
            db.session.add_all([e1, e2])
            db.session.commit()

            resp = client.get(
                "/api/v1/scene/check",
                headers=auth_headers,
            )
        cards = resp.get_json()["data"]["cards"]
        conflict_cards = [c for c in cards if c["type"] == "conflict_alert"]
        assert len(conflict_cards) == 0


class TestWakeScene:
    """Wake adjustment scenarios."""

    def test_late_wake_no_events_low_priority(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)

        with app_client[0].app_context():
            pattern = UserPattern(
                user_id=uid,
                wake_time="06:00",
            )
            db.session.add(pattern)
            db.session.commit()

            resp = client.get(
                "/api/v1/scene/check",
                headers=auth_headers,
            )
        cards = resp.get_json()["data"]["cards"]
        wake_cards = [c for c in cards if c["type"] == "wake_adjust"]
        now = fixed_now
        if now.hour < 12:
            assert len(wake_cards) >= 1
        if wake_cards:
            assert wake_cards[0]["priority"] == "low"


class TestCardStructure:
    """Verify card JSON structure is consistent."""

    def test_all_cards_have_required_fields(self, app_client, auth_headers, fixed_now):
        _, client = app_client
        uid = _get_user_id(app_client)
        now = fixed_now
        today_start = datetime(now.year, now.month, now.day, tzinfo=TZ)

        with app_client[0].app_context():
            e1 = Event(
                user_id=uid,
                title="A",
                starts_at=today_start + timedelta(hours=14),
                ends_at=today_start + timedelta(hours=15, minutes=30),
            )
            e2 = Event(
                user_id=uid,
                title="B",
                starts_at=today_start + timedelta(hours=15),
                ends_at=today_start + timedelta(hours=16),
            )
            db.session.add_all([e1, e2])
            db.session.commit()

            resp = client.get(
                "/api/v1/scene/check?weather=中雨，15°C-22°C",
                headers=auth_headers,
            )
        cards = resp.get_json()["data"]["cards"]

        required_fields = {"type", "priority", "icon", "title", "body", "action_label", "action_type"}
        for card in cards:
            missing = required_fields - set(card.keys())
            assert not missing, f"Card {card.get('type')} missing fields: {missing}"
