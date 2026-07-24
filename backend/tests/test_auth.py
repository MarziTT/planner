"""Test auth endpoints using phone-login flow with backdoor credentials."""

from app import create_app
from app.extensions import db


def test_phone_login_new_user(app_client):
    """Phone-login with backdoor code creates a new user (status 201)."""
    app, client = app_client
    try:
        login_response = client.post(
            "/api/v1/auth/phone-login",
            json={
                "phone": "13800000001",
                "code": "888888",
            },
        )
        assert login_response.status_code == 201
        payload = login_response.get_json()
        assert payload["ok"] is True
        assert payload["data"]["tokens"]["accessToken"]
        assert payload["data"]["isNewUser"] is True
    finally:
        with app.app_context():
            db.drop_all()


def test_phone_login_existing_user(app_client):
    """Phone-login for an existing user returns status 200."""
    app, client = app_client
    try:
        # Create user
        client.post(
            "/api/v1/auth/phone-login",
            json={"phone": "13800000001", "code": "888888"},
        )
        # Login again — should be existing user
        login2 = client.post(
            "/api/v1/auth/phone-login",
            json={"phone": "13800000001", "code": "888888"},
        )
        assert login2.status_code == 200
        payload = login2.get_json()
        assert payload["data"]["isNewUser"] is False
    finally:
        with app.app_context():
            db.drop_all()


def test_profile_update_marks_onboarding_complete(app_client):
    """Updating profile sets onboardingDone = True."""
    app, client = app_client
    try:
        # Login to get access token
        login_response = client.post(
            "/api/v1/auth/phone-login",
            json={"phone": "13800000001", "code": "888888"},
        )
        login_payload = login_response.get_json()["data"]
        headers = {
            "Authorization": f"Bearer {login_payload['tokens']['accessToken']}"
        }

        # Update profile
        profile_response = client.put(
            "/api/v1/profile",
            headers=headers,
            json={
                "city": "Shanghai",
                "bio": "Focus mode",
                "fitnessGoal": "Consistency",
            },
        )
        assert profile_response.status_code == 200

        # Re-login and verify onboardingDone
        login2 = client.post(
            "/api/v1/auth/phone-login",
            json={"phone": "13800000001", "code": "888888"},
        )
        payload2 = login2.get_json()["data"]
        assert login2.status_code == 200
        assert payload2["user"]["onboardingDone"] is True
    finally:
        with app.app_context():
            db.drop_all()


def test_send_code_valid_phone(app_client):
    """POST /auth/send-code with a valid phone returns 200."""
    app, client = app_client
    try:
        response = client.post(
            "/api/v1/auth/send-code",
            json={"phone": "13812345678"},
        )
        assert response.status_code == 200
        payload = response.get_json()
        assert payload["ok"] is True
        assert "message" in payload["data"]
    finally:
        with app.app_context():
            db.drop_all()


def test_send_code_invalid_phone(app_client):
    """POST /auth/send-code with an invalid phone returns 400."""
    app, client = app_client
    try:
        response = client.post(
            "/api/v1/auth/send-code",
            json={"phone": "12345"},
        )
        assert response.status_code == 400
        payload = response.get_json()
        assert payload["ok"] is False
    finally:
        with app.app_context():
            db.drop_all()
