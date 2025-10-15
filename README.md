# 🔐 Private AI Agent with atPlatform

> **Your intelligent AI assistant that keeps your data private**

A privacy-first personal AI agent built with Flutter and Dart. Process 95% of queries locally with Ollama, use Claude only for external knowledge (with sanitization), and keep all your personal data encrypted end-to-end via atPlatform.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![atPlatform](https://img.shields.io/badge/atPlatform-E2E%20Encrypted-6C3483)](https://atsign.com)
[![Ollama](https://img.shields.io/badge/Ollama-Local%20LLM-000000)](https://ollama.ai)

**[🏗️ Architecture](ARCHITECTURE.md)** • **[🚀 Quick Start](#-quick-start)** • **[🔐 Privacy](ARCHITECTURE.md#privacy-architecture)** • **[📖 Docs](#-documentation)**

## 🌟 Key Features

- **🔒 Privacy-First**: 95% of queries processed locally with Ollama
- **🔐 End-to-End Encryption**: All data encrypted via atPlatform  
- **🧠 Hybrid Intelligence**: Local LLM + Cloud LLM (with sanitization) when needed
- **🎚️ Ollama-Only Mode**: Toggle for 100% local processing
- **📱 Cross-Platform**: Flutter app runs on macOS, iOS, Android, Linux, Windows, and Web
- **🎯 Smart Routing**: Automatically determines when external knowledge is needed
- **🛡️ Query Sanitization**: Removes personal info before any external API calls
- **✨ Transparent**: See exactly how each response was generated
- **🔑 Keychain Integration**: Seamless authentication with OS keychain

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (@your_sign)                                   │
│  ┌──────────┐  ┌──────────┐  ┌─────────────────────────┐  │
│  │  Chat UI │  │ Settings │  │ Ollama-Only Mode Toggle │  │
│  └──────────┘  └──────────┘  └─────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ Encrypted via atPlatform
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Agent Service (@agent_sign)                                │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │ Query Router │──▶ Privacy Analysis │                    │
│  └──────────────┘  └──────────────────┘                    │
│         │                    │                              │
│         ▼                    ▼                              │
│  ┌─────────────┐      ┌────────────┐                       │
│  │   Ollama    │      │   Claude   │ (Sanitized queries)  │
│  │ (Local LLM) │      │    API     │ (Only when needed)   │
│  └─────────────┘      └────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

📚 **[See detailed architecture →](ARCHITECTURE.md)**

## 🚀 Quick Start

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) 3.0+
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.0+
- [Docker](https://www.docker.com/get-started) (for Ollama)
- An [@sign](https://atsign.com) (free)
- [Claude API Key](https://console.anthropic.com) (optional)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/cconstab/personalagent.git
cd personalagent
```

2. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

3. Configure your credentials:
   - **Get 2 @signs** from [atsign.com](https://atsign.com/get-an-sign/) (free)
     - One for your agent (e.g., `@alice_agent`)
     - One for your app (e.g., `@alice`)
   - Edit `agent/.env` with your **agent's** @sign and keys path
   - Place your agent's `.atKeys` file in `agent/keys/`
   - Add Claude API key to `agent/.env` (optional, for hybrid mode)
   - Your app's @sign is set up during first launch (onboarding)
   - See [ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md) for details

4. Start the services:

   **Option A: Quick Start (Scripts)**
   ```bash
   # Terminal 1: Start agent
   ./run_agent.sh
   
   # Terminal 2: Start app  
   ./run_app.sh
   ```

   **Option B: Docker Compose**
   ```bash
   docker compose up
   ```

   **Option C: Manual**
   ```bash
   # Terminal 1: Start Ollama
   docker run -d -p 11434:11434 ollama/ollama
   
   # Terminal 2: Start agent
   cd agent && dart run bin/agent.dart
   
   # Terminal 3: Start app
   cd app && flutter run
   ```

## 📂 Project Structure

```
personalagent/
├── agent/                      # Dart backend service
│   ├── bin/agent.dart         # Main entry point
│   ├── lib/
│   │   ├── models/            # Data models
│   │   └── services/          # Core services
│   │       ├── agent_service.dart
│   │       ├── at_platform_service.dart
│   │       ├── ollama_service.dart
│   │       └── claude_service.dart
│   ├── pubspec.yaml
│   ├── .env.example
│   ├── Dockerfile
│   └── README.md
├── app/                        # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   ├── pubspec.yaml
│   └── README.md
├── docker-compose.yml
├── setup.sh
└── README.md
```

## 🔐 Privacy Model

### Three Modes of Operation

1. **🔒 Ollama-Only Mode** (100% Local)
   - User-enabled toggle in settings
   - Zero external API calls ever
   - All processing on your device or local server
   - Ideal for sensitive queries

2. **🎯 Hybrid Mode** (Default, 95% Local)
   - Intelligently routes queries
   - Local processing for personal/simple queries
   - External APIs only for current events/specialized knowledge
   - All personal data sanitized before external calls

3. **📊 What Never Leaves Your Device**
   - ✅ Your context and personal information
   - ✅ Conversation history  
   - ✅ Analysis and decision-making logic
   - ✅ Any data in Ollama-only mode

### Example: Privacy-Preserving Query

**Your Query**: "Should I accept this job offer at Acme Corp given my current salary of $120k?"

**Processing**:
1. 🧠 **Ollama analyzes**: Needs job market data
2. 🛡️ **Sanitize**: "Software engineer compensation analysis 2025"
3. ☁️ **Claude receives**: Generic market trends (no personal info)
4. 🔒 **Ollama combines**: Market data + YOUR salary + YOUR context  
5. ✅ **Response**: Personalized advice using your private data

**What Claude saw**: Generic market question  
**What Claude didn't see**: Your salary, company, personal situation

📚 **[Learn more about privacy →](ARCHITECTURE.md#privacy-architecture)**

## 🛠️ Development

### Agent Service (Dart)

```bash
cd agent

# Install dependencies
dart pub get

# Generate code
dart run build_runner build

# Run tests
dart test

# Run agent
dart run bin/agent.dart
```

See [agent/README.md](agent/README.md) for detailed documentation.

### Flutter App

```bash
cd app

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run app
flutter run

# Build for production
flutter build apk  # Android
flutter build ios  # iOS
flutter build web  # Web
```

See [app/README.md](app/README.md) for detailed documentation.

## 🔧 Configuration

### Agent Configuration

Edit `agent/.env`:

```env
# Required
AT_SIGN=@your_agent
AT_KEYS_FILE_PATH=./keys/@your_agent_key.atKeys
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=llama2

# Optional (for hybrid mode)
CLAUDE_API_KEY=your_api_key_here
CLAUDE_MODEL=claude-3-5-sonnet-20241022

# Tuning
PRIVACY_THRESHOLD=0.7  # 0.0-1.0, higher = more local processing
```

## 📊 Performance & Cost

| Metric | Value | Notes |
|--------|-------|-------|
| **Local Processing** | ~95% of queries | Ollama handles most requests |
| **External Queries** | ~5% | Only when external knowledge needed |
| **Latency (Local)** | 1-3 seconds | Ollama processing |
| **Latency (Hybrid)** | 3-5 seconds | Includes Claude API call |
| **Cost** | Minimal | Ollama free, Claude usage ~5% |
| **Privacy Score** | 95-100% | Depending on mode |

📚 **[See detailed performance metrics →](ARCHITECTURE.md#system-performance)**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [atPlatform](https://atsign.com) for end-to-end encrypted communication
- [Ollama](https://ollama.ai) for local LLM inference
- [Anthropic Claude](https://www.anthropic.com) for external knowledge
- [Flutter](https://flutter.dev) for cross-platform UI

## 🎓 Quick Reference

### Toggle Ollama-Only Mode
1. Open app settings (gear icon)
2. Enable "Use Ollama Only" toggle
3. All queries now 100% local (no external APIs)

### Check Agent Status
```bash
# View agent logs
tail -f agent/logs/agent.log

# Verify Ollama is running
curl http://localhost:11434/api/tags

# Test Claude API (optional)
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01"
```

### Common Issues
- **"No response from agent"** → Check agent is running: `./run_agent.sh`
- **"Ollama error"** → Verify Ollama: `curl http://localhost:11434/api/tags`
- **"Authentication failed"** → Check `.atKeys` file exists in correct location
- **"Keys not found in keychain"** → Re-run onboarding process in app

## 📞 Support

- 📖 [Full Documentation](ARCHITECTURE.md)
- 🐛 [Issue Tracker](https://github.com/cconstab/personalagent/issues)
- 💬 [Discussions](https://github.com/cconstab/personalagent/discussions)
- 📧 Email: [your-email@example.com]

## 🗺️ Roadmap

### ✅ Completed (v1.0)
- [x] Agent service with Ollama integration
- [x] Flutter cross-platform UI
- [x] Privacy-preserving hybrid query routing
- [x] atPlatform end-to-end encryption
- [x] Ollama-only mode toggle
- [x] Query sanitization
- [x] Auto-decrypting notifications
- [x] Keychain integration for seamless auth
- [x] Smart notification pattern (at_talk_gui)

### 🚧 In Progress (v1.1)
- [ ] Context management UI
- [ ] Enhanced error handling and retry logic
- [ ] Response streaming for real-time feedback

### 🔮 Future (v2.0+)
- [ ] Multi-model support (GPT-4, Gemini, local models)
- [ ] Voice input/output
- [ ] Mobile app store deployment
- [ ] Background autonomous tasks
- [ ] Plugin system for extensibility
- [ ] Privacy-preserving analytics

## 📖 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed system architecture with diagrams
- **[ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md)** - atPlatform integration guide
- **[OLLAMA_ONLY_MODE.md](OLLAMA_ONLY_MODE.md)** - Privacy mode documentation
- **[KEYCHAIN_AUTH.md](KEYCHAIN_AUTH.md)** - Authentication flow details
- **[agent/README.md](agent/README.md)** - Agent service documentation
- **[app/README.md](app/README.md)** - Flutter app documentation

---

**Mission**: Prove that AI can be both intelligent AND private by keeping personal data local/encrypted while selectively using cloud LLMs for external knowledge only.

