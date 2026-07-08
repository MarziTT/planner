"""Pre-start script: ensure database tables exist and are valid."""

try:
    from .app import create_app
except ImportError:
    from app import create_app

app = create_app(repair_tables=True)
print("ensure_tables: OK")
