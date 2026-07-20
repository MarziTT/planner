"""Render gunicorn entry point — from project root, no --chdir needed."""
import sys
from pathlib import Path

# Ensure backend/ is importable (Python 3.14+ removed implicit CWD from sys.path)
_sys_path_backend = str(Path(__file__).resolve().parent / "backend")
if _sys_path_backend not in sys.path:
    sys.path.insert(0, _sys_path_backend)

# Forward to the real wsgi app
from backend.wsgi import app  # noqa: E402, F401
