"""Tests for exercise_service.py — mode management, record CRUD, summaries.

Requires DB fixtures (test_user).
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from app.extensions import db
from app.models import User
from app.models_habits import ExerciseRecord
from app.services.exercise_service import (
    create_record,
    get_current_mode,
    get_history,
    get_today_summary,
    set_mode,
)


# ===========================================================================
# get_current_mode
# ===========================================================================


class TestGetCurrentMode:
    def test_default_mode(self, db_session, test_user):
        """Default exercise_mode is 'self'."""
        result = get_current_mode(test_user)
        assert result["exercise_mode"] == "self"
        assert result["trainer_end_date"] is None

    def test_trainer_mode_active(self, db_session, test_user):
        """Active trainer mode should be returned as-is."""
        test_user.exercise_mode = "trainer"
        future = (datetime.now(timezone.utc) + timedelta(days=30)).date()
        test_user.trainer_end_date = future
        db_session.commit()

        result = get_current_mode(test_user)
        assert result["exercise_mode"] == "trainer"
        assert result["trainer_end_date"] is not None

    def test_trainer_mode_expired_auto_switch(self, db_session, test_user):
        """Expired trainer mode should auto-switch back to self."""
        test_user.exercise_mode = "trainer"
        past = (datetime.now(timezone.utc) - timedelta(days=1))
        test_user.trainer_end_date = past
        db_session.commit()

        result = get_current_mode(test_user)
        assert result["exercise_mode"] == "self"
        assert result["trainer_end_date"] is None

        # Verify DB was actually updated
        db_session.refresh(test_user)
        assert test_user.exercise_mode == "self"
        assert test_user.trainer_end_date is None


# ===========================================================================
# set_mode
# ===========================================================================


class TestSetMode:
    def test_set_self(self, db_session, test_user):
        result = set_mode(test_user, "self")
        assert result["exercise_mode"] == "self"
        assert result["trainer_end_date"] is None

    def test_set_trainer_with_date(self, db_session, test_user):
        future = "2026-12-31"
        result = set_mode(test_user, "trainer", trainer_end_date=future)
        assert result["exercise_mode"] == "trainer"
        assert result["trainer_end_date"] is not None

    def test_set_trainer_without_date(self, db_session, test_user):
        """Setting trainer without a date should clear trainer_end_date."""
        result = set_mode(test_user, "trainer")
        assert result["exercise_mode"] == "trainer"
        assert result["trainer_end_date"] is None


# ===========================================================================
# create_record
# ===========================================================================


class TestCreateRecord:
    def test_minimal_record(self, db_session, test_user):
        record = create_record(
            user_id=test_user.id,
            exercise_type="running",
            duration_minutes=30,
        )
        assert record.id is not None
        assert record.user_id == test_user.id
        assert record.exercise_type == "running"
        assert record.duration_minutes == 30
        assert record.source == "manual"

    def test_full_record(self, db_session, test_user):
        now = datetime.now(timezone.utc)
        record = create_record(
            user_id=test_user.id,
            exercise_type="walking",
            duration_minutes=45,
            source="sensor",
            calories=200,
            steps=5000,
            recorded_at=now,
        )
        assert record.calories == 200
        assert record.steps == 5000
        assert record.source == "sensor"
        # SQLite stores as naive datetime; compare the UTC timestamp
        assert record.recorded_at.replace(tzinfo=timezone.utc) == now

    def test_record_in_db(self, db_session, test_user):
        """Record should be persisted and retrievable."""
        create_record(test_user.id, "cycling", 60)
        records = ExerciseRecord.query.filter_by(user_id=test_user.id).all()
        assert len(records) == 1
        assert records[0].exercise_type == "cycling"


# ===========================================================================
# get_today_summary
# ===========================================================================


class TestGetTodaySummary:
    def test_empty(self, db_session, test_user):
        summary = get_today_summary(test_user.id)
        assert summary["total_minutes"] == 0
        assert summary["total_calories"] == 0
        assert summary["total_steps"] == 0
        assert summary["records"] == []

    def test_with_records(self, db_session, test_user):
        create_record(test_user.id, "running", 30, calories=300, steps=4000)
        create_record(test_user.id, "walking", 20, calories=100, steps=2000)

        summary = get_today_summary(test_user.id)
        assert summary["total_minutes"] == 50
        assert summary["total_calories"] == 400
        assert summary["total_steps"] == 6000
        assert len(summary["records"]) == 2

    def test_user_isolation(self, db_session, test_user, test_user2):
        """User A's records should not appear in User B's summary."""
        create_record(test_user.id, "running", 30, calories=300)
        summary = get_today_summary(test_user2.id)
        assert summary["total_minutes"] == 0


# ===========================================================================
# get_history
# ===========================================================================


class TestGetHistory:
    def test_empty(self, db_session, test_user):
        result = get_history(test_user.id)
        assert result["records"] == []
        assert result["days"] == 7

    def test_with_records(self, db_session, test_user):
        # Create a record dated 2 days ago
        two_days_ago = datetime.now(timezone.utc) - timedelta(days=2)
        record = ExerciseRecord(
            user_id=test_user.id,
            exercise_type="running",
            duration_minutes=30,
            recorded_at=two_days_ago,
        )
        db_session.add(record)
        db_session.commit()

        result = get_history(test_user.id, days=7)
        assert len(result["records"]) == 1

    def test_days_filter(self, db_session, test_user):
        """Records older than `days` should be excluded."""
        ten_days_ago = datetime.now(timezone.utc) - timedelta(days=10)
        record = ExerciseRecord(
            user_id=test_user.id,
            exercise_type="running",
            duration_minutes=30,
            recorded_at=ten_days_ago,
        )
        db_session.add(record)
        db_session.commit()

        result = get_history(test_user.id, days=7)
        assert len(result["records"]) == 0

        result_full = get_history(test_user.id, days=30)
        assert len(result_full["records"]) == 1
