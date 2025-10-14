#!/bin/bash

# Test script for the Private AI Agent

set -e

echo "🧪 Running Private AI Agent Tests"
echo "=================================="
echo ""

# Test agent service
echo "Testing agent service..."
cd agent
dart pub get
echo "Running Dart tests..."
dart test
echo "Running Dart analyzer..."
dart analyze
cd ..

echo ""
echo "✅ Agent service tests passed!"
echo ""

# Test Flutter app
echo "Testing Flutter app..."
cd app
flutter pub get
echo "Running Flutter tests..."
flutter test
echo "Running Flutter analyzer..."
flutter analyze
cd ..

echo ""
echo "✅ Flutter app tests passed!"
echo ""

echo "🎉 All tests passed successfully!"
