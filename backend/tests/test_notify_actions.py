from datetime import datetime

from app.services.smart_notify_service import _with_presentation


def test_non_urgent_notification_has_snooze_and_dismiss_actions():
    insight = _with_presentation(
        {
            "insight_type": "standing_nudge",
            "priority": "medium",
            "title": "起来活动一下",
            "body": "坐得有点久了",
            "data": {},
        },
        datetime(2026, 7, 31, 10, 0),
    )
    actions = insight["presentation"]["actions"]
    assert {action["action"] for action in actions} == {
        "log_standing", "snooze", "dismiss_today",
    }
    assert next(action for action in actions if action["action"] == "snooze")["minutes"] == 30


def test_high_priority_notification_cannot_be_snoozed_from_contract():
    insight = _with_presentation(
        {
            "insight_type": "wake_deviation",
            "priority": "high",
            "title": "重要提醒",
            "body": "请尽快处理",
            "data": {},
        },
        datetime(2026, 7, 31, 10, 0),
    )
    assert [action["action"] for action in insight["presentation"]["actions"]] == ["open_health"]
