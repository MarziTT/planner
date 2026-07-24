"""Tests for GET /api/v1/dashboard/health — P3-F2 health trends endpoint."""

from datetime import datetime, timedelta, timezone

import jwt

TZ = timezone(timedelta(hours=8))

# ---------------------------------------------------------------------------
# Helpers — use app + db_session for ORM, return helpers
# ---------------------------------------------------------------------------


def _decode_user_id(app, token):
    """Decode JWT to get user_id, using app config for the secret."""
    # Strip "Bearer " prefix from header value
    raw = token.removeprefix("Bearer ")
    payload = jwt.decode(raw, app.config["JWT_SECRET_KEY"], algorithms=["HS256"])
    return payload["sub"]


def _make_exercise(db_session, user_id, minutes=30, calories=200, steps=5000):
    from app.models_habits import ExerciseRecord

    r = ExerciseRecord(
        user_id=user_id,
        exercise_type="walking",
        duration_minutes=minutes,
        calories=calories,
        steps=steps,
        recorded_at=datetime.now(TZ),
        source="auto",
    )
    db_session.add(r)
    db_session.commit()
    return r


def _make_meal(db_session, user_id, meal_type="lunch", items=None, recorded_at=None):
    from app.models_habits import MealRecord

    if items is None:
        items = [{"name": "test food", "calories": 300, "category": "肉类"}]

    r = MealRecord(
        user_id=user_id,
        meal_type=meal_type,
        items=items,
        recorded_at=recorded_at or datetime.now(TZ),
        source="tap",
    )
    db_session.add(r)
    db_session.commit()
    return r


def _make_standing_event(db_session, user_id, skipped=False):
    from app.models_habits import EventHistory

    now = datetime.now(TZ)
    e = EventHistory(
        user_id=user_id,
        notify_type="standing",
        planned_time=now,
        reminded_at=now if not skipped else None,
        completed_at=None if skipped else now,
        skipped=skipped,
    )
    db_session.add(e)
    db_session.commit()
    return e


def _make_wake_pattern(db_session, user_id, hour=7, minute=30):
    from app.models_habits import UserPattern

    existing = UserPattern.query.filter_by(
        user_id=user_id, pattern_type="wake_time"
    ).first()
    if existing:
        existing.pattern_value = {"hour": hour, "minute": minute}
    else:
        p = UserPattern(
            user_id=user_id,
            pattern_type="wake_time",
            pattern_key="",
            pattern_value={"hour": hour, "minute": minute},
            confidence=0.8,
            sample_count=10,
        )
        db_session.add(p)
    db_session.commit()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestHealthApiAuth:
    def test_health_requires_auth(self, app_client):
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health")
        assert resp.status_code == 401


