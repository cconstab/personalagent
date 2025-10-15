# Communication Flow - Fixed! ✅

## The Problem (FIXED)
The original code was confused about WHO sends AS whom. Now fixed!

## The Solution

### Correct Flow
```
User (@cconstab) → sends query → Agent (@llama)
Agent (@llama) → sends response → User (@cconstab)
```

### App (Flutter) Side

**Sending Queries TO Agent:**
```dart
// App (logged in AS @cconstab) sends query TO @llama
final atKey = AtKey()
  ..key = 'query.${message.id}'
  ..namespace = 'personalagent'
  ..sharedWith = _agentAtSign;  // TO @llama

await _atClient!.notificationService.notify(
  NotificationParams.forUpdate(atKey, value: jsonData),
);
```

**Listening for Responses FROM Agent:**
```dart
// App listens for messages FROM @llama
_atClient!.notificationService
  .subscribe(regex: 'message.*', shouldDecrypt: true)
  .listen((notification) {
    // notification.from will be @llama
    _handleNotification(notification);
  });
```

### Agent (Backend) Side

**Listening for Queries FROM Users:**
```dart
// Agent (logged in AS @llama) listens for queries FROM users
_atClient!.notificationService
  .subscribe(regex: 'query.*', shouldDecrypt: true)
  .listen((notification) async {
    // notification.from will be @cconstab
    final query = parseQuery(notification);
    await onQueryReceived(query);
  });
```

**Sending Responses TO Users:**
```dart
// Agent sends response TO user
final atKey = AtKey()
  ..key = 'message.${response.id}'
  ..namespace = 'personalagent'
  ..sharedWith = recipientAtSign;  // TO @cconstab

await _atClient!.notificationService.notify(
  NotificationParams.forUpdate(atKey, value: jsonData),
);
```

## Key Patterns

| Pattern | Direction | Sender | Receiver | Purpose |
|---------|-----------|--------|----------|---------|
| `query.*` | User → Agent | @cconstab | @llama | Send question to agent |
| `message.*` | Agent → User | @llama | @cconstab | Send answer to user |

## Who Uses Which @sign

### App (@cconstab)
- **Authenticated AS**: @cconstab (uses @cconstab's keys)
- **Sends TO**: @llama (via `sharedWith` parameter)
- **Receives FROM**: @llama (via notification.from)

### Agent (@llama)
- **Authenticated AS**: @llama (uses @llama's keys)
- **Receives FROM**: @cconstab (via notification.from)
- **Sends TO**: @cconstab (via `sharedWith` parameter)

## Processing Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User sends message in app                                    │
│    - App (AS @cconstab) creates query with key 'query.123'     │
│    - Sets sharedWith = '@llama'                                 │
│    - Sends encrypted notification TO @llama                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Agent receives notification                                   │
│    - Agent (AS @llama) listening for 'query.*' pattern         │
│    - Receives notification FROM @cconstab                       │
│    - Decrypts and parses query                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Agent processes query                                         │
│    - Retrieves context from atPlatform storage                  │
│    - Analyzes with Ollama (95% of queries)                      │
│    - OR uses hybrid mode with Claude (5% of queries)            │
│    - Creates response message                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Agent sends response                                          │
│    - Agent (AS @llama) creates message with key 'message.456'  │
│    - Sets sharedWith = '@cconstab'                              │
│    - Sends encrypted notification TO @cconstab                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. App receives response                                         │
│    - App (AS @cconstab) listening for 'message.*' pattern      │
│    - Receives notification FROM @llama                          │
│    - Decrypts and displays to user                              │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration in UI

Users can configure the agent @sign in Settings:
```
Settings → Agent @sign → Enter: @llama → Save
```

This tells the app:
- **WHERE** to send queries (TO @llama)
- **WHO** to expect responses from (FROM @llama)

## Testing the Flow

### 1. Start Agent
```bash
cd agent
dart run bin/agent.dart
```

Look for:
```
✅ Agent is now listening for queries...
```

### 2. Send Message from App
Type a message in the app, e.g., "Hello agent"

### 3. Check Agent Logs
You should see:
```
📨 Received query from @cconstab
Processing query: 123
⚡ Handling query from @cconstab
✅ Sent response to @cconstab
```

### 4. Check App
Response should appear in chat:
```
You: Hello agent
Agent: Hi! How can I help you today?
```
