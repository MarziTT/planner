"""Tests for meal_service.py — meal recording, daily summary, calorie aggregation.

Requires DB fixtures (test_user).
Pure-logic helpers (_calories_from_items) tested without DB.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from app.models_habits import MealRecord
from app.services.meal_service import (
    _calories_from_items,
    _meal_to_dict,
    create_meal_record,
    get_daily_summary,
    get_meal_history,
    get_today_meals,
    get_weekly_average_calories,
)


# ===========================================================================
# _calories_from_items — pure logic
# ===========================================================================


class TestCaloriesFromItems:
    def test_single_item(self):
        items = [{"name": "米饭", "calories": 200}]
        assert _calories_from_items(items) == 200

    def test_multiple_items(self):
        items = [
            {"name": "米饭", "calories": 200},
            {"name": "西红柿炒鸡蛋", "calories": 220},
            {"name": "拿铁", "calories": 150},
        ]
        assert _calories_from_items(items) == 570

    def test_none_item(self):
        assert _calories_from_items(None) == 0

    def test_empty_list(self):
        assert _calories_from_items([]) == 0

    def test_missing_calories(self):
        items = [{"name": "未知食物"}]
        assert _calories_from_items(items) == 0

    def test_mixed(self):
        items = [
            {"name": "米饭", "calories": 200},
            {"name": "水", "calories": 0},
            {"name": "未知"},
        ]
        assert _calories_from_items(items) == 200


# ===========================================================================
# create_meal_record
# ===========================================================================


class TestCreateMealRecord:
    def test_basic_creation(self, db_session, test_user):
        items = [{"name": "牛肉面", "calories": 500}]
        record = create_meal_record(
            user_id=test_user.id,
            meal_type="lunch",
            items=items,
        )
        assert record.id is not None
        assert record.user_id == test_user.id
        assert record.meal_type == "lunch"
        assert isinstance(record.items, list)
        assert record.items[0]["name"] == "牛肉面"

    def test_defaults(self, db_session, test_user):
        record = create_meal_record(
            user_id=test_user.id,
            meal_type="breakfast",
            items=[],
        )
        assert record.source == "photo"
        assert record.recorded_at is not None

    def test_persistence(self, db_session, test_user):
        create_meal_record(test_user.id, "dinner", [{"name": "沙拉", "calories": 300}])
        records = MealRecord.query.filter_by(user_id=test_user.id).all()
        assert len(records) == 1
        assert records[0].meal_type == "dinner"


# ===========================================================================
# get_today_meals
# ===========================================================================


class TestGetTodayMeals:
    def test_empty(self, db_session, test_user):
        meals = get_today_meals(test_user.id)
        assert meals == []

    def test_with_records(self, db_session, test_user):
        create_meal_record(test_user.id, "breakfast",
                           [{"name": "包子", "calories": 300}])
        create_meal_record(test_user.id, "lunch",
                           [{"name": "面条", "calories": 400}])

        meals = get_today_meals(test_user.id)
        assert len(meals) == 2
        # Should be ordered ASC by recorded_at
        assert meals[0]["meal_type"] == "breakfast"
        assert meals[1]["meal_type"] == "lunch"


# ===========================================================================
# get_meal_history
# ===========================================================================


class TestGetMealHistory:
    def test_empty(self, db_session, test_user):
        history = get_meal_history(test_user.id)
        assert history == []

    def test_days_filter(self, db_session, test_user):
        ten_days_ago = datetime.now(timezone.utc) - timedelta(days=10)
        record = MealRecord(
            user_id=test_user.id,
            meal_type="dinner",
            items=[],
            recorded_at=ten_days_ago,
        )
        db_session.add(record)
        db_session.commit()

        history_7d = get_meal_history(test_user.id, days=7)
        assert len(history_7d) == 0

        history_30d = get_meal_history(test_user.id, days=30)
        assert len(history_30d) == 1


# ===========================================================================
# get_daily_summary
# ===========================================================================


class TestGetDailySummary:
    def test_empty(self, db_session, test_user):
        summary = get_daily_summary(test_user.id)
        assert summary["total_calories"] == 0
        assert summary["meal_count"] == 0

    def test_with_multiple_meal_types(self, db_session, test_user):
        create_meal_record(test_user.id, "breakfast",
                           [{"name": "包子", "calories": 300}])
        create_meal_record(test_user.id, "lunch",
                           [{"name": "牛肉面", "calories": 600}])
        create_meal_record(test_user.id, "dinner",
                           [{"name": "沙拉", "calories": 200}])

        summary = get_daily_summary(test_user.id)
        assert summary["total_calories"] == 1100
        assert summary["meal_count"] == 3
        assert summary["by_type"]["breakfast"] is not None
        assert summary["by_type"]["lunch"] is not None
        assert summary["by_type"]["dinner"] is not None
        assert summary["by_type"]["snack"] is None  # no snack recorded


# ===========================================================================
# get_weekly_average_calories
# ===========================================================================


class TestGetWeeklyAverageCalories:
    def test_empty(self, db_session, test_user):
        avg = get_weekly_average_calories(test_user.id)
        assert avg == 0.0

    def test_single_day(self, db_session, test_user):
        create_meal_record(test_user.id, "lunch",
                           [{"name": "面", "calories": 500}])
        avg = get_weekly_average_calories(test_user.id)
        assert avg == 500.0

    def test_multiple_days(self, db_session, test_user):
        # Day 1 (today)
        create_meal_record(test_user.id, "lunch",
                           [{"name": "面", "calories": 400}])
        # Day 2 (yesterday)
        yesterday = datetime.now(timezone.utc) - timedelta(days=1)
        r1 = MealRecord(
            user_id=test_user.id, meal_type="dinner",
            items=[{"name": "饭", "calories": 600}],
            recorded_at=yesterday,
        )
        db_session.add(r1)
        # Day 3 (2 days ago)
        two_days_ago = datetime.now(timezone.utc) - timedelta(days=2)
        r2 = MealRecord(
            user_id=test_user.id, meal_type="dinner",
            items=[{"name": "面", "calories": 500}],
            recorded_at=two_days_ago,
        )
        db_session.add(r2)
        db_session.commit()

        avg = get_weekly_average_calories(test_user.id)
        # (400 + 600 + 500) / 3 = 500
        assert avg == 500.0
