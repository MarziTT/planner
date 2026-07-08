web: mkdir -p backend/data && flask --app backend.wsgi db upgrade && gunicorn --bind 0.0.0.0:$PORT backend.wsgi:app
