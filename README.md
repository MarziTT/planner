# Pixel Planner

Pixel Planner has been rebuilt into a clean two-part project:

- `mobile_app/`: Flutter Android client
- `backend/`: Flask API service
- `assets/`: shared update manifest and static app assets

## Project Structure

```text
PixelPlanner/
|- mobile_app/      Flutter client
|- backend/         Flask API, models, migrations, routes
|- assets/          update manifest and shared static assets
|- Procfile         production backend start command
|- requirements.txt root deployment dependencies
```

## Local Development

### Mobile app

```bash
cd mobile_app
flutter pub get
flutter run
```

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r ..\requirements.txt
flask --app wsgi run --debug
```

The API base path is `/api/v1/*`.

## Current Scope

- JWT login and session refresh
- planner events and todos
- tags, profile, settings
- update manifest checks
- Flutter-based Android app UI
