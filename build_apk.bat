@echo off
REM Builds the Android APK. Usage: build_apk.bat http://192.168.0.101:8000   (or https://api.yourdomain.com)
REM Builds from an ASCII-only path (C:\dev\fintrack_frontend) because Gradle/Kotlin fail on the "-" in this folder name.
set API=%1
if "%API%"=="" set API=http://192.168.0.101:8000
set PATH=C:\dev\flutter\bin;%PATH%
set JAVA_HOME=C:\Program Files\Java\jdk-23
set ANDROID_HOME=C:\dev\android
robocopy "%~dp0frontend" C:\dev\fintrack_frontend /E /XD build .dart_tool .gradle /NFL /NDL /NJH /NJS /NP
echo kotlin.incremental=false>>C:\dev\fintrack_frontend\android\gradle.properties
cd /d C:\dev\fintrack_frontend
call flutter pub get
call flutter build apk --release --dart-define=API_BASE=%API%
if not exist "%~dp0dist" mkdir "%~dp0dist"
copy /Y build\app\outputs\flutter-apk\app-release.apk "%~dp0dist\FinTrack-AI.apk"
