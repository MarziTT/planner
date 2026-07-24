"""Tests for routine_service.py — wake time, sleep, standing status.

Requires DB fixtures (test_user).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, time, timezone

import pytest
from app.extensions import db
from app.models_habits import EventHistory, UserPattern
from app.services.routine_service import (
    get_routine_today,
    get_standing_status,
    record_wake,
    update_wake_time,
)

TZ = timezone(timedelta(hours=8))


# ===========================================================================
# get_routine_today
# ===========================================================================


class TestGetRoutineToday:
    def test_default_routine(self, db_session, test_user):
        """No learned pattern → use defaults (wake 7:30, sleep 23:30)."""
        result = get_routine_today(test_user.id)

        assert result["date"] == date.today().isoformat()
        assert result["wake_time"]["hour"] == 7
        assert result["wake_time"]["minute"] == 30
        assert result["wake_time"]["source"] == "default"
        assert result["sleep_time"]["hour"] == 23
        assert result["sleep_time"]["minute"] == 30
        assert len(result["timeline"]) == 3

    def test_learned_wake_time(self, db_session, test_user):
        """If UserPattern exists for wake_time, use it."""
        import json
        pattern = UserPattern(
            user_id=test_user.id,
            pattern_type="wake_time",
            pattern_key="default",
            pattern_value=json.dumps({"hour": 6, "minute": 0}),
            confidence=0.9,
            sample_count=5,
        )
        db_session.add(pattern)
        db_session.commit()

        result = get_routine_today(test_user.id)
        assert result["wake_time"]["hour"] == 6
        assert result["wake_time"]["minute"] == 0
        assert result["wake_time"]["source"] == "learned"
        # Sleep time = 6:00 - 8h = 22:00
        assert result["sleep_time"]["hour"] == 22
        assert result["sleep_time"]["minute"] == 0

    def test_timeline_order(self, db_session, test_user):
        """Timeline should follow: wake → sleep reminder → sleep."""
        result = get_routine_today(test_user.id)
        timeline = result["timeline"]
        labels = [t["label"] for t in timeline]
        assert labels == ["起床", "入睡提醒", "预计入睡"]

    def test_standing_included(self, db_session, test_user):
        """Routine should include standing status."""
        result = get_routine_today(test_user.id)
        assert "standing" in result
        assert result["standing"]["enabled"] is True
        assert "interval_minutes" in result["standing"]


# ===========================================================================
# record_wake
# ===========================================================================


class TestRecordWake:
    def test_auto_time(self, db_session, test_user):
        """record_wake with no arg uses current time."""
        result = record_wake(test_user.id)
        now = datetime.now(TZ)
        assert result["hour"] == now.hour
        assert result["minute"] == now.minute

    def test_explicit_time(self, db_session, test_user):
        result = record_wake(test_user.id, wake_time="06:15")
        assert result["hour"] == 6
        assert result["minute"] == 15

    def test_invalid_format(self, db_session, test_user):
        with pytest.raises(ValueError, match="Invalid time format"):
            record_wake(test_user.id, wake_time="not-a-time")

    def test_persists_pattern(self, db_session, test_user):
        """After recording wake time, a UserPattern should exist."""
        record_wake(test_user.id, wake_time="06:45")

        pattern = UserPattern.query.filter_by(
            user_id=test_user.id,
            pattern_type="wake_time",
            pattern_key="default",
        ).first()
        assert pattern is not None
        assert pattern.sample_count == 1


# ===========================================================================
# update_wake_time
# ===========================================================================


class TestUpdateWakeTime:
    def test_valid_time(self, db_session, test_user):
        result = update_wake_time(test_user.id, 8, 0)
        assert result["hour"] == 8
        assert result["minute"] == 0
        assert result["source"] == "manual"

    def test_invalid_hour(self, db_session, test_user):
        with pytest.raises(ValueError):
            update_wake_time(test_user.id, 25, 0)

    def test_invalid_minute(self, db_session, test_user):
        with pytest.raises(ValueError):
            update_wake_time(test_user.id, 8, 60)

    def test_boundary_values(self, db_session, test_user):
        """Edge values 0, 23, 0, 59 should all be valid."""
        result = update_wake_time(test_user.id, 23, 59)
        assert result["hour"] == 23
        assert result["minute"] == 59

        result = update_wake_time(test_user.id, 0, 0)
        assert result["hour"] == 0
        assert result["minute"] == 0

    def test_persists_and_updates(self, db_session, test_user):
        """Multiple updates should increment sample_count."""
        update_wake_time(test_user.id, 7, 0)
        update_wake_time(test_user.id, 7, 30)

        pattern = UserPattern.query.filter_by(
            user_id=test_user.id,
            pattern_type="wake_time",
            pattern_key="default",
        ).first()
        assert pattern is not None
        assert pattern.sample_count == 2

        import json
        v = json.loads(pattern.pattern_value) if isinstance(pattern.pattern_value, str) else pattern.pattern_value
        assert v["hour"] == 7
        assert v["minute"] == 30


# ===========================================================================
# get_standing_status
# ===========================================================================


class TestGetStandingStatus:
    def test_default_enabled(self, db_session, test_user):
        """No history → standing is enabled."""
        status = get_standing_status(test_user.id)
        assert status["enabled"] is True
        assert status["today_total"] == 0
        assert status["today_skipped"] == 0
        assert status["auto_stopped"] is False

    def test_with_events(self, db_session, test_user):
        """Events recorded today should be reflected."""
        today_start = datetime.combine(date.today(), time(10, 0), tzinfo=TZ)
        e1 = EventHistory(
            event_id=None, user_id=test_user.id,
            notify_type="standing", planned_time=today_start,
            skipped=False,
        )
        e2 = EventHistory(
            event_id=None, user_id=test_user.id,
            notify_type="standing",
            planned_time=today_start + timedelta(hours=1),
            skipped=True,
        )
        db_session.add_all([e1, e2])
        db_session.commit()

        status = get_standing_status(test_user.id)
        assert status["today_total"] == 2
        assert status["today_skipped"] == 1

    def test_auto_stop_after_5_consecutive_skips(self, db_session, test_user):
        """5 consecutive skips should trigger auto_stop."""
        base = datetime.combine(date.today(), time(9, 0), tzinfo=TZ)
        for i in range(5):
            e = EventHistory(
                event_id=None, user_id=test_user.id,
                notify_type="standing",
                planned_time=base + timedelta(hours=i),
                skipped=True,
            )
            db_session.add(e)
        db_session.commit()

        status = get_standing_status(test_user.id)
        assert status["auto_stopped"] is True
        assert status["enabled"] is False
        assert status["consecutive_skips"] == 5

    def test_no_auto_stop_with_interleaved_accept(self, db_session, test_user):
        """4 skips + 1 accept → should NOT auto-stop."""
        base = datetime.combine(date.today(), time(9, 0), tzinfo=TZ)
        for i in range(4):
            e = EventHistory(
                event_id=None, user_id=test_user.id,
                notify_type="standing",
                planned_time=base + timedelta(hours=i),
                skipped=True,
            )
            db_session.add(e)
        accepted = EventHistory(
            event_id=None, user_id=test_user.id,
            notify_type="standing",
            planned_time=base + timedelta(hours=4),
            skipped=False,
        )
        db_session.add(accepted)
        db_session.commit()

        status = get_standing_status(test_user.id)
        assert status["auto_stopped"] is False
        assert status["enabled"] is True

    def test_user_isolation(self, db_session, test_user, test_user2):
        """User A's standing events shouldn't affect User B's status."""
        today_start = datetime.combine(date.today(), time(10, 0), tzinfo=TZ)
        e = EventHistory(
            event_id=None, user_id=test_user.id,
            notify_type="standing", planned_time=today_start, skipped=True,
        )
        db_session.add(e)
        db_session.commit()

        status = get_standing_status(test_user2.id)
        assert status["today_total"] == 0
