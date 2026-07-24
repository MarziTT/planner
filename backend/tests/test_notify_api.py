"""
Tests for P3-F3 smart notification API.

GET  /api/v1/notify/insights
GET  /api/v1/notify/history
"""


# ---------------------------------------------------------------------------
#  notify/insights
# ---------------------------------------------------------------------------

def test_insights_unauthenticated(app_client):
    """GET /notify/insights without token → 401."""
    _, client = app_client
    resp = client.get("/api/v1/notify/insights")
    assert resp.status_code == 401


def test_insights_returns_ok(app_client, auth_headers):
    """GET /notify/insights with valid token → 200 with insights list."""
    _, client = app_client
    resp = client.get("/api/v1/notify/insights", headers=auth_headers)
    assert resp.status_code == 200

    data = resp.get_json()
    assert data["ok"] is True
    assert "data" in data
    assert "insights" in data["data"]
    assert isinstance(data["data"]["insights"], list)
    assert "count" in data["data"]


# ---------------------------------------------------------------------------
#  notify/history
# ---------------------------------------------------------------------------

def test_history_unauthenticated(app_client):
    """GET /notify/history without token → 401."""
    _, client = app_client
    resp = client.get("/api/v1/notify/history")
    assert resp.status_code == 401


def test_history_returns_ok(app_client, auth_headers):
    """GET /notify/history with valid token → 200 with entries list."""
    _, client = app_client
    resp = client.get("/api/v1/notify/history", headers=auth_headers)
    assert resp.status_code == 200

    data = resp.get_json()
    assert data["ok"] is True
    assert "data" in data
    assert "entries" in data["data"]
    assert isinstance(data["data"]["entries"], list)
    assert "total" in data["data"]
    assert "skipped" in data["data"]
    assert "completed" in data["data"]


def test_history_with_type_filter(app_client, auth_headers):
    """GET /notify/history?notify_type=standing filters correctly."""
    _, client = app_client
    resp = client.get(
        "/api/v1/notify/history?notify_type=standing&days=1&limit=10",
        headers=auth_headers,
    )
    assert resp.status_code == 200

    data = resp.get_json()
    assert data["ok"] is True
    for entry in data["data"]["entries"]:
        assert entry["notify_type"] == "standing"


def test_history_respects_limit(app_client, auth_headers):
    """GET /notify/history?limit=3 returns at most 3 entries."""
    _, client = app_client
    resp = client.get(
        "/api/v1/notify/history?limit=3",
        headers=auth_headers,
    )
    assert resp.status_code == 200

    data = resp.get_json()
    assert len(data["data"]["entries"]) <= 3


def test_history_clamps_days(app_client, auth_headers):
    """GET /notify/history?days=999 → clamped to 30."""
    _, client = app_client
    resp = client.get(
        "/api/v1/notify/history?days=999",
        headers=auth_headers,
    )
    assert resp.status_code == 200
