from flask import Flask
from sqlalchemy import inspect, text

from .api.agent import agent_bp
from .api.auth import auth_bp
from .api.dashboard import dashboard_bp
from .api.exercise import exercise_bp
from .api.habits import habits_bp
from .api.meals import meals_bp
from .api.notifications import notify_bp
from .api.planner import planner_bp
from .api.profile import profile_bp
from .api.routine import routine_bp
from .api.scheduler import scheduler_bp
from .api.scene import scene_bp
from .api.settings import settings_bp
from .api.transit import transit_bp
from .api.updates import updates_bp
from .api.voice import voice_bp
from .api.weather import weather_bp
from .api.widget import widget_bp
from .config import get_config
from .extensions import cors, db, limiter, migrate
from .models import register_models


def create_app(config_name: str | None = None, repair_tables: bool = False) -> Flask:
    app = Flask(__name__)
    app.config.from_object(get_config(config_name))

    cors.init_app(app, resources={r"/api/*": {"origins": app.config.get("CORS_ORIGINS", "*")}})
    db.init_app(app)
    migrate.init_app(app, db)
    limiter.init_app(app)

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
    app.register_blueprint(agent_bp, url_prefix="/api/v1/agent")
    app.register_blueprint(scheduler_bp, url_prefix="/api/v1/scheduler")
    app.register_blueprint(scene_bp, url_prefix="/api/v1")
    app.register_blueprint(habits_bp, url_prefix="/api/v1")
    app.register_blueprint(routine_bp, url_prefix="/api/v1")
    app.register_blueprint(meals_bp, url_prefix="/api/v1")
    app.register_blueprint(exercise_bp, url_prefix="/api/v1")
    app.register_blueprint(transit_bp, url_prefix="/api/v1")
    app.register_blueprint(dashboard_bp, url_prefix="/api/v1")
    app.register_blueprint(notify_bp, url_prefix="/api/v1")
    app.register_blueprint(widget_bp, url_prefix="/api/v1")

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
            app.logger.exception("Database table creation/verification failed")

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
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT 'migrated'"
                        ))
                        db.session.execute(text(
                            "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_phone ON users (phone)"
                        ))
                    db.session.commit()
                    app.logger.info("Migration: added phone column to users table (dialect=%s)", dialect)
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: users.phone column")

        # Add is_recurring/recurrence_rule columns if tags table exists without them
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
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE tags ADD COLUMN is_recurring BOOLEAN DEFAULT false"
                        ))
                    db.session.commit()
                    app.logger.info("Migration: added is_recurring to tags (dialect=%s)", dialect)
                if "recurrence_rule" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE tags ADD COLUMN recurrence_rule VARCHAR(120) NOT NULL DEFAULT ''"
                        ))
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE tags ADD COLUMN recurrence_rule VARCHAR(120) DEFAULT ''"
                        ))
                    db.session.commit()
                    app.logger.info("Migration: added recurrence_rule to tags (dialect=%s)", dialect)
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: tags columns")

        # Ensure settings table exists (db.create_all() may silently fail on PG)
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "settings" not in tables:
                dialect = db.engine.dialect.name
                if dialect == "postgresql":
                    db.session.execute(text("""
                        CREATE TABLE IF NOT EXISTS settings (
                            user_id INTEGER PRIMARY KEY REFERENCES users(id),
                            theme VARCHAR(32) NOT NULL DEFAULT 'forest',
                            theme_mode VARCHAR(16) NOT NULL DEFAULT 'dark',
                            notifications_enabled BOOLEAN NOT NULL DEFAULT true,
                            voice_enabled BOOLEAN NOT NULL DEFAULT true,
                            update_channel VARCHAR(32) NOT NULL DEFAULT 'stable',
                            zzz_enabled BOOLEAN NOT NULL DEFAULT false,
                            weather_tone TEXT,
                            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
                        )
                    """))
                elif dialect == "sqlite":
                    db.session.execute(text("""
                        CREATE TABLE IF NOT EXISTS settings (
                            user_id INTEGER PRIMARY KEY REFERENCES users(id),
                            theme VARCHAR(32) NOT NULL DEFAULT 'forest',
                            theme_mode VARCHAR(16) NOT NULL DEFAULT 'dark',
                            notifications_enabled BOOLEAN NOT NULL DEFAULT 1,
                            voice_enabled BOOLEAN NOT NULL DEFAULT 1,
                            update_channel VARCHAR(32) NOT NULL DEFAULT 'stable',
                            zzz_enabled BOOLEAN NOT NULL DEFAULT 0,
                            weather_tone TEXT,
                            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                        )
                    """))
                db.session.commit()
                app.logger.info("Manually created settings table (dialect=%s)", dialect)
        except Exception:
            db.session.rollback()
            app.logger.exception("Failed to create settings table")

        # Add zzz_enabled column if settings table exists without it
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
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE settings ADD COLUMN zzz_enabled BOOLEAN DEFAULT false"
                        ))
                    db.session.commit()
                    app.logger.info("Migration: added zzz_enabled to settings (dialect=%s)", dialect)
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: settings.zzz_enabled")

        # Add missing profile columns
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
                # SQLite doesn't support NOT NULL in ALTER TABLE ADD COLUMN
                sqlite_missing = [
                    ("identity", "VARCHAR(32) DEFAULT 'worker'"),
                    ("routine_start", "VARCHAR(8) DEFAULT '09:00'"),
                    ("routine_end", "VARCHAR(8) DEFAULT '18:00'"),
                    ("focus_area", "VARCHAR(120) DEFAULT ''"),
                    ("wants_fitness", "BOOLEAN DEFAULT false"),
                    ("fitness_mode", "VARCHAR(32) DEFAULT 'self'"),
                ]
                target = sqlite_missing if dialect == "sqlite" else missing
                for col_name, col_def in target:
                    if col_name not in cols:
                        db.session.execute(text(
                            f"ALTER TABLE profiles ADD COLUMN {col_name} {col_def}"
                        ))
                db.session.commit()
                app.logger.info("Migration: checked profiles columns (dialect=%s)", dialect)
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: profiles columns")

        # Phase 2 — add exercise_mode / trainer_end_date to users
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "users" in tables:
                cols = {c["name"] for c in inspector.get_columns("users")}
                dialect = db.engine.dialect.name
                if "exercise_mode" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN exercise_mode VARCHAR(20) NOT NULL DEFAULT 'self'"
                        ))
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN exercise_mode VARCHAR(20) DEFAULT 'self'"
                        ))
                    db.session.commit()
                if "trainer_end_date" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN trainer_end_date DATE"
                        ))
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE users ADD COLUMN trainer_end_date DATE"
                        ))
                    db.session.commit()
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: users exercise_mode/trainer_end_date")

        # Phase 2 — add calories/steps to exercise_records
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if "exercise_records" in tables:
                cols = {c["name"] for c in inspector.get_columns("exercise_records")}
                dialect = db.engine.dialect.name
                if "calories" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE exercise_records ADD COLUMN calories INTEGER"
                        ))
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE exercise_records ADD COLUMN calories INTEGER"
                        ))
                    db.session.commit()
                if "steps" not in cols:
                    if dialect == "postgresql":
                        db.session.execute(text(
                            "ALTER TABLE exercise_records ADD COLUMN steps INTEGER"
                        ))
                    elif dialect == "sqlite":
                        db.session.execute(text(
                            "ALTER TABLE exercise_records ADD COLUMN steps INTEGER"
                        ))
                    db.session.commit()
        except Exception:
            db.session.rollback()
            app.logger.exception("Migration failed: exercise_records columns")
