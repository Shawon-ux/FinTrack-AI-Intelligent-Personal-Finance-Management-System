@echo off
REM FinTrack AI - local dev: API on :8000, Flutter web app on Chrome
cd /d "%~dp0backend"
python -m pip install -q -r requirements.txt
python manage.py migrate
python manage.py seed_demo
start "api" cmd /c "python manage.py runserver 8000"
cd /d "%~dp0frontend"
set PATH=C:\devlutterin;%PATH%
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
