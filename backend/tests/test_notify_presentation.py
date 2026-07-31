from datetime import datetime

from app.services.smart_notify_service import _with_presentation


def test_notification_presentation_has_live_activity_contract():
    insight = _with_presentation(
        {
            "insight_type": "exercise_drop",
            "priority": "medium",
            "title": "运动量下降",
            "body": "这周运动少了很多",
            "data": {"drop_pct": 40},
        },
        datetime(2026, 7, 31, 10, 0),
    )

    presentation = insight["presentation"]
    assert presentation["surface"] == "notification_and_live_activity"
    assert presentation["category"] == "exercise_drop"
    assert presentation["route"] == "/exercise"
    assert presentation["actions"][0]["action"] == "open_exercise"
    assert presentation["expires_at"]
    assert presentation["ongoing"] is False
