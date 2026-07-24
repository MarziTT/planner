"""Scene check API — P6 scene linkage.

GET /scene/check  →  returns proactive scene cards for current user state.
"""

from __future__ import annotations

from flask import Blueprint, g, request

from ..api.common import auth_required, success
from ..services.scene_engine import check_scenes

scene_bp = Blueprint("scene", __name__)


@scene_bp.route("/scene/check", methods=["GET"])
@auth_required
def check():
    """Return active scene cards for the authenticated user.

    Optional query param:
        weather: str — current weather description text
    """
    weather = request.args.get("weather", "").strip() or None

    cards = check_scenes(user_id=g.user_id, weather_text=weather)

    return success({"cards": cards})
