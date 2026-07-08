import importlib

from app import config as config_module


def test_postgres_database_url_uses_psycopg_driver(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://user:pass@db.railway.internal:5432/pixelplanner")
    importlib.reload(config_module)

    config = config_module.get_config("production")

    assert (
        config.SQLALCHEMY_DATABASE_URI
        == "postgresql+psycopg://user:pass@db.railway.internal:5432/pixelplanner"
    )
