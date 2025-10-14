# Quick Reference Guide

## 🚀 Getting Started

### First Time Setup
```bash
./setup.sh
```

### Start Services
```bash
# All services with Docker
docker compose up

# Or individually
cd agent && dart run bin/agent.dart
cd app && flutter run
```

## 📝 Common Commands

### Agent Service
```bash
cd agent

# Install dependencies
dart pub get

# Generate code (after model changes)
dart run build_runner build

# Run agent
dart run bin/agent.dart

# Run tests
dart test

# Check for issues
dart analyze
```

### Flutter App
```bash
cd app

# Install dependencies
flutter pub get

# Run on device
flutter run

# Run on specific device
flutter devices                 # List devices
flutter run -d chrome          # Web
flutter run -d macos           # macOS
flutter run -d iPhone          # iOS simulator

# Build for production
flutter build apk              # Android
flutter build ios              # iOS
flutter build macos            # macOS
flutter build web              # Web

# Run tests
flutter test

# Check for issues
flutter analyze
```

### Ollama
```bash
# Pull a model
docker compose exec ollama ollama pull llama2

# List installed models
docker compose exec ollama ollama list

# Run a model directly (for testing)
docker compose exec ollama ollama run llama2

# Check Ollama status
curl http://localhost:11434/api/tags
```

## 🔧 Configuration

### Agent Environment Variables
Edit `agent/.env`:
- `AT_SIGN` - Your agent's @sign
- `AT_KEYS_FILE_PATH` - Path to atKeys file
- `OLLAMA_HOST` - Ollama server URL
- `OLLAMA_MODEL` - Model to use
- `CLAUDE_API_KEY` - Claude API key (optional)
- `PRIVACY_THRESHOLD` - 0.0-1.0 (higher = more local)

### Docker Compose
Edit `docker-compose.yml` to change:
- Port mappings
- Volume mounts
- Environment variables

## 🐛 Troubleshooting

### Ollama not responding
```bash
# Check if running
docker compose ps

# View logs
docker compose logs ollama

# Restart
docker compose restart ollama
```

### atPlatform connection issues
- Verify your @sign is activated
- Check your atKeys file exists
- Ensure internet connection
- Check agent logs for details

### Model not found
```bash
# Pull the model
docker compose exec ollama ollama pull llama2

# Or pull a different model
docker compose exec ollama ollama pull mistral
```

### Agent errors
```bash
# View agent logs
docker compose logs agent

# Or run directly to see output
cd agent && dart run bin/agent.dart
```

## 📊 Available Models

Popular Ollama models:
- `llama2` (7B) - Good balance of speed/quality
- `llama2:13b` - Better quality, slower
- `mistral` (7B) - Fast and efficient
- `codellama` - Optimized for code
- `phi` (2.7B) - Very fast, smaller

See all at https://ollama.ai/library

## 🔐 Privacy Levels

Adjust `PRIVACY_THRESHOLD` in `agent/.env`:
- `1.0` - 100% local (never use Claude)
- `0.7` - Default (95% local, 5% Claude)
- `0.5` - Balanced (80% local, 20% Claude)
- `0.0` - Always ask Claude (not recommended)

## 📦 Project Structure
```
personalagent/
├── agent/          # Dart backend
├── app/            # Flutter app
├── docker-compose.yml
├── setup.sh        # Initial setup
└── test.sh         # Run all tests
```

## 🆘 Getting Help

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/cconstab/personalagent/issues)
- 💬 [Discussions](https://github.com/cconstab/personalagent/discussions)

## 📋 Development Workflow

1. Make changes to code
2. Run tests: `./test.sh`
3. Test locally: `dart run` or `flutter run`
4. Commit changes
5. Open Pull Request

## 🎯 Next Steps

After setup:
1. ✅ Get your @sign from https://atsign.com
2. ✅ Place atKeys file in `agent/keys/`
3. ✅ Configure `agent/.env`
4. ✅ Run `./setup.sh`
5. ✅ Start services
6. ✅ Open Flutter app and start chatting!
