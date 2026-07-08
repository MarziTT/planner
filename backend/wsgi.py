try:
    from .app import create_app
except ImportError:
    from app import create_app  # fallback: standalone script execution


def create_wsgi_app():
    """Gunicorn entry: enable table repair on startup."""
    return create_app(repair_tables=True)


app = create_app()  # Flask CLI entry (no repair)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
