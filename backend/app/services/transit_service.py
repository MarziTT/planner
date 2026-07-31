"""
Transit service — ticket OCR, route planning.

Spec: mobile_app/docs/superpowers/specs/2026-07-23-jarvis-agent-phase2-design.md §10
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from ..extensions import db
from ..models_habits import OcrCache
from .llm_gateway import chat_completion

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------


@dataclass
class ParsedTicket:
    train_number: str = ""
    departure_date: str = ""      # ISO date
    departure_time: str = ""      # HH:MM
    departure_station: str = ""
    arrival_station: str = ""
    carriage: str = ""
    seat_number: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "train_number": self.train_number,
            "departure_date": self.departure_date,
            "departure_time": self.departure_time,
            "departure_station": self.departure_station,
            "arrival_station": self.arrival_station,
            "carriage": self.carriage,
            "seat_number": self.seat_number,
        }


@dataclass
class TransitRouteLeg:
    from_station: str = ""
    to_station: str = ""
    line: str = ""               # 地铁线路，如 "1号线"
    minutes: int = 0

    def to_dict(self) -> dict[str, Any]:
        return {
            "from_station": self.from_station,
            "to_station": self.to_station,
            "line": self.line,
            "minutes": self.minutes,
        }


@dataclass
class TransitRoute:
    from_station: str = ""
    to_station: str = ""
    start_time: str = ""          # HH:MM
    end_time: str = ""            # HH:MM
    duration_minutes: int = 0
    transfer_stations: list[str] = field(default_factory=list)
    legs: list[TransitRouteLeg] = field(default_factory=list)
    total_walking_meters: int = 0

    def to_dict(self) -> dict[str, Any]:
        return {
            "from_station": self.from_station,
            "to_station": self.to_station,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration_minutes": self.duration_minutes,
            "transfer_stations": self.transfer_stations,
            "total_walking_meters": self.total_walking_meters,
            "legs": [leg.to_dict() for leg in self.legs],
        }


# ---------------------------------------------------------------------------
# OCR via OpenAI Vision
# ---------------------------------------------------------------------------

TICKET_OCR_SYSTEM_PROMPT = """You are a Chinese train ticket OCR parser. Extract the following fields from the ticket image:

1. train_number: 车次, e.g. "G1234"
2. departure_date: 出发日期 in YYYY-MM-DD format
3. departure_time: 发车时间 in HH:MM format
4. departure_station: 出发站, e.g. "深圳北"
5. arrival_station: 到达站, e.g. "长沙南"
6. carriage: 车厢号, e.g. "08"
7. seat_number: 座位号, e.g. "12A"

