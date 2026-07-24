"""
Transit API — Jarvis Agent Phase 2 endpoints.

POST /api/v1/transit/ocr         — OCR a train ticket image
POST /api/v1/transit/route       — plan a subway route
GET  /api/v1/transit/stations    — search station names

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §6
"""

from __future__ import annotations

from flask import Blueprint, current_app, g, request

from .common import auth_required, failure, success
from ..services.transit_service import ocr_ticket, plan_route, search_stations

transit_bp = Blueprint("transit", __name__)


# ---------------------------------------------------------------------------
#  POST /api/v1/transit/ocr
# ---------------------------------------------------------------------------

@transit_bp.post("/transit/ocr")
@auth_required
def ocr_ticket_endpoint():
    """Receive a train ticket image and return structured OCR result.

    Accepts multipart/form-data with field 'image' (the image file).
    Returns ParsedTicket JSON.
    """
    user_id = g.current_user.id

    if "image" not in request.files:
        return failure("validation_error", "No image file provided", status=422)

    image_file = request.files["image"]
    if image_file.filename == "" or image_file.filename is None:
        return failure("validation_error", "Empty image file", status=422)

    image_bytes = image_file.read()
    if len(image_bytes) == 0:
        return failure("validation_error", "Image file is empty", status=422)

    # Rough size guard: 10 MB max
    if len(image_bytes) > 10 * 1024 * 1024:
        return failure("validation_error", "Image too large (max 10 MB)", status=413)

    config = current_app.config
    parsed = ocr_ticket(image_bytes, user_id, config)

    return success(parsed.to_dict())


# ---------------------------------------------------------------------------
#  POST /api/v1/transit/route
# ---------------------------------------------------------------------------

@transit_bp.post("/transit/route")
@auth_required
def plan_route_endpoint():
    """Plan a subway route between two stations.

    Request JSON: {"from_station": "...", "to_station": "..."}
    Returns TransitRoute JSON or None if not found.
    """
    payload = request.get_json(silent=True) or {}
    from_station = (payload.get("from_station") or "").strip()
    to_station = (payload.get("to_station") or "").strip()

    if not from_station or not to_station:
        return failure("validation_error", "from_station and to_station are required", status=422)

    route = plan_route(from_station, to_station)
    if route is None:
        return failure(
            "not_found",
            "No route found between these stations. "
            f"Check station names: '{from_station}' → '{to_station}'",
            status=404,
        )

    return success(route.to_dict())


# ---------------------------------------------------------------------------
#  GET /api/v1/transit/stations
# ---------------------------------------------------------------------------

@transit_bp.get("/transit/stations")
@auth_required
def search_stations_endpoint():
    """Search subway stations by keyword.

    Query params: ?q=<keyword>&limit=10
    """
    keyword = request.args.get("q", "").strip()
    if not keyword:
        return failure("validation_error", "Query parameter 'q' is required", status=422)

    try:
        limit = int(request.args.get("limit", 10))
        limit = max(1, min(limit, 50))
    except (ValueError, TypeError):
        limit = 10

    results = search_stations(keyword, limit=limit)
    return success({"stations": results, "count": len(results)})
