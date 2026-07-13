from __future__ import annotations

import json
from pathlib import Path

from flask import Blueprint, abort, current_app, send_from_directory, url_for

from .common import success


updates_bp = Blueprint("updates", __name__)

_ALLOWED_RESOURCE_FILES = {
    "zzz.transform": "zzz-transform.gif",
    "zzz.shield": "zzz-shield.gif",
    "zzz.equipment": "zzz-equipment.gif",
    "zzz.flight": "zzz-flight.gif",
    "zzz.rain": "zzz-rain.gif",
}


def _load_manifest() -> dict:
    manifest_path = Path(current_app.config["UPDATE_MANIFEST_PATH"])
    if manifest_path.exists():
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    return {
        "resources": [],
        "latestVersion": current_app.config["APP_VERSION"],
        "buildNumber": current_app.config["APP_BUILD"],
    }


def _build_public_resource(item: dict) -> dict | None:
    resource_id = item.get("id")
    if not isinstance(resource_id, str):
        return None

    filename = _ALLOWED_RESOURCE_FILES.get(resource_id)
    if filename is None or item.get("filename") != filename:
        return None

    version = item.get("version")
    sha256 = item.get("sha256")
    if not isinstance(version, str) or not version:
        return None
    if not isinstance(sha256, str) or not sha256:
        return None

    return {
        "id": resource_id,
        "version": version,
        "sha256": sha256,
        "contentType": item.get("contentType", "image/gif"),
        "url": url_for("updates.get_resource", filename=filename),
    }


def _public_manifest() -> dict:
    manifest = _load_manifest()
    public_resources = []
    for item in manifest.get("resources", []):
        if isinstance(item, dict):
            resource = _build_public_resource(item)
            if resource is not None:
                public_resources.append(resource)

    manifest["resources"] = public_resources
    return manifest


@updates_bp.get("/version")
def get_version():
    manifest = _public_manifest()
    return success(
        {
            "latestVersion": manifest.get("latestVersion", current_app.config["APP_VERSION"]),
            "buildNumber": manifest.get("buildNumber", current_app.config["APP_BUILD"]),
            "required": manifest.get("required", False),
            "downloadUrl": manifest.get("downloadUrl") or current_app.config["APP_DOWNLOAD_URL"],
            "releaseNotes": manifest.get("releaseNotes", []),
        }
    )


@updates_bp.get("/update-manifest")
def get_update_manifest():
    return success(_public_manifest())


@updates_bp.get("/resources/<path:filename>")
def get_resource(filename: str):
    if filename not in _ALLOWED_RESOURCE_FILES.values():
        abort(404)

    manifest = _public_manifest()
    declared_files = {
        _ALLOWED_RESOURCE_FILES[item["id"]]
        for item in manifest.get("resources", [])
        if item.get("id") in _ALLOWED_RESOURCE_FILES
    }
    if filename not in declared_files:
        abort(404)

    resource_dir = Path(current_app.config["UPDATE_RESOURCE_DIR"])
    resource_path = resource_dir / filename
    if not resource_path.is_file():
        abort(404)

    return send_from_directory(
        resource_dir,
        filename,
        mimetype="image/gif",
    )
