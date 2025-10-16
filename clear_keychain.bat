@echo off
REM Script to clear Windows Credential Manager entries and app preferences
REM This does NOT delete your .atKeys file - you can use that to re-onboard

setlocal enabledelayedexpansion

echo 🔧 Clearing Windows Credential Manager entries and app data...

REM Get user's @sign
set /p ATSIGN="Enter your @sign (e.g., @cconstab): "

REM Remove @ if user included it
set "ATSIGN=%ATSIGN:@=%"
set "ATSIGN=@%ATSIGN%"

echo.
echo → Clearing Windows Credential Manager entries for %ATSIGN%...

REM Delete credential manager entries
REM The atPlatform SDK may store credentials under various names
cmdkey /delete:%ATSIGN% 2>nul
cmdkey /delete:"atSign:%ATSIGN%" 2>nul
cmdkey /delete:"LegacyGeneric:target=atSign:%ATSIGN%" 2>nul

echo → Clearing Flutter app data...

REM Clear Flutter app local storage
set "APP_DATA=%LOCALAPPDATA%\com.example.personalAgentApp"
if exist "%APP_DATA%" (
    rmdir /s /q "%APP_DATA%" 2>nul
)

set "ROAMING_DATA=%APPDATA%\com.example.personalAgentApp"
if exist "%ROAMING_DATA%" (
    rmdir /s /q "%ROAMING_DATA%" 2>nul
)

echo.
echo ✅ Credential Manager entries and app data cleared!
echo.
echo Your %ATSIGN%_key.atKeys file is still safe at:
echo   %USERPROFILE%\.atsign\keys\%ATSIGN%_key.atKeys
echo.
echo Now run: run_app.bat
echo.
echo The app will start fresh and you can onboard using:
echo   Option 1: Upload your %ATSIGN%_key.atKeys file ^(recommended^)
echo   Option 2: Use APKAM enrollment via @atsign Authenticator app
echo.
