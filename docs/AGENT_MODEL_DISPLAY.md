# Agent Model Display Feature

**Date**: October 15, 2025  
**Status**: Implemented ✅

## Feature Request

Display the actual AI model being used by the agent backend in the chat window, alongside the agent's name.

**Why**: The agent could be using different local models (e.g., llama3.2:3b, llama3.2:1b, mistral, etc.), so users want to see which specific model is responding.

## Implementation

### 1. Added `model` Field to Agent's ResponseMessage ✅

**File**: `agent/lib/models/message.dart`

```dart
@JsonSerializable()
class ResponseMessage extends AgentMessage {
  final ResponseSource source;
  final bool wasPrivacyFiltered;
  final double confidenceScore;
  final String? agentName;
  final String? model;  // ← NEW

  ResponseMessage({
    required String id,
    required String content,
    required this.source,
    this.wasPrivacyFiltered = false,
    this.confidenceScore = 1.0,
    this.agentName,
    this.model,  // ← NEW
    DateTime? timestamp,
  }) : super(
    // ...
    metadata: {
      // ...
      if (model != null) 'model': model,  // ← NEW
    },
  );
}
```

### 2. Agent Sends Model Name in Responses ✅

**File**: `agent/lib/services/agent_service.dart`

**Ollama-only responses**:
```dart
return ResponseMessage(
  id: query.id,
  content: response.response,
  source: ResponseSource.ollama,
  wasPrivacyFiltered: false,
  confidenceScore: 1.0,
  agentName: agentName,
  model: ollama.model,  // ← NEW: e.g., "llama3.2:3b"
);
```

**Hybrid responses (Ollama + Claude)**:
```dart
return ResponseMessage(
  id: query.id,
  content: finalResponse.response,
  source: ResponseSource.hybrid,
  wasPrivacyFiltered: true,
  confidenceScore: analysis.confidence,
  agentName: agentName,
  model: '${ollama.model} + ${claude!.model}',  // ← NEW: e.g., "llama3.2:3b + claude-3-5-sonnet-20241022"
);
```

**Error responses**:
```dart
final errorResponse = ResponseMessage(
  id: query.id,
  content: 'Sorry, I encountered an error...',
  source: ResponseSource.ollama,
  wasPrivacyFiltered: false,
  agentName: agentName,
  model: ollama.model,  // ← NEW
);
```

### 3. Added `model` Field to App's ChatMessage ✅

**File**: `app/lib/models/message.dart`

```dart
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final ResponseSource? source;
  final bool wasPrivacyFiltered;
  final bool isError;
  final String? agentName;
  final String? model;  // ← NEW

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.source,
    this.wasPrivacyFiltered = false,
    this.isError = false,
    this.agentName,
    this.model,  // ← NEW
  });

  Map<String, dynamic> toJson() => {
    // ...
    if (model != null) 'model': model,  // ← NEW
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      // ...
      model: json['model'] as String?,  // ← NEW
    );
  }
}
```

### 4. App Extracts Model from Agent Responses ✅

**File**: `app/lib/services/at_client_service.dart`

```dart
final message = ChatMessage(
  id: responseData['id'] ?? ...,
  content: responseData['content'] ?? '',
  isUser: false,
  timestamp: DateTime.parse(...),
  source: _parseSource(responseData['source']),
  wasPrivacyFiltered: responseData['wasPrivacyFiltered'] ?? false,
  agentName: responseData['agentName'] as String?,
  model: responseData['model'] as String?,  // ← NEW: Extract from response
);
```

### 5. UI Displays Model from Last Agent Message ✅

**File**: `app/lib/screens/home_screen.dart`

```dart
Builder(
  builder: (context) {
    // Get the model from the last agent message
    final lastAgentMessage = agent.messages
        .where((m) => !m.isUser && m.model != null)
        .lastOrNull;
    final modelInfo = lastAgentMessage?.model ?? 
        (agent.useOllamaOnly ? 'Llama' : 'Claude');
    
    return Text(
      '→ ${agent.agentAtSign} • $modelInfo',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
    );
  },
)
```

## Visual Result

### Before:
```
@cconstab
→ @llama
```

### After (with model info from agent):
```
@cconstab
→ @llama • llama3.2:3b
```

