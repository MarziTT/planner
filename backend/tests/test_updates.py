import hashlib
import json

from app import create_app


def test_update_manifest_exposes_allowlisted_resource_download(tmp_path):
    resource_bytes = b'zzz-resource-bytes'
    resource_path = tmp_path / 'zzz-transform.gif'
    resource_path.write_bytes(resource_bytes)
    manifest_path = tmp_path / 'manifest.json'
    manifest_path.write_text(
        json.dumps(
            {
                'latestVersion': '5.0.0',
                'buildNumber': '50000',
                'resources': [
                    {
                        'id': 'zzz.transform',
                        'version': '2026.07.10.1',
                        'filename': 'zzz-transform.gif',
                        'sha256': hashlib.sha256(resource_bytes).hexdigest(),
                        'contentType': 'image/gif',
                    }
                ],
            }
        ),
        encoding='utf-8',
    )
    app = create_app('testing')
    app.config.update(
        UPDATE_MANIFEST_PATH=str(manifest_path),
        UPDATE_RESOURCE_DIR=str(tmp_path),
    )
    client = app.test_client()

    manifest_response = client.get('/api/v1/app/update-manifest')
    payload = manifest_response.get_json()

    assert manifest_response.status_code == 200
    resource = payload['data']['resources'][0]
    assert resource['id'] == 'zzz.transform'
    assert resource['url'].endswith('/api/v1/app/resources/zzz-transform.gif')
    assert resource['sha256'] == hashlib.sha256(resource_bytes).hexdigest()

    resource_response = client.get('/api/v1/app/resources/zzz-transform.gif')

    assert resource_response.status_code == 200
    assert resource_response.data == resource_bytes
    assert resource_response.mimetype == 'image/gif'


def test_resource_endpoint_rejects_undeclared_file(tmp_path):
    manifest_path = tmp_path / 'manifest.json'
    manifest_path.write_text(json.dumps({'resources': []}), encoding='utf-8')
    (tmp_path / 'private.gif').write_bytes(b'not declared')
    app = create_app('testing')
    app.config.update(
        UPDATE_MANIFEST_PATH=str(manifest_path),
        UPDATE_RESOURCE_DIR=str(tmp_path),
    )

    response = app.test_client().get('/api/v1/app/resources/private.gif')

    assert response.status_code == 404
