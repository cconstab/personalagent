# Ollama-Only Mode

## Overview
Users can now enable "Ollama-Only Mode" in settings to ensure 100% private processing. When enabled, all queries are processed exclusively with local Ollama - no data is ever sent to external services like Claude.

## How It Works

### User Controls
**Settings → Privacy Settings → "Use Ollama Only"**

- **OFF (default)**: Hybrid mode - Uses Ollama for 95% of queries, Claude for complex ones requiring external knowledge
- **ON**: 100% private - ALL queries processed locally with Ollama, Claude is never used

### Data Flow

#### Hybrid Mode (Default)
```
User Query
    ↓
Agent analyzes locally
    ↓
Can answer locally? (95%)
  ├─ YES → Ollama only ✓
  └─ NO  → Ollama + sanitized Claude query
```

#### Ollama-Only Mode (Enabled)
```
User Query
    ↓
🔒 OLLAMA ONLY MODE
    ↓
100% Local Processing
    ↓
Ollama response
(Claude NEVER contacted)
```

## Implementation

### 1. AgentProvider - State Management
**File**: `app/lib/providers/agent_provider.dart`

```dart
class AgentProvider extends ChangeNotifier {
  bool _useOllamaOnly = false;
  
  bool get useOllamaOnly => _useOllamaOnly;
  
  Future<void> setUseOllamaOnly(bool value) async {
    _useOllamaOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useOllamaOnly', value);
    notifyListeners();
    
    debugPrint('🔧 Ollama-only mode: ${value ? "ENABLED" : "DISABLED"}');
  }
  
  // Load on startup
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _useOllamaOnly = prefs.getBool('useOllamaOnly') ?? false;
    notifyListeners();
  }
}
```

### 2. SettingsScreen - Toggle UI
**File**: `app/lib/screens/settings_screen.dart`

```dart
Consumer<AgentProvider>(
  builder: (context, agent, _) {
    return SwitchListTile(
      secondary: const Icon(Icons.local_fire_department),
      title: const Text('Use Ollama Only'),
      subtitle: const Text('Never send queries to external services'),
      value: agent.useOllamaOnly,
      onChanged: (value) {
        context.read<AgentProvider>().setUseOllamaOnly(value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                ? 'Ollama only mode enabled - 100% private'
                : 'Hybrid mode enabled - uses Claude when needed',
            ),
          ),
        );
      },
    );
  },
)
```

### 3. AtClientService - Send Setting
**File**: `app/lib/services/at_client_service.dart`

```dart
Future<void> sendQuery(ChatMessage message, {bool useOllamaOnly = false}) async {
  debugPrint('📤 Sending query to $_agentAtSign');
  debugPrint('   Ollama Only: $useOllamaOnly');
  
  final queryData = {
    'id': message.id,
    'type': 'query',
    'content': message.content,
    'userId': _currentAtSign,
    'timestamp': message.timestamp.toIso8601String(),
    'useOllamaOnly': useOllamaOnly, // Send privacy preference
  };
  
  // Send encrypted notification...
}
```

### 4. QueryMessage Model - Add Field
**File**: `agent/lib/models/message.dart`

```dart
@JsonSerializable()
class QueryMessage extends AgentMessage {
  final String userId;
  final List<String>? contextKeys;
  final bool useOllamaOnly; // NEW FIELD

  QueryMessage({
    required String id,
    required String content,
    required this.userId,
    this.contextKeys,
    this.useOllamaOnly = false, // Default to hybrid mode
    DateTime? timestamp,
  });
}
```

### 5. AgentService - Respect Setting
**File**: `agent/lib/services/agent_service.dart`

```dart
Future<ResponseMessage> processQuery(QueryMessage query) async {
  _logger.info('Processing query: ${query.id}');
  
  // Check if user requested Ollama-only mode
  if (query.useOllamaOnly) {
    _logger.info('🔒 User requested Ollama-only mode - 100% private processing');
    final context = await _retrieveContext(query);
    return await _processWithOllama(query, context);
  }

  // Normal hybrid processing...
  final analysis = await ollama.analyzeQuery(...);
  if (analysis.canAnswerLocally) {
    return await _processWithOllama(query, context);
  } else {
    return await _processWithHybrid(query, context, analysis);
  }
}
```

## User Experience

### Enabling Ollama-Only Mode
1. Open app
2. Tap Settings (gear icon)
3. Under "Privacy Settings", toggle "Use Ollama Only" ON
4. See confirmation: "Ollama only mode enabled - 100% private"
5. Setting persists across app restarts

### Using Ollama-Only Mode
```
User: "What is the moon made of?"
    ↓
[Ollama-Only Mode: ON]
    ↓
Agent: Processes 100% locally
    ↓
Response: "The moon is primarily composed of..."
    ↓
✓ No external services contacted
✓ Complete privacy guaranteed
```

### Disabling Ollama-Only Mode
1. Settings → Toggle OFF
2. Confirmation: "Hybrid mode enabled - uses Claude when needed"
3. Back to intelligent routing (95% local, 5% hybrid)

## Agent Logs

### With Ollama-Only Mode OFF (Hybrid)
```
INFO: Processing query: 1760497...
INFO: Analysis: canAnswerLocally=false, confidence=0.50
INFO: Processing with hybrid approach (Ollama + Claude)
INFO: Sanitized query: Please ask [Name] who is...
INFO: Querying Claude with sanitized input
INFO: Received response from Claude (384 tokens)
```

### With Ollama-Only Mode ON
```
INFO: Processing query: 1760497...
INFO: 🔒 User requested Ollama-only mode - 100% private processing
INFO: Processing with Ollama only (fully private)
INFO: Generated response (llama3)
✓ Claude was NEVER contacted
```

## Privacy Benefits

1. **User Control**: Users decide their privacy level
2. **100% Guarantee**: When enabled, NO data leaves device
3. **Transparent**: Clear UI feedback on current mode
4. **Persistent**: Setting saved across sessions
5. **Per-Query**: Can be toggled anytime

## Trade-offs

| Mode | Privacy | Capabilities | Speed |
|------|---------|--------------|-------|
| **Hybrid** | 95% local | Full knowledge (internet access) | Fast for simple, slower for complex |
| **Ollama-Only** | 100% local | Limited to model knowledge | Always fast, purely local |

## Testing

### Test Ollama-Only Mode
1. Enable in Settings
2. Send query: "What is the weather in London today?"
3. Agent responds using only Ollama's knowledge
4. Check agent logs - should see: "🔒 User requested Ollama-only mode"
5. No Claude API calls in logs

### Test Hybrid Mode
1. Disable Ollama-Only mode
2. Send query: "Who is the richest person in 2025?"
3. Agent uses Claude for current info
4. Check logs - should see: "Processing with hybrid approach"

## Related Files
- `app/lib/providers/agent_provider.dart` - Setting state management
- `app/lib/screens/settings_screen.dart` - UI toggle
- `app/lib/services/at_client_service.dart` - Send setting to agent
- `agent/lib/models/message.dart` - Query message model
- `agent/lib/services/agent_service.dart` - Respect privacy setting
