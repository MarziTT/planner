from flask import Flask

from .api.auth import auth_bp
from .api.planner import planner_bp
from .api.profile import profile_bp
from .api.settings import settings_bp
from .api.updates import updates_bp
from .api.voice import voice_bp
from .config import get_config
from .extensions import cors, db, migrate
from .models import register_models


def create_app(config_name: str | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(get_config(config_name))

    cors.init_app(app, resources={r"/api/*": {"origins": "*"}})
    db.init_app(app)
    migrate.init_app(app, db)

    register_models()
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