Or for hybrid mode:
```
@cconstab
→ @llama • llama3.2:3b + claude-3-5-sonnet-20241022
```

## How It Works

1. **Agent**: When generating a response, the agent includes which model it used:
   - OllamaService has a `model` field (e.g., "llama3.2:3b", "llama3.2:1b", "mistral:7b")
   - ClaudeService has a `model` field (e.g., "claude-3-5-sonnet-20241022")
   - AgentService passes this to ResponseMessage

2. **Transport**: The model name is sent via atPlatform in the message metadata

3. **App**: Receives the model name and stores it in ChatMessage

4. **UI**: Shows the model from the most recent agent response

## Benefits

✅ **Transparency**: Users know exactly which model is responding  
✅ **Dynamic**: If agent switches models, UI updates automatically  
✅ **Per-Message**: Each message can show different models (if agent changes config)  
✅ **Hybrid Support**: Shows combined model for hybrid responses  
✅ **Fallback**: Shows generic "Llama" or "Claude" if model info not available

## Example Model Names

### Ollama Models:
- `llama3.2:3b` - Llama 3.2 3B parameters
- `llama3.2:1b` - Llama 3.2 1B parameters  
- `llama3.1:8b` - Llama 3.1 8B parameters
- `mistral:7b` - Mistral 7B
- `codellama:7b` - CodeLlama 7B
- `phi3:mini` - Phi-3 Mini

### Claude Models:
- `claude-3-5-sonnet-20241022` - Claude 3.5 Sonnet (latest)
- `claude-3-opus-20240229` - Claude 3 Opus
- `claude-3-sonnet-20240229` - Claude 3 Sonnet

### Hybrid Mode:
- `llama3.2:3b + claude-3-5-sonnet-20241022`

## Configuration

The model used by the agent is set in the agent's environment/config:

```bash
# For Ollama
export OLLAMA_MODEL=llama3.2:3b

# Or in run script
./run_agent.sh -n myagent  # Uses model from agent config
```

Different agent instances can use different models, and users will see which one responded!

## Code Changes Summary

### Agent Files Modified:
1. **`agent/lib/models/message.dart`**
   - Added `model` field to ResponseMessage
   - Updated JSON serialization

2. **`agent/lib/services/agent_service.dart`**
   - Pass `ollama.model` when creating ResponseMessage
   - Pass `claude.model` for hybrid responses
   - Pass model in error responses

### App Files Modified:
1. **`app/lib/models/message.dart`**
   - Added `model` field to ChatMessage
   - Updated toJson() and fromJson()

2. **`app/lib/services/at_client_service.dart`**
   - Extract `model` from incoming message data

3. **`app/lib/providers/agent_provider.dart`**
   - Removed `currentModel` getter (no longer needed)

4. **`app/lib/screens/home_screen.dart`**
   - Display model from last agent message
   - Fallback to generic name if not available

### JSON Serialization:
- Regenerated agent's message.g.dart with `dart run build_runner build`

## Testing

### Test Case 1: Ollama Model Display
1. Start agent with specific Ollama model (e.g., llama3.2:3b)
2. Send a query from app
3. Check title bar shows: `→ @llama • llama3.2:3b`

### Test Case 2: Different Ollama Model
1. Restart agent with different model (e.g., mistral:7b)
2. Send a query
3. Check title bar updates to: `→ @llama • mistral:7b`

### Test Case 3: Hybrid Mode
1. Enable hybrid mode in agent
2. Send a query that triggers privacy filtering
3. Check title bar shows: `→ @llama • llama3.2:3b + claude-3-5-sonnet-20241022`

### Test Case 4: Multiple Agents with Different Models
1. Start agent1 with llama3.2:1b
2. Start agent2 with llama3.2:3b
3. Send queries
4. Verify UI shows model from whichever agent responded

## Compilation Status

✅ **Agent**: No issues found  
✅ **App**: 8 linter warnings (cosmetic, pre-existing)  
✅ All changes compile successfully

## Summary

**Feature**: Display agent's actual model in chat window  
**Implementation**: Model name flows from agent → atPlatform → app → UI  
**Benefit**: Users see exactly which model is responding to their queries  
**Dynamic**: Updates based on actual agent configuration  

The chat window now shows the real model being used by the agent backend! 🎉
