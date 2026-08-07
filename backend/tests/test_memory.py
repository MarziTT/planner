from app.extensions import db


def test_memory_api_is_user_controlled(app_client, auth_headers):
    app, client = app_client
    try:
        initial = client.get('/api/v1/memories', headers=auth_headers)
        assert initial.status_code == 200
        assert initial.get_json()['data'] == {
            'learningEnabled': True,
            'items': [],
        }

        created = client.post(
            '/api/v1/memories',
            headers=auth_headers,
            json={
                'category': 'preference',
                'key': 'reply-style',
                'summary': '用户偏好简短直接的回答',
            },
        )
        assert created.status_code == 201
        memory_id = created.get_json()['data']['item']['id']

        disabled = client.put(
            '/api/v1/memories/settings',
            headers=auth_headers,
            json={'learningEnabled': False},
        )
        assert disabled.get_json()['data']['learningEnabled'] is False

        paused = client.put(
            f'/api/v1/memories/{memory_id}',
            headers=auth_headers,
            json={'active': False},
        )
        assert paused.get_json()['data']['item']['active'] is False

        cleared = client.delete('/api/v1/memories', headers=auth_headers)
        assert cleared.status_code == 200
        final = client.get('/api/v1/memories', headers=auth_headers).get_json()['data']
        assert final['learningEnabled'] is False
        assert final['items'] == []
    finally:
        with app.app_context():
            db.drop_all()


def test_memory_api_requires_authentication(app_client):
    _, client = app_client
    assert client.get('/api/v1/memories').status_code == 401
    assert client.delete('/api/v1/memories').status_code == 401
