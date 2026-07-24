"""Shared fixtures and helpers for backend tests."""

from pathlib import Path
import sys

import pytest
from app import create_app
from app.extensions import db
from app.models import User

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))


@pytest.fixture
def app_client():
    """Create a Flask app and test client with clean DB tables."""
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    return app, app.test_client()


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

