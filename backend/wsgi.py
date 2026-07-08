try:
    from .app import create_app
except ImportError:
    from app import create_app  # fallback: standalone script execution

app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
