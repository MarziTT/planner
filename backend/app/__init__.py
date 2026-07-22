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
        try:
            db.session.execute(text("SELECT 1"))
            db_status = "ok"
        except Exception:
            db_status = "unreachable"
        return {
            "ok": True,
            "data": {"status": "healthy", "db": db_status},
            "error": None,
            "meta": {},
        }

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

        # PostgreSQL-specific: add is_recurring/recurrence_rule columns if tags table exists without them
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "tags" in tables:
                cols = {c["name"] for c in inspector.get_columns("tags")}
                dialect = db.engine.dialect.name
                if "is_recurring" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE tags ADD COLUMN is_recurring BOOLEAN NOT NULL DEFAULT false"
                        ))
                    db.session.commit()
                if "recurrence_rule" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE tags ADD COLUMN recurrence_rule VARCHAR(120) NOT NULL DEFAULT ''"
                        ))
                    db.session.commit()
        except Exception:
            db.session.rollback()
            pass

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

        # PostgreSQL-specific: add missing profile columns
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "profiles" in tables:
                cols = {c["name"] for c in inspector.get_columns("profiles")}
                dialect = db.engine.dialect.name
                missing = [
                    ("identity", "VARCHAR(32) NOT NULL DEFAULT 'worker'"),
                    ("routine_start", "VARCHAR(8) NOT NULL DEFAULT '09:00'"),
                    ("routine_end", "VARCHAR(8) NOT NULL DEFAULT '18:00'"),
                    ("focus_area", "VARCHAR(120) NOT NULL DEFAULT ''"),
                    ("wants_fitness", "BOOLEAN NOT NULL DEFAULT false"),
                    ("fitness_mode", "VARCHAR(32) NOT NULL DEFAULT 'self'"),
                ]
                if dialect == "postgresql":
                    for col_name, col_def in missing:
                        if col_name not in cols:
                            db.session.execute(text(
                                f"ALTER TABLE profiles ADD COLUMN {col_name} {col_def}"
                            ))
                db.session.commit()
        except Exception:
            db.session.rollback()
            pass
