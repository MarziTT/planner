"""Test planner endpoints for create, update, list, export and tag-import."""

from app.extensions import db
from app.models_habits import MemoryFeedback, UserMemory


def _register_and_login(client):
    response = client.post(
        "/api/v1/auth/phone-login",
        json={"phone": "13800000001", "code": "888888"},
    )
    payload = response.get_json()["data"]
    return {"Authorization": f"Bearer {payload['tokens']['accessToken']}"}


def test_create_and_list_event_and_todo(app_client):
    app, client = app_client
    try:
        headers = _register_and_login(client)

        event_response = client.post(
            "/api/v1/events",
            headers=headers,
            json={
                "title": "晨间训练",
                "startsAt": "2026-07-07T07:00:00",
                "endsAt": "2026-07-07T08:00:00",
                "status": "planned",
            },
        )
        assert event_response.status_code == 201
        event_id = event_response.get_json()["data"]["item"]["id"]

        todo_response = client.post(
            "/api/v1/todos",
            headers=headers,
            json={"title": "补充蛋白粉", "completed": False},
        )
        assert todo_response.status_code == 201
        todo_id = todo_response.get_json()["data"]["item"]["id"]

        update_event = client.put(
            f"/api/v1/events/{event_id}",
            headers=headers,
            json={"title": "晨间力量训练", "startsAt": "2026-07-07T07:00:00", "endsAt": "2026-07-07T08:00:00", "status": "planned"},
        )
        update_todo = client.put(
            f"/api/v1/todos/{todo_id}",
            headers=headers,
            json={"title": "补充蛋白粉", "completed": True},
        )

        events_list = client.get("/api/v1/events?status=planned", headers=headers)
        todos_list = client.get("/api/v1/todos?completed=true", headers=headers)
        stats = client.get("/api/v1/stats", headers=headers)

        assert update_event.status_code == 200
        assert update_todo.status_code == 200
        assert events_list.status_code == 200
        assert len(events_list.get_json()["data"]["items"]) == 1
        assert events_list.get_json()["data"]["items"][0]["title"] == "晨间力量训练"
        assert todos_list.status_code == 200
        assert len(todos_list.get_json()["data"]["items"]) == 1
        assert stats.get_json()["data"]["eventsTotal"] == 1
    finally:
        with app.app_context():
            db.drop_all()


def test_tags_export_and_import_snapshot(app_client):
    app, client = app_client
    try:
        headers = _register_and_login(client)
        tag_response = client.post(
            "/api/v1/tags",
            headers=headers,
            json={"name": "健身", "color": "#22C55E"},
        )
        assert tag_response.status_code == 201
        tag_id = tag_response.get_json()["data"]["item"]["id"]

        update_tag = client.put(
            f"/api/v1/tags/{tag_id}",
            headers=headers,
            json={"name": "训练", "color": "#16A34A"},
        )
        assert update_tag.status_code == 200

        import_response = client.post(
            "/api/v1/import",
            headers=headers,
            json={
                "events": [
                    {
                        "title": "夜间拉伸",
                        "startsAt": "2026-07-07T21:00:00",
                        "endsAt": "2026-07-07T21:30:00"
                    }
                ],
                "todos": [
                    {"title": "准备明天衣服"}
                ],
                "tags": [
                    {"name": "恢复", "color": "#0EA5E9"}
                ]
            },
        )
        assert import_response.status_code == 201

        export_response = client.get("/api/v1/export", headers=headers)
        payload = export_response.get_json()["data"]
        delete_tag = client.delete(f"/api/v1/tags/{tag_id}", headers=headers)
        assert delete_tag.status_code == 200
        assert export_response.status_code == 200
        assert len(payload["events"]) == 1
        assert len(payload["todos"]) == 1
        assert len(payload["tags"]) == 2
    finally:
        with app.app_context():
            db.drop_all()


def test_event_actions_feed_controlled_personal_memory(app_client):
    app, client = app_client
    try:
        headers = _register_and_login(client)
        created = client.post(
            "/api/v1/events",
            headers=headers,
            json={
                "title": "晚间健身",
                "startsAt": "2026-08-07T19:00:00",
                "endsAt": "2026-08-07T20:00:00",
            },
        )
        event_id = created.get_json()["data"]["item"]["id"]

        modified = client.put(
            f"/api/v1/events/{event_id}",
            headers=headers,
            json={
                "startsAt": "2026-08-07T20:00:00",
                "endsAt": "2026-08-07T21:30:00",
            },
        )
        assert modified.status_code == 200

        with app.app_context():
            memory = UserMemory.query.filter_by(category="schedule").one()
            assert memory.value["hour"] == 20
            assert memory.value["duration_minutes"] == 90
            assert memory.evidence_count == 2
            assert [row.action for row in MemoryFeedback.query.order_by(MemoryFeedback.id).all()] == [
                "confirmed", "modified",
            ]

        deleted = client.delete(f"/api/v1/events/{event_id}", headers=headers)
        assert deleted.status_code == 200
        with app.app_context():
            assert MemoryFeedback.query.order_by(MemoryFeedback.id.desc()).first().action == "cancelled"
            assert UserMemory.query.filter_by(category="schedule").one().evidence_count == 2
    finally:
        with app.app_context():
            db.drop_all()
