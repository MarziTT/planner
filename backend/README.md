# Backend

## Stack

- Flask app factory
- Blueprint routing
- SQLAlchemy models
- Flask-Migrate / Alembic
- JWT access + refresh tokens

## Run locally

1. Create a virtualenv.
2. Install `backend/requirements.txt`.
3. Copy `.env.example` to `.env` and adjust values.
4. Run `flask --app wsgi run --debug` from `backend/`.

## API groups

- `/api/v1/auth/*`
- `/api/v1/events`
- `/api/v1/todos`
- `/api/v1/tags`
- `/api/v1/profile`
- `/api/v1/settings`
- `/api/v1/stats`
- `/api/v1/voice/asr`
- `/api/v1/app/version`
- `/api/v1/app/update-manifest`
