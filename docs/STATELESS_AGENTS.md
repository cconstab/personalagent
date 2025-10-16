# Stateless Agent Architecture

## Overview

The Personal AI Agent has been refactored to be **completely stateless**, enabling perfect load balancing across multiple agent instances without losing conversation context.

## Previous Architecture (Stateful)

**Problem:**
- Each agent stored Ollama conversation context in memory (`_conversationContexts`)
- When different agents handled sequential queries, context was lost
- Load balancing broke conversation continuity

**Example Failure:**
```
Query 1 → Agent 1 (stores context in memory)
Query 2 → Agent 2 (no access to Agent 1's context) ❌
Query 3 → Agent 3 (no access to previous contexts) ❌
```

## New Architecture (Stateless)

**Solution:**
- Agents do NOT store any conversation state
- App sends full `conversationHistory` with each query
- Each agent regenerates Ollama context from history on every request

**Benefits:**
✅ **Perfect Load Balancing** - Any agent can handle any query  
✅ **No Context Loss** - Full conversation history always available  
✅ **Agent Restarts Safe** - No state to lose  
✅ **Horizontal Scaling** - Add/remove agents freely  
✅ **Simpler Code** - No context management needed  

## How It Works

### Query Flow:

1. **App Sends Query**
   ```json
   {
     "id": "123",
     "content": "What's the weather?",
     "userId": "@user",
     "conversationHistory": [
       {"role": "user", "content": "Hi"},
       {"role": "assistant", "content": "Hello!"},
       {"role": "user", "content": "What's your name?"},
       {"role": "assistant", "content": "I'm your AI assistant!"}
     ]
   }
   ```

2. **Agent Receives Query**
   - Any agent can receive it (mutex coordination)
   - Extracts `conversationHistory` from query

3. **Agent Processes**
   - Builds full conversation prompt from history
   - Sends to Ollama (regenerates context)
   - Gets response

4. **Agent Sends Response**
   - Returns response to app
   - No state stored

5. **App Updates History**
   - Adds assistant's response to conversation history
   - Next query includes updated history

### Example:

```dart
// OLD (Stateful):
final existingContext = _conversationContexts[query.userId]; // ❌ Memory lookup
final response = await ollama.generate(
  prompt: prompt,
  context: existingContext, // ❌ Reuse stored tokens
);
_conversationContexts[query.userId] = response.context; // ❌ Store in memory

// NEW (Stateless):
final history = query.conversationHistory ?? []; // ✅ From app
final prompt = _buildPromptFromHistory(history, query.content); // ✅ Regenerate
final response = await ollama.generate(
  prompt: prompt,
  context: null, // ✅ No stored context
);
// ✅ No storage - app maintains state
```

## Code Changes

### Removed:
- ❌ `Map<String, List<int>> _conversationContexts` - In-memory storage
- ❌ `clearConversationContext()` - Context management methods
- ❌ `clearAllConversationContexts()` - Context management methods
- ❌ Context storage after each response

### Added:
- ✅ History-based prompt building
- ✅ `conversationHistory` parameter usage
- ✅ Stateless processing logic

## Load Balancing Benefits

### Before (Stateful):
```
Query 1 → Agent A → Stores context A
Query 2 → Agent B → No context! ❌
Query 3 → Agent C → No context! ❌
```

### After (Stateless):
```
Query 1 → Agent A → Uses history from app ✅
Query 2 → Agent B → Uses history from app ✅
Query 3 → Agent C → Uses history from app ✅
```

All agents have full context because the app is the source of truth!

## Performance Considerations

### Token Usage:
- **Before**: Stored Ollama tokens, reused between queries (fewer tokens)
- **After**: Regenerate context from history each time (more tokens)

**Trade-off Analysis:**
- ✅ **Pro**: Perfect load balancing, no lost context
- ⚠️ **Con**: Slightly more token processing by Ollama
- ✅ **Mitigation**: Ollama is local and fast, token regeneration is negligible

### Memory:
- **Before**: Stored contexts in memory for all active users
- **After**: Zero memory usage for conversation state
- ✅ **Result**: More efficient memory usage

## Testing

To verify stateless operation works correctly:

1. **Start multiple agents:**
   ```bash
   ./run_agent.sh -n agent1  # Terminal 1
   ./run_agent.sh -n agent2  # Terminal 2
   ./run_agent.sh -n agent3  # Terminal 3
   ```

2. **Send multi-turn conversation:**
   ```
   Query 1: "Hi, what's your name?"
   Query 2: "What did I just ask you?"
   Query 3: "Summarize our conversation"
   ```

3. **Verify:**
   - ✅ Each query handled by different agent (check logs)
   - ✅ Context maintained across all queries
   - ✅ Agent remembers previous exchanges

## App Requirements

The Flutter app must:

1. **Maintain Conversation History**
   - Store all user/assistant messages
   - Send complete history with each query

2. **Add Responses to History**
   - After receiving response, add it to history
   - Include in next query

3. **Query Format**
   ```dart
   final query = {
     'id': DateTime.now().millisecondsSinceEpoch.toString(),
     'content': userMessage,
     'userId': currentAtSign,
     'conversationHistory': _messageHistory.map((msg) => {
       'role': msg.isFromUser ? 'user' : 'assistant',
       'content': msg.content,
     }).toList(),
   };
   ```

## Migration Notes

### For Developers:

**What Changed:**
- Agents no longer store conversation state
- All context comes from `query.conversationHistory`
- No context management methods needed

**What Stayed The Same:**
- Query/response format
- Ollama and Claude integration
- Privacy filtering logic
- Mutex-based load balancing

**No Breaking Changes:**
- Backward compatible with existing apps
- Apps already send `conversationHistory`
- Just using it more effectively now

## Conclusion

The stateless agent architecture provides:
- ✅ **Perfect load balancing** without context loss
- ✅ **Simpler agent code** without state management
- ✅ **Horizontal scalability** with any number of agents
- ✅ **Reliability** with no state to lose or corrupt

This is the correct architecture for a distributed AI agent system!
