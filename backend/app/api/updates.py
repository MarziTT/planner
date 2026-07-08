from __future__ import annotations

import json
from pathlib import Path

from flask import Blueprint, current_app

from .common import success


updates_bp = Blueprint("updates", __name__)


def _load_manifest() -> dict:
    manifest_path = Path(current_app.config["UPDATE_MANIFEST_PATH"])
    if manifest_path.exists():
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    return {
        "resources": [],
        "latestVersion": current_app.config["APP_VERSION"],
        "buildNumber": current_app.config["APP_BUILD"],
    }


@updates_bp.get("/version")
def get_version():
    manifest = _load_manifest()
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
    return success(_load_manifest())
