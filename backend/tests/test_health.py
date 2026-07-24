from app import create_app


def test_healthcheck():
    app = create_app("testing")
    client = app.test_client()

    response = client.get("/healthz")
    payload = response.get_json()

    assert response.status_code == 200
    assert payload["ok"] is True
    assert payload["data"]["status"] == "healthy"
