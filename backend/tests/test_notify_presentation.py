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
    assert presentation["dedupe_key"] == insight["dedupe_key"]
    assert presentation["cooldown_minutes"] == 24 * 60


def test_notification_dedupe_key_is_stable_for_same_daily_insight():
    now = datetime(2026, 7, 31, 10, 0)
    base = {
        "insight_type": "standing_nudge",
        "priority": "medium",
        "title": "起来活动一下",
        "body": "已经连续跳过三次",
        "data": {"consecutive_skips": 3},
    }
    first = _with_presentation(base, now)
    second = _with_presentation(base, now.replace(hour=11))
    changed = _with_presentation({**base, "data": {"consecutive_skips": 4}}, now)

    assert first["dedupe_key"] == second["dedupe_key"]
    assert first["dedupe_key"] != changed["dedupe_key"]
