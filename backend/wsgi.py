import sys
from pathlib import Path

# Python 3.14+ no longer auto-adds CWD to sys.path;
# ensure the backend directory itself is importable.
_backend_dir = Path(__file__).resolve().parent
if str(_backend_dir) not in sys.path:
    sys.path.insert(0, str(_backend_dir))

try:
    from .app import create_app
except ImportError:
    from app import create_app  # fallback: standalone script execution


def create_wsgi_app():
    """Gunicorn entry: enable table repair on startup."""
    return create_app(repair_tables=True)


app = create_app(repair_tables=True)  # Flask CLI & gunicorn entry

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
