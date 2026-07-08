from __future__ import annotations

import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parents[1]


class BaseConfig:
    SECRET_KEY = os.getenv("PIXEL_SECRET_KEY", "pixel-planner-dev-secret")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_AS_ASCII = False

    DB_PATH = BASE_DIR / "data" / "pixel_planner.db"
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL") or f"sqlite:///{DB_PATH.as_posix()}"

    JWT_ISSUER = os.getenv("JWT_ISSUER", "pixel-planner")
    JWT_ACCESS_TTL_SECONDS = int(os.getenv("JWT_ACCESS_TTL_SECONDS", "3600"))
    JWT_REFRESH_TTL_SECONDS = int(os.getenv("JWT_REFRESH_TTL_SECONDS", "2592000"))

    UPDATE_MANIFEST_PATH = os.getenv(
        "UPDATE_MANIFEST_PATH",
        str((BASE_DIR.parent / "assets" / "update_manifest.json").resolve()),
    )
    APP_VERSION = os.getenv("APP_VERSION", "5.0.0")
    APP_BUILD = os.getenv("APP_BUILD", "50000")
    APP_DOWNLOAD_URL = os.getenv("APP_DOWNLOAD_URL", "")


class DevelopmentConfig(BaseConfig):
    DEBUG = True


class TestingConfig(BaseConfig):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"


class ProductionConfig(BaseConfig):
    DEBUG = False


def get_config(config_name: str | None = None):
    name = (config_name or os.getenv("FLASK_ENV") or "development").lower()
    mapping = {
        "development": DevelopmentConfig,
        "testing": TestingConfig,
        "production": ProductionConfig,
    }
    return mapping.get(name, DevelopmentConfig)
