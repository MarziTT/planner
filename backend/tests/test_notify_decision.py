from datetime import datetime, timedelta

from app.extensions import db
from app.models_habits import EventHistory
from app.services.smart_notify_service import _is_suppressed


def test_snoozed_insight_is_suppressed_until_planned_time(app_client):
    app, client = app_client
    client.post("/api/v1/auth/phone-login", json={"phone": "13800000001", "code": "888888"})
    now = datetime(2026, 7, 31, 10, 0)
    with app.app_context():
        from app.models import User
        user = User.query.filter_by(phone="13800000001").first()
        assert user is not None
        db.session.add(EventHistory(
            user_id=user.id,
            notify_type="insight:abc",
            planned_time=now + timedelta(minutes=30),
            reminded_at=now,
            delayed_count=1,
        ))
        db.session.commit()
        assert _is_suppressed(user.id, "abc", now) is True
        assert _is_suppressed(user.id, "abc", now + timedelta(minutes=31)) is False
