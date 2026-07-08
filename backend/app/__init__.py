from flask import Flask
from sqlalchemy import inspect, text

from .api.auth import auth_bp
from .api.planner import planner_bp
from .api.profile import profile_bp
from .api.settings import settings_bp
from .api.updates import updates_bp
from .api.voice import voice_bp
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

    @app.get("/healthz")
    def healthcheck():
        return {"ok": True, "data": {"status": "healthy"}, "error": None, "meta": {}}

    return app


def _ensure_tables(app: Flask) -> None:
    """Create tables and repair broken ones from prior partial deploys."""
    with app.app_context():
        try:
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            if not tables:
                db.create_all()
                return

            if "users" in tables:
                cols = {c["name"] for c in inspector.get_columns("users")}
                if "email" not in cols:
                    # Drop all user tables with CASCADE, then recreate
                    db.session.execute(text("""
                        DO $$ DECLARE
                            r RECORD;
                        BEGIN
                            FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
                                EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
                            END LOOP;
                        END $$;
                    """))
                    db.session.commit()
                    db.create_all()
        except Exception:
            pass  # Table repair is best-effort; app starts regardless