Return ONLY a JSON object with these fields. If a field is not visible, set it to empty string "".
Do NOT include markdown fences or any other text."""


def _build_vision_payload(image_base64: str, api_key: str, base_url: str, model: str) -> dict[str, Any]:
    """Build an OpenAI-compatible vision request payload."""
    return {
        "model": model,
        "messages": [
            {"role": "system", "content": TICKET_OCR_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_base64}",
                            "detail": "high",
                        },
                    }
                ],
            },
        ],
        "max_tokens": 512,
        "temperature": 0.0,
    }


def ocr_ticket(image_bytes: bytes, user_id: int, config: dict[str, str]) -> ParsedTicket:
    """OCR a train ticket image using OpenAI vision.

    Args:
        image_bytes: Raw image bytes.
        user_id: Requesting user ID.
        config: Flask app config dict (for API keys and model names).

    Returns:
        ParsedTicket with extracted fields.
    """
    image_hash = hashlib.sha256(image_bytes).hexdigest()

    # Check cache first
    cached = OcrCache.query.filter_by(user_id=user_id, image_hash=image_hash).first()
    if cached is not None and cached.parsed is not None:
        logger.info("OCR cache hit for hash %s", image_hash)
        return ParsedTicket(**cached.parsed)

    import base64
    image_base64 = base64.b64encode(image_bytes).decode("ascii")

    try:
        content = chat_completion(
            _build_vision_payload(image_base64, "", "", "")["messages"],
            config,
            temperature=0.0,
            max_tokens=512,
            timeout=60,
            capability="vision",
        )
        if content is None:
            raise ValueError("No OCR provider returned a response")
        # Strip markdown fences if present
        content = content.strip()
        if content.startswith("```"):
            content = re.sub(r"^```(?:json)?\s*", "", content)
            content = re.sub(r"\s*```$", "", content)

        data = json.loads(content)
        parsed = ParsedTicket(
            train_number=str(data.get("train_number", "")).strip(),
            departure_date=str(data.get("departure_date", "")).strip(),
            departure_time=str(data.get("departure_time", "")).strip(),
            departure_station=str(data.get("departure_station", "")).strip(),
            arrival_station=str(data.get("arrival_station", "")).strip(),
            carriage=str(data.get("carriage", "")).strip(),
            seat_number=str(data.get("seat_number", "")).strip(),
        )
    except json.JSONDecodeError as exc:
        logger.warning("OCR JSON parse failed; raw response: %s", content)
        parsed = ParsedTicket()
        _cache_ocr_result(user_id, image_hash, parsed, raw_text=content)
        return parsed
    except Exception as exc:
        logger.warning("OCR vision call failed: %s", exc)
        parsed = ParsedTicket()
        _cache_ocr_result(user_id, image_hash, parsed)
        return parsed

    _cache_ocr_result(user_id, image_hash, parsed, raw_text=json.dumps(parsed.to_dict(), ensure_ascii=False))
    return parsed


def _cache_ocr_result(user_id: int, image_hash: str, parsed: ParsedTicket, raw_text: str = "") -> None:
    """Write OCR result to cache table."""
    existing = OcrCache.query.filter_by(user_id=user_id, image_hash=image_hash).first()
    if existing is not None:
        existing.parsed = parsed.to_dict()
        existing.raw_text = raw_text
        existing.processed_at = datetime.now(timezone.utc)
    else:
        entry = OcrCache(
            user_id=user_id,
            image_hash=image_hash,
            raw_text=raw_text,
            parsed=parsed.to_dict(),
        )
        db.session.add(entry)
    db.session.commit()


# ---------------------------------------------------------------------------
# Route planning — static subway database (Shenzhen-centric, extensible)
# ---------------------------------------------------------------------------

# Minimal built-in subway graph for Shenzhen.
# In production this would be an external API call (e.g. AMap / 高德).
_SHENZHEN_METRO: dict[str, list[tuple[str, str, int]]] = {
    # station_name: [(next_station, line, minutes)]
    "深圳北站": [("民治", "5号线", 3), ("红山", "4号线", 4)],
    "会展中心": [("购物公园", "1号线", 2), ("岗厦", "1号线", 2), ("市民中心", "4号线", 3)],
    "车公庙": [("下沙", "9号线", 2), ("竹子林", "1号线", 3), ("香蜜湖", "1号线", 3), ("农林", "7号线", 3)],
    "购物公园": [("会展中心", "1号线", 2), ("香蜜湖", "1号线", 4)],
    "竹子林": [("车公庙", "1号线", 3), ("侨城东", "1号线", 3)],
    "侨城东": [("竹子林", "1号线", 3), ("华侨城", "1号线", 2)],
    "华侨城": [("侨城东", "1号线", 2), ("世界之窗", "1号线", 2)],
    "世界之窗": [("华侨城", "1号线", 2), ("白石洲", "1号线", 2), ("红树湾", "2号线", 4)],
    "白石洲": [("世界之窗", "1号线", 2), ("高新园", "1号线", 3)],
    "高新园": [("白石洲", "1号线", 3), ("深大", "1号线", 2)],
    "深大": [("高新园", "1号线", 2), ("桃园", "1号线", 3)],
    "桃园": [("深大", "1号线", 3), ("大新", "1号线", 2)],
    "大新": [("桃园", "1号线", 2), ("鲤鱼门", "1号线", 2)],
    "民治": [("深圳北站", "5号线", 3), ("五和", "5号线", 4)],
    "红山": [("深圳北站", "4号线", 4), ("上塘", "4号线", 2)],
    "岗厦": [("会展中心", "1号线", 2), ("华强路", "1号线", 3), ("岗厦北", "2号线", 2)],
    "市民中心": [("会展中心", "4号线", 3), ("少年宫", "4号线", 2)],
    "香蜜湖": [("购物公园", "1号线", 4), ("车公庙", "1号线", 3)],
    "下沙": [("车公庙", "9号线", 2), ("深圳湾公园", "9号线", 3)],
    "农林": [("车公庙", "7号线", 3), ("安托山", "7号线", 3)],
    "深圳湾公园": [("下沙", "9号线", 3), ("深湾", "9号线", 3)],
}

from collections import defaultdict


def _build_graph() -> tuple[
    dict[str, list[tuple[str, str, int]]],
    set[str],
]:
    """Convert station list to adjacency dict and collect all stations."""
    graph: dict[str, list[tuple[str, str, int]]] = defaultdict(list)
    for station, neighbors in _SHENZHEN_METRO.items():
        for next_station, line, minutes in neighbors:
            graph[station].append((next_station, line, minutes))
            # Ensure reverse edge exists
            if not any(n[0] == station for n in graph.get(next_station, [])):
                graph[next_station].append((station, line, minutes))
    all_stations = set(graph.keys())
    return dict(graph), all_stations


def plan_route(from_station: str, to_station: str) -> TransitRoute | None:
    """BFS-based shortest-time route planner for the built-in subway graph.

    Args:
        from_station: 出发站名
        to_station: 到达站名

    Returns:
        TransitRoute or None if no path exists.
    """
    graph, stations = _build_graph()

    from_station = from_station.strip()
    to_station = to_station.strip()

    if from_station not in stations:
        logger.warning("Station not found: %s", from_station)
        return None
    if to_station not in stations:
        logger.warning("Station not found: %s", to_station)
        return None
    if from_station == to_station:
        return TransitRoute(
            from_station=from_station,
            to_station=to_station,
            duration_minutes=0,
        )

    # BFS with time accumulation (Dijkstra-lite on unweighted small graph)
    import heapq

    # (total_minutes, station, path_legs, transfers)
    heap = [(0, from_station, [], [])]
    visited: dict[str, int] = {}  # station -> best minutes

    while heap:
        total, current, legs, transfers = heapq.heappop(heap)

        if current in visited and visited[current] <= total:
            continue
        visited[current] = total

        if current == to_station:
            transfer_set = []
            for leg in legs:
                if leg.line and (not transfer_set or transfer_set[-1] != leg.from_station):
                    if len(legs) > 0 and transfer_set:
                        pass
                if leg.line and leg.from_station not in transfer_set:
                    # Mark transfer stations: stations where line changes
                    pass
            # Compute transfer stations
            transfer_stations: list[str] = []
            prev_line = ""
            for i, leg in enumerate(legs):
                if leg.line and leg.line != prev_line and i > 0:
                    transfer_stations.append(leg.from_station)
                prev_line = leg.line

            return TransitRoute(
                from_station=from_station,
                to_station=to_station,
                duration_minutes=total,
                transfer_stations=transfer_stations,
                legs=[TransitRouteLeg(from_station=l.from_station, to_station=l.to_station, line=l.line, minutes=l.minutes) for l in legs],
            )

        for neighbor, line, mins in graph.get(current, []):
            new_total = total + mins
            if neighbor not in visited or new_total < visited[neighbor]:
                new_leg = TransitRouteLeg(from_station=current, to_station=neighbor, line=line, minutes=mins)
                heapq.heappush(heap, (new_total, neighbor, legs + [new_leg], transfers))

    return None


def search_stations(keyword: str, limit: int = 10) -> list[str]:
    """Fuzzy search station names by substring."""
    _, stations = _build_graph()
    kw = keyword.strip().lower()
    results = [s for s in stations if kw in s.lower()]
    results.sort()
    return results[:limit]
