# Private AI Agent App

Flutter-based mobile/desktop app for interacting with your private AI agent via atPlatform.

## Features

- **Privacy-First UI**: Clear indicators showing when queries use local vs external LLMs
- **End-to-End Encryption**: All communication via atPlatform
- **Beautiful Chat Interface**: Modern Material Design 3 UI
- **Context Management**: View, edit, and delete your stored context
- **Cross-Platform**: Works on iOS, Android, macOS, Linux, Windows, and Web

## Screenshots

*(Coming soon)*

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or later
- An @sign from [atsign.com](https://atsign.com)
- The agent service running (see `/agent` folder)

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
# For mobile
flutter run

# For desktop
flutter run -d macos
flutter run -d windows
flutter run -d linux

# For web
flutter run -d chrome
```

## First Time Setup

1. Launch the app
2. Follow the onboarding flow
3. Authenticate with your @sign
4. Configure your agent @sign (the agent service @sign)
5. Start chatting!

## Privacy Indicators

The app shows you exactly how each response was generated:

- 🖥️ **Local (Private)**: Processed entirely by local Ollama, 100% private
- ☁️ **Claude (Sanitized)**: External knowledge from Claude, personal info removed
- 🔀 **Hybrid**: Combination of Claude's knowledge + your private context
- 🛡️ **Privacy Filtered**: Personal information was sanitized before external query

## Project Structure

```
app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── message.dart
│   │   └── agent_response.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   └── agent_provider.dart
│   ├── screens/
│   │   ├── onboarding_screen.dart
│   │   ├── home_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   ├── chat_bubble.dart
│   │   └── input_field.dart
│   └── services/
│       └── at_client_service.dart (TBD)
├── test/
├── pubspec.yaml
└── README.md
```

## Development

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# iOS
flutter build ios

# Android
flutter build apk
flutter build appbundle

# Desktop
flutter build macos
flutter build windows
flutter build linux

# Web
flutter build web
```

## Integration Status

- [x] UI Framework
- [x] State Management (Provider)
- [x] Chat Interface
- [x] Privacy Indicators
- [ ] atPlatform Integration
- [ ] Agent Communication
- [ ] Context Management
- [ ] Push Notifications

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - See LICENSE file
