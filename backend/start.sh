#!/bin/bash
set -e

echo "Checking environment variables..."
if [ -z "$DATABASE_URL" ]; then
    echo "WARNING: DATABASE_URL not set, will use SQLite"
fi

echo "Running database migrations..."
flask --app wsgi db upgrade

echo "Starting gunicorn..."
exec gunicorn --bind 0.0.0.0:$PORT wsgi:app