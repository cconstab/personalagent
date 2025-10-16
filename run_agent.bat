@echo off
REM Start Agent Script
REM This script ensures the agent runs with the correct working directory and .env file

setlocal enabledelayedexpansion

echo 🤖 Starting Personal AI Agent...

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "AGENT_DIR=%SCRIPT_DIR%agent"

REM Check if agent directory exists
if not exist "%AGENT_DIR%" (
    echo ❌ Error: agent directory not found at %AGENT_DIR%
    exit /b 1
)

REM Change to agent directory
cd /d "%AGENT_DIR%"
echo 📁 Working directory: %CD%

REM Check if .env file exists
if not exist ".env" (
    echo ⚠️  Warning: .env file not found
    echo    Checking for .env.example...
    
    if exist ".env.example" (
        echo    Found .env.example - creating .env
        copy .env.example .env
        echo    ✅ Created .env from .env.example
        echo    ⚠️  Please edit agent\.env with your configuration before continuing
        echo.
        echo    Required settings:
        echo    - AT_SIGN=@your_agent_atsign
        echo    - AT_KEYS_FILE_PATH=C:\path\to\your\keys.atKeys
        echo    - OLLAMA_HOST=http://localhost:11434
        echo.
        exit /b 1
    ) else (
        echo ❌ Error: No .env or .env.example file found
        exit /b 1
    )
)

REM Verify required environment variables are set
echo 🔍 Checking configuration...

REM Read .env file and set variables
for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
    set "line=%%a"
    REM Skip comments and empty lines
    if not "!line:~0,1!"=="#" if not "%%a"=="" (
        set "%%a=%%b"
    )
)

set ERRORS=0

if "%AT_SIGN%"=="" (
    echo ❌ AT_SIGN not set in .env
    set /a ERRORS+=1
)

if "%AT_KEYS_FILE_PATH%"=="" (
    echo ❌ AT_KEYS_FILE_PATH not set in .env
    set /a ERRORS+=1
)

if not "%AT_KEYS_FILE_PATH%"=="" (
    if not exist "%AT_KEYS_FILE_PATH%" (
        echo ❌ Keys file not found at: %AT_KEYS_FILE_PATH%
        echo    You need to onboard your agent @sign first
        echo    See AGENT_SETUP.md for instructions
        set /a ERRORS+=1
    )
)

if "%OLLAMA_HOST%"=="" (
    echo ⚠️  OLLAMA_HOST not set, using default: http://localhost:11434
    set "OLLAMA_HOST=http://localhost:11434"
)

if %ERRORS% gtr 0 (
    echo.
    echo ❌ Configuration errors found. Please fix agent\.env
    exit /b 1
)

echo ✅ Configuration looks good
echo    Agent @sign: %AT_SIGN%
echo    Keys file: %AT_KEYS_FILE_PATH%
echo    Ollama: %OLLAMA_HOST%
if not "%CLAUDE_API_KEY%"=="" (
    echo    Claude: enabled
)
echo.

REM Check if Ollama is running
echo 🔍 Checking if Ollama is running...
curl -s %OLLAMA_HOST% >nul 2>nul
if %errorlevel% neq 0 (
    echo ⚠️  Warning: Cannot connect to Ollama at %OLLAMA_HOST%
    echo    The agent will still start but won't be able to process messages.
    echo.
    echo    To start Ollama:
    echo    - Using Docker: docker compose up -d ollama
    echo    - Or install Ollama locally: https://ollama.ai
    echo.
    timeout /t 3 /nobreak >nul
)

REM Get dependencies if needed
if not exist "pubspec.lock" (
    echo 📦 Getting dependencies...
    dart pub get
    echo.
)

REM Generate JSON serialization code
echo 🔧 Generating JSON serialization code...
call dart run build_runner build --delete-conflicting-outputs >nul 2>nul
echo ✅ Code generation complete
echo.

REM Start the agent
echo 🚀 Starting agent service...
echo    Press Ctrl+C to stop
echo.
dart run bin/agent.dart
