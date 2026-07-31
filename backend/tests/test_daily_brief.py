from unittest.mock import patch

from app.services.daily_brief_service import build_daily_brief


@patch("app.services.daily_brief_service._load_persona", return_value={"butler_name": "阿福", "user_name": "小林", "tone": "温和朋友"})
@patch("app.services.daily_brief_service.get_dashboard_overview")
def test_daily_brief_combines_life_domains(mock_overview, mock_persona):
    mock_overview.return_value = {
        "date": "2026-07-31",
        "weather": {"available": True, "condition": "晴", "high": 30, "low": 22},
        "schedule": {"pending_count": 1, "upcoming": [{"time": "09:00", "title": "晨会"}]},
        "exercise": {"total_minutes": 30},
        "meals": {"meal_count": 1, "total_calories": 500},
        "routine": {"auto_stopped": False},
    }

    result = build_daily_brief(1)
    assert result["date"] == "2026-07-31"
    assert "晴" in result["summary"]
    assert "晨会" in result["summary"]
    assert "达标" in result["summary"]
    assert result["compact_summary"]
    assert result["summary"].startswith("小林，")
    assert "有事叫我" in result["summary"]


@patch("app.services.daily_brief_service.get_dashboard_overview")
def test_daily_brief_adds_weather_comfort_and_travel_tips(mock_overview):
    mock_overview.return_value = {
        "date": "2026-07-31",
        "weather": {"available": True, "condition": "阵雨", "high": 34, "low": 25},
        "schedule": {"pending_count": 1, "upcoming": [{"time": "14:00", "title": "客户会议"}]},
        "exercise": {"total_minutes": 0},
        "meals": {"meal_count": 0, "total_calories": 0},
        "routine": {"auto_stopped": False},
    }

    result = build_daily_brief(1)
    assert "带伞" in result["travel_tips"]
    assert any("客户会议" in tip for tip in result["travel_tips"])
    assert any("补水" in tip for tip in result["comfort_tips"])


@patch("app.services.daily_brief_service.get_dashboard_overview")
def test_daily_brief_adapts_to_air_quality_uv_and_short_sleep(mock_overview):
    mock_overview.return_value = {
        "date": "2026-07-31",
        "weather": {
            "available": True,
            "condition": "晴",
            "high": 28,
            "low": 20,
            "humidity": 85,
            "uv_index": 8,
            "air_quality_index": 120,
        },
        "schedule": {"pending_count": 0, "upcoming": []},
        "exercise": {"total_minutes": 0},
        "meals": {"meal_count": 0, "total_calories": 0},
        "routine": {"auto_stopped": False, "sleep_hours": 5.5},
    }

    result = build_daily_brief(1)
    assert "湿度较高，注意通风" in result["comfort_tips"]
    assert "紫外线较强，注意防晒" in result["comfort_tips"]
    assert "优先补充休息" in result["comfort_tips"]
    assert "空气质量一般，减少户外剧烈运动" in result["travel_tips"]
    assert "睡眠不足" in result["summary"]


@patch("app.services.daily_brief_service.get_dashboard_overview")
@patch("app.services.daily_brief_service.now_hour", return_value=15)
def test_daily_brief_covers_transit_food_and_weekend(mock_hour, mock_overview):
    mock_overview.return_value = {
        "date": "2026-08-01",
        "weather": {"available": False},
        "schedule": {"pending_count": 0, "upcoming": []},
        "transit": {"trip_count": 1, "trips": [{"minutes_to_departure": 45}]},
        "exercise": {"total_minutes": 0},
        "meals": {"meal_count": 1, "total_calories": 400},
        "routine": {"auto_stopped": False},
    }

    result = build_daily_brief(1)
    assert any("手机电量" in tip for tip in result["travel_tips"])
    assert any("摄入偏少" in tip for tip in result["food_tips"])
    assert any("短途散步" in tip for tip in result["travel_tips"])
