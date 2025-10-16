@echo off
REM Private AI Agent - Quick Start Script

echo 🔐 Private AI Agent Setup
echo =========================
echo.

REM Check prerequisites
echo Checking prerequisites...

REM Check Docker
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Docker is not installed. Please install Docker first.
    exit /b 1
)

REM Check Dart
where dart >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Dart is not installed. Please install Dart SDK first.
    exit /b 1
)

REM Check Flutter
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter SDK first.
    exit /b 1
)

echo ✅ All prerequisites found!
echo.

REM Setup agent
echo Setting up agent service...
cd agent

if not exist ".env" (
    echo 📝 Creating .env file from template...
    copy .env.example .env
    echo ⚠️  Please edit agent\.env and configure your settings:
    echo    - AT_SIGN: Your agent's @sign
    echo    - AT_KEYS_FILE_PATH: Path to your atKeys file
    echo    - CLAUDE_API_KEY: Your Claude API key ^(optional^)
    echo.
    pause
)

echo 📦 Installing agent dependencies...
dart pub get

cd ..

REM Setup app
echo.
echo Setting up Flutter app...
cd app

echo 📦 Installing app dependencies...
flutter pub get

cd ..

REM Start Ollama with Docker
echo.
echo 🚀 Starting Ollama with Docker...
docker compose up -d ollama

echo.
echo ⏳ Waiting for Ollama to be ready...
timeout /t 5 /nobreak >nul

echo.
echo 📥 Pulling Ollama model ^(this may take a while^)...
docker compose exec ollama ollama pull llama2

echo.
echo ✅ Setup complete!
echo.
echo Next steps:
echo 1. Start the agent service:
echo    cd agent ^&^& dart run bin/agent.dart
echo.
echo 2. In another terminal, start the Flutter app:
echo    cd app ^&^& flutter run
echo.
echo Or use Docker Compose to run everything:
echo    docker compose up
echo.
echo For more information, see README.md
