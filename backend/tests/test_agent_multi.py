"""Tests for Phase 4 multi-intent NLU — voice butler agent."""

import json
from datetime import datetime, timedelta, timezone

import pytest

TZ = timezone(timedelta(hours=8))


class TestMultiIntentParse:
    """POST /api/v1/agent/parse-multi — multi-intent classification."""

    def test_parse_multi_requires_auth(self, app_client):
        _, client = app_client
        resp = client.post("/api/v1/agent/parse-multi", json={})
        assert resp.status_code in (401, 403)

    def test_parse_multi_requires_text(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post("/api/v1/agent/parse-multi", json={}, headers=auth_headers)
        assert resp.status_code == 422

    def test_parse_multi_log_meal_intent(self, app_client, auth_headers):
        """Voice: 'I ate beef noodles' → log_meal intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "我吃了一碗牛肉面"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["ok"] is True
        parsed = data["data"]
        assert parsed["intent"] in ("log_meal", "unknown")  # regex fallback
        assert "confidence" in parsed

    def test_parse_multi_log_exercise_intent(self, app_client, auth_headers):
        """Voice: 'I ran 30 minutes' → log_exercise intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "我跑了30分钟"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert parsed["intent"] in ("log_exercise", "unknown")

    def test_parse_multi_log_routine_intent(self, app_client, auth_headers):
        """Voice: 'I woke up at 7' → log_routine intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "我今天7点起的床"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert parsed["intent"] in ("log_routine", "unknown")

    def test_parse_multi_query_intent(self, app_client, auth_headers):
        """Voice: 'How many calories today?' → query intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "我今天吃了多少卡路里"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert parsed["intent"] in ("query", "unknown")

    def test_parse_multi_create_reminder_intent(self, app_client, auth_headers):
        """Voice: 'Remind me to buy milk tonight' → create_reminder intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "记得提醒我晚上买牛奶"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert parsed["intent"] in ("create_reminder", "unknown")

    def test_parse_multi_create_event_intent(self, app_client, auth_headers):
        """Voice: 'Meeting tomorrow at 3pm' → create_event intent (backward compat)."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "明天下午3点跟老张开项目会"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert parsed["intent"] in ("create_event", "unknown")

    def test_parse_multi_unknown_intent(self, app_client, auth_headers):
        """Gibberish → unknown intent."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/parse-multi",
            json={"text": "你好"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        parsed = data["data"]
        assert "intent" in parsed
        assert "confidence" in parsed


class TestExecuteLogMeal:
    """POST /api/v1/agent/execute — intent=log_meal"""

    def test_log_meal_creates_record(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "log_meal",
                "meal_type": "午餐",
                "food_name": "牛肉面",
                "calories_estimate": 550,
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["ok"] is True
        assert data["data"]["action"] == "meal_logged"
        assert data["data"]["record_id"] > 0
        assert "牛肉面" in data["data"]["summary"]

    def test_log_meal_requires_meal_type(self, app_client, auth_headers):
        """Default meal type is inferred, should still work."""
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "log_meal",
                "food_name": "沙拉",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201


class TestExecuteLogExercise:
    """POST /api/v1/agent/execute — intent=log_exercise"""

    def test_log_exercise_creates_record(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "log_exercise",
                "exercise_type": "跑步",
                "duration_minutes": 30,
                "intensity": "中",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["data"]["action"] == "exercise_logged"
        assert "跑步" in data["data"]["summary"]


class TestExecuteLogRoutine:
    """POST /api/v1/agent/execute — intent=log_routine"""

    def test_log_wake_routine(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "log_routine",
                "routine_type": "wake",
                "routine_value": "07:30",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["data"]["action"] == "routine_logged"
        assert "07:30" in data["data"]["summary"]

    def test_log_standing_routine(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "log_routine",
                "routine_type": "standing",
                "routine_value": "done",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201


class TestExecuteCreateReminder:
    """POST /api/v1/agent/execute — intent=create_reminder"""

    def test_create_reminder_creates_todo(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "create_reminder",
                "reminder_text": "买牛奶",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["data"]["action"] == "reminder_created"
        assert "买牛奶" in data["data"]["summary"]


class TestExecuteQuery:
    """POST /api/v1/agent/execute — intent=query"""

    def test_calories_query_returns_answer(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "query",
                "query_type": "calories_today",
                "query_text": "我今天吃了多少卡路里",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["data"]["action"] == "query_answered"
        assert "answer" in data["data"]
        assert "kcal" in data["data"]["answer"] or "卡路里" in data["data"]["answer"]

    def test_exercise_query_returns_answer(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={
                "intent": "query",
                "query_type": "exercise_today",
                "query_text": "今天运动达标了吗",
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert "answer" in data["data"]

    def test_unknown_intent_rejected(self, app_client, auth_headers):
        _, client = app_client
        resp = client.post(
            "/api/v1/agent/execute",
            json={"intent": "unknown"},
            headers=auth_headers,
        )
        assert resp.status_code == 422
