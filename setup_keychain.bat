@echo off
REM Windows Credential Manager Setup for Personal Agent
REM This script helps import .atKeys file into Windows Credential Manager

setlocal enabledelayedexpansion

echo 🔐 Windows Credential Setup for Personal Agent
echo ===============================================
echo.

REM Get user's @sign
set /p ATSIGN="Enter your @sign (e.g., @cconstab): "

REM Remove @ if user included it
set "ATSIGN=%ATSIGN:@=%"
set "ATSIGN=@%ATSIGN%"

REM Default atKeys file location
set "ATKEYS_FILE=%USERPROFILE%\.atsign\keys\%ATSIGN%_key.atKeys"

echo.
echo Looking for .atKeys file at: %ATKEYS_FILE%
echo.

REM Check if .atKeys file exists
if not exist "%ATKEYS_FILE%" (
    echo ❌ Error: .atKeys file not found at: %ATKEYS_FILE%
    echo.
    echo Please ensure your .atKeys file is at:
    echo   %ATKEYS_FILE%
    echo.
    echo Or specify custom location:
    set /p CUSTOM_PATH="Enter full path to your .atKeys file (or press Enter to exit): "
    if "!CUSTOM_PATH!"=="" exit /b 1
    set "ATKEYS_FILE=!CUSTOM_PATH!"
    if not exist "!ATKEYS_FILE!" (
        echo ❌ Error: File not found at: !ATKEYS_FILE!
        exit /b 1
    )
)

echo ✅ Found .atKeys file: %ATKEYS_FILE%
echo.

REM The app will use the SDK's onboarding to import it
echo 📱 Starting Flutter app to import keys...
echo.
echo INSTRUCTIONS:
echo 1. App will open to onboarding screen
echo 2. Click 'Get Started'
echo 3. The SDK will show authentication options
echo 4. Click 'Upload .atKeys file'
echo 5. Select: %ATKEYS_FILE%
echo 6. Keys will be imported into Windows Credential Manager
echo 7. ✅ DONE! From now on, keys load automatically from credential manager
echo.
pause

REM Launch the app
call "%~dp0run_app.bat"
