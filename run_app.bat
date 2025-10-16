@echo off
REM Start Flutter App Script

echo 🚀 Starting Personal AI Agent App...

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "APP_DIR=%SCRIPT_DIR%app"

REM Check if app directory exists
if not exist "%APP_DIR%" (
    echo ❌ Error: app directory not found at %APP_DIR%
    exit /b 1
)

REM Change to app directory
cd /d "%APP_DIR%"
echo 📁 Working directory: %CD%

REM Get dependencies if needed
if not exist "pubspec.lock" (
    echo 📦 Getting dependencies...
    flutter pub get
    echo.
)

REM Run the Flutter app on Windows
echo 🎯 Running Flutter app on Windows...
flutter run -d windows
