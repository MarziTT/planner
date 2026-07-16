from flask import Flask
from sqlalchemy import inspect, text

from .api.auth import auth_bp
from .api.planner import planner_bp
from .api.profile import profile_bp
from .api.settings import settings_bp
from .api.updates import updates_bp
from .api.voice import voice_bp
from .api.weather import weather_bp
from .config import get_config
from .extensions import cors, db, migrate
from .models import register_models


def create_app(config_name: str | None = None, repair_tables: bool = False) -> Flask:
    app = Flask(__name__)
    app.config.from_object(get_config(config_name))

    cors.init_app(app, resources={r"/api/*": {"origins": "*"}})
    db.init_app(app)
    migrate.init_app(app, db)

    register_models()

    if repair_tables:
        _ensure_tables(app)

    app.register_blueprint(auth_bp, url_prefix="/api/v1/auth")
    app.register_blueprint(planner_bp, url_prefix="/api/v1")
    app.register_blueprint(profile_bp, url_prefix="/api/v1")
    app.register_blueprint(settings_bp, url_prefix="/api/v1")
    app.register_blueprint(voice_bp, url_prefix="/api/v1/voice")
    app.register_blueprint(updates_bp, url_prefix="/api/v1/app")
    app.register_blueprint(weather_bp, url_prefix="/api/v1/weather")

    @app.get("/healthz")
    def healthcheck():
        return {"ok": True, "data": {"status": "healthy"}, "error": None, "meta": {}}

    return app


def _ensure_tables(app: Flask) -> None:
    """Create missing tables and migrate existing ones to match current models."""
    with app.app_context():
        try:
            db.create_all()
        except Exception:
            pass

        # PostgreSQL-specific: add phone column if users table exists without it
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "users" in tables:
                cols = {c["name"] for c in inspector.get_columns("users")}
                if "phone" not in cols:
                    dialect = db.engine.dialect.name
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN phone VARCHAR(20)"
                        ))
                        db.session.execute(text(
                            "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_phone ON users (phone)"
                        ))
                        db.session.execute(text(
                            "UPDATE users SET phone = 'migrated_' || id WHERE phone IS NULL"
                        ))
                        db.session.execute(text(
                            "ALTER TABLE users ALTER COLUMN phone SET NOT NULL"
                        ))
                        db.session.execute(text(
                            "ALTER TABLE users ALTER COLUMN email DROP NOT NULL"
                        ))
                        db.session.execute(text(
                            "ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL"
                        ))
                    db.session.commit()
        except Exception:
            db.session.rollback()
            pass  # Best-effort; app starts regardless

        # PostgreSQL-specific: add zzz_enabled column if settings table exists without it
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "settings" in tables:
                cols = {c["name"] for c in inspector.get_columns("settings")}
                if "zzz_enabled" not in cols:
                    dialect = db.engine.dialect.name
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE settings ADD COLUMN zzz_enabled BOOLEAN NOT NULL DEFAULT false"
                        ))
                    db.session.commit()
        except Exception:
            db.session.rollback()
            pass
