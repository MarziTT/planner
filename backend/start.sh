#!/bin/bash
set -e

echo "Checking environment variables..."
if [ -z "$DATABASE_URL" ]; then
    echo "WARNING: DATABASE_URL not set, will use SQLite"
fi

echo "Starting gunicorn..."
cd /app
exec gunicorn --bind 0.0.0.0:$PORT backend.wsgi:app