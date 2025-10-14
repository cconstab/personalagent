# Communication Flow: Flutter App ↔ Agent

This document explains how the Flutter app communicates with the Dart agent service using atPlatform's end-to-end encrypted messaging.

## 🏗️ Architecture Overview

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────────┐
│   Flutter App   │◄────────►│  atPlatform  │◄────────►│  Agent Service  │
│   (@user_sign)  │ encrypted│   (atServer) │ encrypted│ (@agent_sign)   │
└─────────────────┘          └──────────────┘          └─────────────────┘
```

## 🔐 Key Components

### 1. **atPlatform** (The Communication Layer)
- Provides end-to-end encrypted messaging
- Acts as the secure intermediary
- Both app and agent authenticate with their own @signs
- Messages are encrypted before transmission
- Only the recipient can decrypt

### 2. **Flutter App** (Client)
- **Location**: `/app/lib/services/at_client_service.dart`
- **Responsibilities**:
  - Initialize atClient with user's @sign
  - Send encrypted queries to agent
  - Listen for encrypted responses
  - Manage local message state

### 3. **Agent Service** (Server)
- **Location**: `/agent/lib/services/at_platform_service.dart`
- **Responsibilities**:
  - Initialize atClient with agent's @sign
  - Listen for incoming queries
  - Process queries (Ollama/Claude)
  - Send encrypted responses back

## 📨 Complete Message Flow

### 1️⃣ User Sends Query

```
User types in Flutter app
         ↓
AgentProvider.sendMessage()
         ↓
AtClientService.sendQuery()
         ↓
Creates AtKey with agent's @sign
         ↓
atPlatform encrypts with agent's public key
         ↓
Sends notification to agent's atServer
```

### 2️⃣ Agent Receives & Processes

```
Agent's notification listener triggers
         ↓
atPlatform decrypts with agent's private key
         ↓
AgentService.processQuery()
         ↓
Retrieves user context from atServer
         ↓
Ollama analyzes query + context
         ↓
Decides: Local (95%) or Hybrid (5%)
         ↓
Generates response
```

### 3️⃣ Agent Sends Response

```
AgentService creates ResponseMessage
         ↓
AtPlatformService.sendResponse()
         ↓
Creates AtKey with user's @sign
         ↓
atPlatform encrypts with user's public key
         ↓
Sends notification to user's atServer
```

### 4️⃣ User Receives Response

```
App's notification listener triggers
         ↓
atPlatform decrypts with user's private key
         ↓
AtClientService emits message via stream
         ↓
AgentProvider receives and adds to messages
         ↓
UI updates with new message
```

## 🔑 Key Implementation Details

### AtKey Structure
```dart
AtKey()
  ..key = 'query.12345'           // Unique message ID
  ..namespace = 'personalagent'   // App-specific namespace
  ..sharedWith = '@recipient'     // Only this @sign can decrypt
```

### Message Types
| Direction | Notification Pattern | Content |
|-----------|---------------------|---------|
| App → Agent | `query.*` | User query + metadata |
| Agent → App | `response.*` | AI response + source info |
| Storage | `context.*` | User's encrypted context data |

### Code Locations

**Flutter App:**
- Service: `app/lib/services/at_client_service.dart` ✅ Created
- Provider: `app/lib/providers/agent_provider.dart` ✅ Updated
- Models: `app/lib/models/message.dart` ✅ Ready

**Agent Service:**
- Platform: `agent/lib/services/at_platform_service.dart` ✅ Ready
- Orchestration: `agent/lib/services/agent_service.dart` ✅ Ready
- Models: `agent/lib/models/message.dart` ⏳ Needs JSON generation

## 🛡️ Security & Privacy

### End-to-End Encryption
1. Message created on device
2. JSON-encoded
3. Encrypted with recipient's public key (RSA 2048)
4. Transmitted encrypted
5. Decrypted with recipient's private key
6. Private keys never leave devices

### What atPlatform Sees
- ❌ Message content (encrypted)
- ❌ User context (encrypted)
- ✅ Sender/recipient @signs (metadata)
- ✅ Timestamp (metadata)

### What Claude Sees (5% of queries)
- ✅ Sanitized query only
- ❌ User's personal information
- ❌ Conversation history
- ❌ User context

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                    │
│                                                 │
│  User Input → AgentProvider → AtClientService  │
│       ↑                              ↓          │
│       └──────────Stream──────────────┘          │
└───────────────────────┬─────────────────────────┘
                        │ Encrypted
                        │ Notifications
                        ↓
              ┌──────────────────┐
              │   atPlatform     │
              │   (atServer)     │
              └──────────────────┘
                        ↓
┌───────────────────────┬─────────────────────────┐
│                  Agent Service                  │
│                                                 │
│  AtPlatformService → AgentService → Response   │
│         ↓                 ↓           ↓         │
│    Listener         Ollama/Claude   Storage    │
└─────────────────────────────────────────────────┘
```

## 🚀 Quick Start Guide

### 1. Configure Agent
```bash
cd agent
cp .env.example .env
# Edit .env with your @agent_sign and atKeys path
```

### 2. Start Agent
```bash
cd agent
dart run bin/agent.dart
# Should see: "Agent is now listening for queries..."
```

### 3. Run Flutter App
```bash
cd app
flutter run
```

### 4. Set Agent @sign in App
```dart
// In onboarding or settings
agentProvider.setAgentAtSign('@your_agent');
```

### 5. Send Test Message
- Type message in app
- Watch agent console for received query
- See response appear in app

## 📝 Implementation Checklist

### ✅ Completed
- [x] Message data models (app & agent)
- [x] AtClientService for Flutter app
- [x] AtPlatformService for agent
- [x] AgentProvider integration
- [x] UI components
- [x] Privacy indicators

### ⏳ Required Next
- [ ] Run `flutter pub get` in app/
- [ ] Run `dart pub get` in agent/
- [ ] Run `dart run build_runner build` in agent/ (JSON serialization)
- [ ] Complete atPlatform onboarding flow
- [ ] Add error handling
- [ ] Add offline support
- [ ] Add message persistence

## 🧪 Testing

### Manual Test
```bash
# Terminal 1: Start agent
cd agent && dart run bin/agent.dart

# Terminal 2: Run app
cd app && flutter run

# In app: Send "Hello agent"
# Expected: Response appears in 2-5 seconds
```

### Debug Logging
```dart
// Enable in at_client_service.dart
debugPrint('Sending: ${message.content}');
debugPrint('Received: ${notification.value}');
```

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "AtClient not initialized" | Call `initialize()` with @sign first |
| "Agent @sign not set" | Call `setAgentAtSign()` before sending |
| Messages not received | Check notification listener is active |
| Decryption failed | Verify atKeys files are correct |
| Connection timeout | Check internet, atServer availability |

## 📚 Resources

- [atPlatform Docs](https://docs.atsign.com)
- [Notification Service Guide](https://docs.atsign.com/sdk/guide/notifications/)
- [atClient API](https://pub.dev/packages/at_client)

---

**Bottom Line**: Communication happens through atPlatform's encrypted notification system. Messages are automatically encrypted/decrypted, ensuring complete privacy while enabling real-time bidirectional communication between the Flutter app and agent service.
