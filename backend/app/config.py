from __future__ import annotations

import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parents[1]


def _normalize_database_url(raw_url: str | None) -> str:
    if not raw_url:
        db_path = BASE_DIR / "data" / "pixel_planner.db"
        return f"sqlite:///{db_path.as_posix()}"
    if raw_url.startswith("postgres://"):
        return raw_url.replace("postgres://", "postgresql+psycopg://", 1)
    if raw_url.startswith("postgresql://"):
        return raw_url.replace("postgresql://", "postgresql+psycopg://", 1)
    return raw_url


class BaseConfig:
    SECRET_KEY = os.getenv("PIXEL_SECRET_KEY", "pixel-planner-dev-secret")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_AS_ASCII = False

    DB_PATH = BASE_DIR / "data" / "pixel_planner.db"
    SQLALCHEMY_DATABASE_URI = _normalize_database_url(os.getenv("DATABASE_URL"))

    JWT_ISSUER = os.getenv("JWT_ISSUER", "pixel-planner")
    JWT_ACCESS_TTL_SECONDS = int(os.getenv("JWT_ACCESS_TTL_SECONDS", "3600"))
    JWT_REFRESH_TTL_SECONDS = int(os.getenv("JWT_REFRESH_TTL_SECONDS", "31536000"))

    UPDATE_MANIFEST_PATH = os.getenv(
        "UPDATE_MANIFEST_PATH",
        str((BASE_DIR.parent / "assets" / "update_manifest.json").resolve()),
    )
    UPDATE_RESOURCE_DIR = os.getenv(
        "UPDATE_RESOURCE_DIR",
        str((BASE_DIR.parent / "assets" / "resources").resolve()),
    )
    APP_VERSION = os.getenv("APP_VERSION", "5.0.0")
    APP_BUILD = os.getenv("APP_BUILD", "50000")
    APP_DOWNLOAD_URL = os.getenv("APP_DOWNLOAD_URL", "")

    SMS_CODE_EXPIRE_SECONDS = int(os.getenv("SMS_CODE_EXPIRE_SECONDS", "300"))
    SMS_CODE_LENGTH = int(os.getenv("SMS_CODE_LENGTH", "6"))
    SMS_PROVIDER = os.getenv("SMS_PROVIDER", "console")

    BACKDOOR_PHONE = os.getenv("BACKDOOR_PHONE", "13800000001")
    BACKDOOR_CODE = os.getenv("BACKDOOR_CODE", "888888")

    TENCENT_SECRET_ID = os.getenv("TENCENT_SECRET_ID") or os.getenv("TENCENTCLOUD_SECRET_ID", "")
    TENCENT_SECRET_KEY = os.getenv("TENCENT_SECRET_KEY") or os.getenv("TENCENTCLOUD_SECRET_KEY", "")
    TENCENT_ASR_REGION = os.getenv("TENCENT_ASR_REGION", "ap-shanghai")
    TENCENT_ASR_ENGINE_TYPE = os.getenv("TENCENT_ASR_ENGINE_TYPE", "16k_zh")
    TENCENT_ASR_VOICE_FORMAT = os.getenv("TENCENT_ASR_VOICE_FORMAT", "wav")


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
