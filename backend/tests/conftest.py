"""Shared fixtures and helpers for backend tests."""

from datetime import datetime, timezone
from pathlib import Path
import sys

import pytest

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app import create_app
from app.extensions import db
from app.models import User
from app.services.time_service import Clock, SHANGHAI_TZ


FIXED_LOCAL_NOW = datetime(2026, 7, 29, 10, 0, tzinfo=SHANGHAI_TZ)


class FixedClock(Clock):
    def __init__(self, now: datetime):
        self._now = now

    def now_utc(self) -> datetime:
        return self._now.astimezone(timezone.utc)

    def now_local(self) -> datetime:
        return self._now


@pytest.fixture
def app_client():
    """Create a Flask app and test client with clean DB tables."""
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    return app, app.test_client()


@pytest.fixture
def fixed_clock(app_client):
    """Install a stable local clock for time-sensitive tests."""
    app, _ = app_client
    clock = FixedClock(FIXED_LOCAL_NOW)
    app.extensions["clock"] = clock
    return clock


@pytest.fixture
def fixed_now(fixed_clock):
    return fixed_clock.now_local()


@pytest.fixture
def fixed_today(fixed_clock):
    return fixed_clock.now_local().date()


@pytest.fixture
def auth_headers(app_client):
    """Login via backdoor phone and return Authorization headers."""
    _, client = app_client
    resp = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": "13800000001", "code": "888888"},
    )
    data = resp.get_json()
    token = data["data"]["tokens"]["accessToken"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def db_session(app_client):
    """Yield a database session with tables created, then rollback."""
    app, _ = app_client
    with app.app_context():
        yield db.session
        db.session.rollback()


@pytest.fixture
def test_user(app_client, db_session):
    """Create and return a test user bound to db_session."""
    user = User(phone="13800000001", nickname="TestUser")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def test_user2(app_client, db_session):
    """Create and return a second test user (for isolation tests)."""
    user = User(phone="13800000002", nickname="TestUser2")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user
