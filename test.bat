@echo off
REM Test script for the Private AI Agent

echo 🧪 Running Private AI Agent Tests
echo ==================================
echo.

REM Test agent service
echo Testing agent service...
cd agent
call dart pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to get agent dependencies
    exit /b 1
)

echo Running Dart tests...
call dart test
if %errorlevel% neq 0 (
    echo ❌ Agent tests failed
    exit /b 1
)

echo Running Dart analyzer...
call dart analyze
if %errorlevel% neq 0 (
    echo ⚠️  Dart analyzer found issues
)

cd ..

echo.
echo ✅ Agent service tests passed!
echo.

REM Test Flutter app
echo Testing Flutter app...
cd app
call flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to get app dependencies
    exit /b 1
)

echo Running Flutter tests...
call flutter test
if %errorlevel% neq 0 (
    echo ❌ Flutter tests failed
    exit /b 1
)

echo Running Flutter analyzer...
call flutter analyze
if %errorlevel% neq 0 (
    echo ⚠️  Flutter analyzer found issues
)

cd ..

echo.
echo ✅ Flutter app tests passed!
echo.

echo 🎉 All tests passed successfully!
