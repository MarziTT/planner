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