class TestHealthApi:
    def test_health_empty_returns_structure(self, app_client, auth_headers):
        """Even with no data, returns correct structure."""
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["ok"] is True
        body = data["data"]
        assert "period" in body
        assert "exercise" in body
        assert "meals" in body
        assert "routine" in body
        assert "standing" in body
        assert body["period"]["days"] == 7

    def test_health_custom_days(self, app_client, auth_headers):
        """Custom days parameter works."""
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health?days=14", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.get_json()["data"]["period"]["days"] == 14

    def test_health_days_clamped(self, app_client, auth_headers):
        """Days is clamped to max 90."""
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health?days=200", headers=auth_headers)
        assert resp.status_code == 200
        assert resp.get_json()["data"]["period"]["days"] == 90

    def test_health_exercise_aggregation(self, app_client, auth_headers, db_session):
        """Exercise records are correctly aggregated."""
        app, client = app_client
        uid = _decode_user_id(app, auth_headers["Authorization"])
        _make_exercise(db_session, uid, minutes=30, calories=200, steps=5000)
        _make_exercise(db_session, uid, minutes=20, calories=150, steps=3000)

        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        ex = resp.get_json()["data"]["exercise"]
        assert ex["summary"]["total_minutes"] == 50
        assert ex["summary"]["total_calories"] == 350
        assert ex["summary"]["total_steps"] == 8000
        assert ex["summary"]["total_records"] == 2

    def test_health_meals_aggregation(self, app_client, auth_headers, db_session):
        """Meal records are correctly aggregated with calories."""
        app, client = app_client
        uid = _decode_user_id(app, auth_headers["Authorization"])
        _make_meal(db_session, uid, meal_type="lunch",
                   items=[{"name": "t1", "calories": 300, "category": "肉类"}])
        _make_meal(db_session, uid, meal_type="dinner",
                   items=[{"name": "t2", "calories": 250, "category": "主食"}])

        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        meals = resp.get_json()["data"]["meals"]
        assert meals["summary"]["total_calories"] == 550
        assert meals["summary"]["total_meals"] == 2

    def test_health_standing_aggregation(self, app_client, auth_headers, db_session):
        """Standing events are correctly counted."""
        app, client = app_client
        uid = _decode_user_id(app, auth_headers["Authorization"])
        _make_standing_event(db_session, uid, skipped=False)
        _make_standing_event(db_session, uid, skipped=False)
        _make_standing_event(db_session, uid, skipped=True)

        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        st = resp.get_json()["data"]["standing"]
        assert st["summary"]["total"] == 3
        assert st["summary"]["completed"] == 2
        assert st["summary"]["skipped"] == 1

    def test_health_routine_has_wake_time(self, app_client, auth_headers, db_session):
        """Routine section includes wake/sleep times."""
        app, client = app_client
        uid = _decode_user_id(app, auth_headers["Authorization"])
        _make_wake_pattern(db_session, uid, hour=7, minute=15)

        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        routine = resp.get_json()["data"]["routine"]
        assert "avg_wake_time" in routine["summary"]
        assert "default_wake_time" in routine["summary"]

    def test_health_daily_structures(self, app_client, auth_headers):
        """Each domain has 'daily' array with correct date format."""
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.get_json()["data"]

        for domain in ["exercise", "meals", "routine", "standing"]:
            assert "daily" in body[domain], f"{domain} missing 'daily'"
            assert "summary" in body[domain], f"{domain} missing 'summary'"
            assert len(body[domain]["daily"]) == 7, f"{domain} daily count != 7"
            assert "date" in body[domain]["daily"][0], f"{domain} daily[0] missing 'date'"


# ---------------------------------------------------------------------------
# CSV export tests — P3-F8
# ---------------------------------------------------------------------------


class TestHealthCsvExport:
    def test_csv_requires_auth(self, app_client):
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health-csv")
        assert resp.status_code == 401

    def test_csv_returns_csv(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health-csv", headers=auth_headers)
        assert resp.status_code == 200
        assert "text/csv" in resp.content_type
        assert "attachment" in resp.headers.get("Content-Disposition", "")

    def test_csv_has_header_row(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health-csv", headers=auth_headers)
        lines = resp.data.decode("utf-8").strip().split("\n")
        header = lines[0]
        assert "date" in header
        assert "exercise_minutes" in header
        assert "meal_calories" in header
        assert "wake_time" in header
        assert "standing_total" in header

    def test_csv_has_data_rows(self, app_client, auth_headers):
        _, client = app_client
        resp = client.get("/api/v1/dashboard/health-csv?days=3", headers=auth_headers)
        lines = resp.data.decode("utf-8").strip().split("\n")
        # header + 3 data rows
        assert len(lines) == 4

    def test_csv_with_exercise_data(self, app_client, auth_headers, db_session):
        app, client = app_client
        uid = _decode_user_id(app, auth_headers["Authorization"])
        _make_exercise(db_session, uid, minutes=45, calories=300, steps=6000)

        resp = client.get("/api/v1/dashboard/health-csv?days=1", headers=auth_headers)
        lines = resp.data.decode("utf-8").strip().split("\n")
        # Last column values should include exercise data
        data_row = lines[1].split(",")
        # exercise_minutes is column index 1
        assert data_row[1] == "45"
        assert data_row[2] == "300"

