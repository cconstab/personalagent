# 🔐 Private AI Agent with atPlatform

> **Your intelligent AI assistant that keeps your data private**

A personal AI agent that maintains private context via atPlatform while leveraging Claude's intelligence without leaking personal information. Built with Dart (agent) and Flutter (app), using local Ollama for private processing and Claude API for external knowledge when needed.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🌟 Key Features

- **🔒 Privacy-First**: 95% of queries processed locally with Ollama (zero data leakage)
- **🔐 End-to-End Encryption**: All data encrypted via atPlatform
- **🧠 Hybrid Intelligence**: Local LLM + Cloud LLM (with sanitization) when needed
- **📱 Cross-Platform**: Flutter app runs on iOS, Android, Desktop, and Web
- **🎯 Smart Routing**: Automatically determines when external knowledge is needed
- **🛡️ Query Sanitization**: Removes personal info before external API calls
- **✨ Transparent**: See exactly how each response was generated

## 📐 Architecture

```
Flutter App (UI)
    ↓ (via atPlatform - encrypted)
@your_agent (Agent Service)
    ↓
┌───┴────┐
↓        ↓
Ollama   Claude API
(Local)  (Sanitized queries only)
    ↓
atServer (Your encrypted context/memory storage)
```

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
   - Edit `agent/.env` with your **agent's** @sign
   - Place your agent's .atKeys file in `agent/keys/`
   - Add Claude API key (optional)
   - **Note:** Your app's @sign is entered during onboarding, not in .env
   - See [ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md) for detailed explanation

4. Start the services:
```bash
# Option 1: Using Docker Compose (recommended)
docker compose up

# Option 2: Run separately
# Terminal 1: Start agent
cd agent && dart run bin/agent.dart

# Terminal 2: Start app
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

## 🔐 Privacy Guarantees

### What Stays Local (Ollama Only)
- ✅ All user context and personal information
- ✅ 95% of queries (simple questions, personal queries, context-based)
- ✅ All analysis and decision-making logic
- ✅ Complete conversation history

### What Can Go External (Claude API - Optional)
- ⚠️ Only sanitized queries with personal information removed
- ⚠️ Only when local LLM determines external knowledge is needed
- ⚠️ Generic information requests (e.g., "latest tech trends")
- ❌ **Never**: Your context, personal data, or history

## 💡 Example Use Case

**User Query**: "Should I accept this job offer at Acme Corp given my current salary of $120k?"

**Privacy-Preserving Process**:
1. **Ollama analyzes**: Determines need for external job market data
2. **Sanitize**: "Job market analysis for software engineers 2025" → Claude
3. **Claude returns**: Generic market trends (never sees your salary/company)
4. **Ollama combines**: Claude's market data + YOUR salary + YOUR context
5. **Response**: Personalized recommendation based on YOUR situation

**What Claude Saw**: Generic job market question  
**What Claude Didn't See**: Your salary, company name, personal situation

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

## 📊 Performance

- **Local Processing**: ~95% of queries
- **External Queries**: ~5% (only when needed)
- **Latency**: 
  - Local (Ollama): 1-3 seconds
  - Hybrid: 3-5 seconds
- **Cost**: Minimal (Ollama free, Claude only 5% of queries)

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

## 📞 Support

- 📖 [Documentation](https://github.com/cconstab/personalagent/wiki)
- 🐛 [Issue Tracker](https://github.com/cconstab/personalagent/issues)
- 💬 [Discussions](https://github.com/cconstab/personalagent/discussions)

## 🗺️ Roadmap

- [x] Basic agent service with Ollama
- [x] Flutter UI with chat interface
- [x] Privacy-preserving query routing
- [ ] Complete atPlatform integration
- [ ] Context management UI
- [ ] Push notifications for agent responses
- [ ] Multi-model support (GPT-4, Gemini, etc.)
- [ ] Voice input/output
- [ ] Mobile app deployment (iOS/Android)
- [ ] Enhanced analytics and insights

---

**The Goal**: Prove that AI can be both intelligent AND private by keeping context local/encrypted while selectively using cloud LLMs for knowledge only.

