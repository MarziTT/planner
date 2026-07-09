from app import create_app
from app.extensions import db


def make_client():
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    return app, app.test_client()


def test_register_and_login():
    app, client = make_client()
    try:
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "demo@pixelplanner.app",
                "password": "12345678",
                "nickname": "Demo",
            },
        )
        assert register_response.status_code == 201
        assert register_response.get_json()["ok"] is True

        login_response = client.post(
            "/api/v1/auth/login",
            json={"email": "demo@pixelplanner.app", "password": "12345678"},
        )
        login_payload = login_response.get_json()
        assert login_response.status_code == 200
        assert login_payload["data"]["tokens"]["accessToken"]
    finally:
        with app.app_context():
            db.drop_all()


def test_profile_update_marks_onboarding_complete():
    app, client = make_client()
    try:
        register_response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "profile@pixelplanner.app",
                "password": "12345678",
                "nickname": "Profile",
            },
        )
        register_payload = register_response.get_json()["data"]
        headers = {"Authorization": f"Bearer {register_payload['tokens']['accessToken']}"}

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

        login_response = client.post(
            "/api/v1/auth/login",
            json={"email": "profile@pixelplanner.app", "password": "12345678"},
        )
        login_payload = login_response.get_json()["data"]

        assert login_response.status_code == 200
        assert login_payload["user"]["onboardingDone"] is True
    finally:
        with app.app_context():
            db.drop_all()
