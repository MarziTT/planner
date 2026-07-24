"""Tests for transit_service.py — route planning, station search, dataclass serialisation.

route-planning and station search are pure-logic functions (no DB), so these
tests run with zero fixtures.

Note: The built-in _SHENZHEN_METRO graph is sparse and partially disconnected.
Tests only use station pairs that are actually connected.
"""

from __future__ import annotations

import pytest
from app.services.transit_service import (
    ParsedTicket,
    TransitRoute,
    TransitRouteLeg,
    _build_graph,
    plan_route,
    search_stations,
)


# ===========================================================================
# Dataclass serialisation
# ===========================================================================


class TestParsedTicket:
    def test_to_dict_empty(self):
        t = ParsedTicket()
        d = t.to_dict()
        assert d["train_number"] == ""
        assert d["departure_station"] == ""

    def test_to_dict_populated(self):
        t = ParsedTicket(
            train_number="G1234",
            departure_date="2026-07-24",
            departure_time="14:30",
            departure_station="\u6df1\u5733\u5317",
            arrival_station="\u957f\u6c99\u5357",
            carriage="08",
            seat_number="12A",
        )
        d = t.to_dict()
        assert d["train_number"] == "G1234"
        assert d["departure_station"] == "\u6df1\u5733\u5317"
        assert d["arrival_station"] == "\u957f\u6c99\u5357"
        assert d["carriage"] == "08"


class TestTransitRouteLeg:
    def test_to_dict(self):
        leg = TransitRouteLeg(
            from_station="\u6df1\u5733\u5317\u7ad9",
            to_station="\u6c11\u6cbb",
            line="5\u53f7\u7ebf",
            minutes=3,
        )
        d = leg.to_dict()
        assert d["from_station"] == "\u6df1\u5733\u5317\u7ad9"
        assert d["line"] == "5\u53f7\u7ebf"
        assert d["minutes"] == 3


class TestTransitRoute:
    def test_to_dict_basic(self):
        route = TransitRoute(
            from_station="\u4e16\u754c\u4e4b\u7a97",
            to_station="\u4fa8\u57ce\u4e1c",
            duration_minutes=10,
            legs=[
                TransitRouteLeg(
                    from_station="\u4e16\u754c\u4e4b\u7a97",
                    to_station="\u534e\u4fa8\u57ce",
                    line="1\u53f7\u7ebf", minutes=2,
                ),
                TransitRouteLeg(
                    from_station="\u534e\u4fa8\u57ce",
                    to_station="\u4fa8\u57ce\u4e1c",
                    line="1\u53f7\u7ebf", minutes=2,
                ),
            ],
        )
        d = route.to_dict()
        assert len(d["legs"]) == 2


# ===========================================================================
# _build_graph — internal graph construction
# ===========================================================================


class TestBuildGraph:
    def test_graph_is_non_empty(self):
        graph, stations = _build_graph()
        assert len(stations) > 0
        assert "\u6df1\u5733\u5317\u7ad9" in stations
        assert "\u4e16\u754c\u4e4b\u7a97" in stations

    def test_graph_is_bidirectional(self):
        graph, _ = _build_graph()
        shenzhen_neighbors = [n[0] for n in graph.get("\u6df1\u5733\u5317\u7ad9", [])]
        assert "\u6c11\u6cbb" in shenzhen_neighbors

        minzhi_neighbors = [n[0] for n in graph.get("\u6c11\u6cbb", [])]
        assert "\u6df1\u5733\u5317\u7ad9" in minzhi_neighbors


# ===========================================================================
# plan_route — BFS shortest-path routing
# ===========================================================================


class TestPlanRoute:
    def test_direct_route(self):
        """Two adjacent stations -> direct route, no transfer."""
        route = plan_route("\u6df1\u5733\u5317\u7ad9", "\u6c11\u6cbb")
        assert route is not None
        assert route.duration_minutes > 0
        assert len(route.legs) >= 1

    def test_multi_hop_same_line(self):
        """Multiple stops on the same line -> multi-leg route."""
        route = plan_route("\u9ad8\u65b0\u56ed", "\u4e16\u754c\u4e4b\u7a97")
        # 高新园 -> 白石洲(1号线,3) -> 世界之窗(1号线,2)
        assert route is not None
        assert route.duration_minutes > 0
        assert len(route.legs) >= 2

    def test_same_station(self):
        route = plan_route("\u4e16\u754c\u4e4b\u7a97", "\u4e16\u754c\u4e4b\u7a97")
        assert route is not None
        assert route.duration_minutes == 0

    def test_station_not_found_from(self):
        route = plan_route("\u4e0d\u5b58\u5728\u7684\u7ad9", "\u4e16\u754c\u4e4b\u7a97")
        assert route is None

    def test_station_not_found_to(self):
        route = plan_route("\u4e16\u754c\u4e4b\u7a97", "\u706b\u661f\u7ad9")
        assert route is None

    def test_route_fields_populated(self):
        route = plan_route("\u6df1\u5733\u5317\u7ad9", "\u6c11\u6cbb")
        assert route is not None
        assert route.from_station == "\u6df1\u5733\u5317\u7ad9"
        assert route.to_station == "\u6c11\u6cbb"
        assert isinstance(route.duration_minutes, int)
        assert route.duration_minutes > 0
        for leg in route.legs:
            assert isinstance(leg.from_station, str)
            assert isinstance(leg.to_station, str)
            assert isinstance(leg.line, str)
            assert isinstance(leg.minutes, int)
            assert leg.minutes > 0

    def test_disconnected_graph_returns_none(self):
        """Stations in disconnected graph components -> None."""
        # 深圳北站 (north) and 世界之窗 (south) are disconnected
        route = plan_route("\u6df1\u5733\u5317\u7ad9", "\u4e16\u754c\u4e4b\u7a97")
        assert route is None

    def test_strip_whitespace(self):
        route = plan_route("  \u6df1\u5733\u5317\u7ad9  ", " \u6c11\u6cbb ")
        assert route is not None


# ===========================================================================
# search_stations — fuzzy substring search
# ===========================================================================


class TestSearchStations:
    def test_exact_match(self):
        results = search_stations("\u6df1\u5733\u5317\u7ad9")
        assert "\u6df1\u5733\u5317\u7ad9" in results

    def test_partial_match(self):
        results = search_stations("\u6df1\u5733")
        assert len(results) >= 2

    def test_no_match(self):
        results = search_stations("xyz\u4e0d\u5b58\u5728")
        assert results == []

    def test_limit(self):
        results = search_stations("\u6df1\u5733", limit=1)
        assert len(results) <= 1

    def test_results_sorted(self):
        results = search_stations("\u6df1\u5733")
        assert results == sorted(results)
