# FinTrack AI - Intelligent Personal Finance Management System
*Understand Your Money. Predict Your Future.*

Two projects:
```
backend/    Django REST API + ML (finance/ml) + Dockerfile
frontend/   Flutter app (Riverpod, GoRouter, offline-first). Users get the finance app, admins get the admin console.
docs/       screenshots        infrastructure/  nginx config        docker-compose.yml
```

## Run locally
`run.bat` (starts the API on :8000 and the Flutter app in Chrome) or manually:
```
cd backend  && pip install -r requirements.txt && python manage.py migrate && python manage.py seed_demo && python manage.py runserver
cd frontend && flutter pub get && flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
```
Flutter SDK is at `C:\dev\flutter` (add `C:\dev\flutter\bin` to PATH).

| Role | Login |
|---|---|
| Demo user (premium) | demo@fintrack.ai / demo1234 |
| Administrator | admin@fintrack.ai / admin1234 |

API: http://127.0.0.1:8000/api/v1/ · Django admin: http://127.0.0.1:8000/admin/

## Deploy
- **Backend**: `docker compose up --build` (Postgres + gunicorn + nginx). Copy `.env.example` to `.env` first; `DEBUG=0` requires a real `SECRET_KEY`; CORS limited to `CORS_ALLOWED_ORIGINS`.
- **Frontend (web)**: `cd frontend && flutter build web --release --dart-define=API_BASE=https://api.example.com` -> upload `build/web` to any static host (or let the compose nginx serve it).
- **Frontend (mobile)**: `flutter build apk --release --dart-define=API_BASE=https://api.example.com` (needs Android SDK) / `flutter build ios` (needs a Mac). Android emulator talks to the host at `http://10.0.2.2:8000`.
- Tests: `cd frontend && flutter test` (API must be running with `seed_demo` data).

## What's built
- **Backend**: JWT auth with refresh rotation, accounts, transactions (UUID, soft delete, transfers excluded from spend analytics), budgets with alerts, goals, recurring, notifications, audit log, sync log, consistent errors, throttling; SQLite default, PostgreSQL via `DB_ENGINE=postgres`.
- **Offline-first**: local cache + pending queue; `POST /transactions/bulk-sync/` is idempotent on client UUIDs; success is decided by the server response, not connectivity. *Profile -> Simulate offline* to try it.
- **AI/ML**: TF-IDF + LogisticRegression categoriser with per-user personalisation; forecast (Ridge vs mean baseline, time-based backtest, 90% interval); anomaly detection (robust z-score + IsolationForest, "unusual" not "fraud"); receipt parser with duplicate detection and mandatory confirmation; assistant answering only from real analytics; health score; what-if simulator.
- **Admin console** (in the Flutter app, admin accounts only): aggregate stats, user enable/disable/premium, model versions, sync monitor, audit logs, feedback. Transaction details are never shown to admins.

## Limitations
- The categoriser is trained on a small synthetic set; its F1 is not real-world performance.
- Receipt scan takes pasted OCR text (on-device ML Kit not wired); server image OCR needs Tesseract.
- Offline storage uses shared preferences (not Drift/SQLite).
- Not implemented: Firebase push, Celery/Redis, S3, PDF/Excel export, email verification, 2FA, Google/biometric sign-in. Android APK needs the Android SDK (not installed here).
