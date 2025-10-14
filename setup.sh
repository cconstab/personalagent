#!/bin/bash

# Private AI Agent - Quick Start Script

set -e

echo "🔐 Private AI Agent Setup"
echo "========================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Dart
if ! command -v dart &> /dev/null; then
    echo "❌ Dart is not installed. Please install Dart SDK first."
    exit 1
fi

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter SDK first."
    exit 1
fi

echo "✅ All prerequisites found!"
echo ""

# Setup agent
echo "Setting up agent service..."
cd agent

if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit agent/.env and configure your settings:"
    echo "   - AT_SIGN: Your agent's @sign"
    echo "   - AT_KEYS_FILE_PATH: Path to your atKeys file"
    echo "   - CLAUDE_API_KEY: Your Claude API key (optional)"
    echo ""
    read -p "Press Enter after you've configured the .env file..."
fi

echo "📦 Installing agent dependencies..."
dart pub get

cd ..

# Setup app
echo ""
echo "Setting up Flutter app..."
cd app

echo "📦 Installing app dependencies..."
flutter pub get

cd ..

# Start Ollama with Docker
echo ""
echo "🚀 Starting Ollama with Docker..."
docker compose up -d ollama

echo ""
echo "⏳ Waiting for Ollama to be ready..."
sleep 5

echo ""
echo "📥 Pulling Ollama model (this may take a while)..."
docker compose exec ollama ollama pull llama2

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Start the agent service:"
echo "   cd agent && dart run bin/agent.dart"
echo ""
echo "2. In another terminal, start the Flutter app:"
echo "   cd app && flutter run"
echo ""
echo "Or use Docker Compose to run everything:"
echo "   docker compose up"
echo ""
echo "For more information, see README.md"
