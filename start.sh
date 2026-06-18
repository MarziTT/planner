#!/bin/bash
echo "=== ENV CHECK ==="
echo "DATABASE_URL set: $( [ -n "$DATABASE_URL" ] && echo YES || echo NO )"
echo "PORT: $PORT"
echo "Total env vars: $(env | wc -l)"
echo "================="
exec gunicorn server:app --bind 0.0.0.0:$PORT
