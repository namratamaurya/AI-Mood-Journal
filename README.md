# AI Mood Journal

A human-centred journaling app that analyzes daily entries, tags emotional tone, and surfaces mood patterns over time.

## Stack

- Flutter Web for the journal dashboard and charts
- FastAPI for REST endpoints
- SQLite for local entry storage
- Claude API for mood analysis when `ANTHROPIC_API_KEY` is configured
- Local heuristic analyzer as a development fallback

## Project Layout

```text
backend/
  app/
    analysis.py    Python-only mood analysis and pattern logic
    database.py    SQLite persistence
    main.py        FastAPI routes
    models.py      Pydantic API models

frontend/
  lib/
    main.dart                    Flutter app bootstrap and theme
    models/journal_models.dart   Dart-only UI/API models
    services/api_client.dart     REST calls to the backend
    screens/journal_dashboard.dart
```

## Backend

Use Python 3.11, 3.12, or 3.13 for the backend virtual environment. Avoid Python
3.14 for now because native dependencies such as `pydantic-core` may not have
prebuilt wheels available and can fail while compiling.

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

If `python3.12` is not installed, install a stable Python from
https://www.python.org/downloads/macos/ and then recreate the virtual
environment.

Optional Claude configuration:

```bash
export ANTHROPIC_API_KEY="your_key"
```

If no key is set, the backend uses a deterministic local analyzer so the product remains demoable.

## Frontend

Install Flutter, then run:

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

## API

- `POST /entries` creates a journal entry and returns AI mood analysis
- `GET /entries` lists entries
- `GET /stats` returns streak, mood counts, weekly average, and patterns
- `GET /summaries/weekly` returns an AI-generated weekly reflection
