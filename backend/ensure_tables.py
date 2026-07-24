"""Pre-start script: ensure database tables exist and are valid."""
import sys
import os

# Ensure the backend/ directory is on sys.path so 'app' can be imported
# whether invoked as `python backend/ensure_tables.py` or from within backend/.
_here = os.path.dirname(os.path.abspath(__file__))
if _here not in sys.path:
    sys.path.insert(0, _here)

from app import create_app

app = create_app(repair_tables=True)
print("ensure_tables: OK")
