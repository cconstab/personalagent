# Persistent Query Mapping Fix

## Problem Summary

After implementing stateless routing with `conversationId` carried in queries and responses, the app still experienced intermittent message routing failures when:
1. Switching between @signs (logout/login)
2. App restarts
3. The agent's response metadata sometimes arrived without `conversationId` (either older agent instance or retry/duplicate notifications)

**Symptoms:**
- Logs showed: `"ConversationId: null"` for some responses
- `_queryToConversationMap` was empty when responses arrived
- Messages dropped with warning: `"No conversation mapping found for message ..."`
- User reported: "works one or twice but then fail as I log out and back in again"

**Root Cause:**
The in-memory `_queryToConversationMap` was lost:
- When the `AgentProvider` was recreated (sign switch, app restart)
- Between sending the query and receiving the response if provider re-initialized
- The stateless approach (conversationId in response metadata) depended on the agent always echoing it correctly, but older agent instances or duplicate notifications sometimes lacked it

## Solution: Persistent Query Mapping

### Implementation

Added a **persistent short-lived mapping** to atPlatform that survives app restarts and @sign switches while still being temporary (1-hour TTL).

#### Changes to `at_client_service.dart`

Added two new methods:

```dart
/// Save a short-lived mapping from queryId -> conversationId to atPlatform
/// This helps recover routing after app restarts or provider re-creation
Future<void> saveQueryMapping(String queryId, String conversationId,
    {int ttlMilliseconds = 3600000}) async {
  if (_atClient == null) {
    debugPrint('⚠️ AtClient not initialized, cannot save query mapping');
    return;
  }

  try {
    final key = AtKey()
      ..key = 'mapping.$queryId'
      ..namespace = 'personalagent'
      ..sharedWith = null
      ..metadata = (Metadata()
        ..ttl = ttlMilliseconds  // 1 hour by default
        ..ttr = -1
        ..ccd = false);

    final putResult = await _atClient!.put(
      key,
      conversationId,
      putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
    );

    debugPrint('💾 Saved query mapping $queryId -> $conversationId');
    debugPrint('   Commit: ${putResult ? "success" : "failed"}');
  } catch (e, st) {
    debugPrint('❌ Failed to save query mapping: $e');
    debugPrint('StackTrace: $st');
  }
}

/// Retrieve a previously saved query->conversation mapping, or null
Future<String?> getQueryMapping(String queryId) async {
  if (_atClient == null) {
    debugPrint('⚠️ AtClient not initialized, cannot load query mapping');
    return null;
  }

  try {
    final key = AtKey()
      ..key = 'mapping.$queryId'
      ..namespace = 'personalagent'
      ..sharedWith = null;

    final result = await _atClient!.get(key);
    if (result.value != null) {
      debugPrint('🔍 Found remote mapping for $queryId -> ${result.value}');
      return result.value as String;
    }
  } catch (e, st) {
    debugPrint('❌ Failed to load query mapping $queryId: $e');
    debugPrint('StackTrace: $st');
  }

  return null;
}
```

**Key Design Choices:**
- **Self-key** (not shared): mapping belongs to the user's @sign only
- **1-hour TTL**: Long enough to survive app restarts and sign switches, short enough to auto-cleanup
- **useRemoteAtServer=true**: Ensures mapping is synced and available across sessions
- **Silent failure**: If save/get fails, we fallback to stateless routing (conversationId from response)

#### Changes to `agent_provider.dart`

**1. Save mapping after sending query:**

```dart
// Send message to agent via atPlatform with conversation context and ID
await _atClientService.sendQuery(
  userMessage,
  useOllamaOnly: _useOllamaOnly,
  conversationHistory: conversationHistory,
  conversationId: conversationIdForThisQuery,
);

// Persist the mapping to atPlatform as well (short TTL, helpful after restarts/sign switches)
await _atClientService.saveQueryMapping(
  userMessage.id,
  conversationIdForThisQuery,
);
debugPrint('💾 Persisted query mapping to atPlatform');
```

**2. Fetch mapping when needed:**

```dart
// Fallback: Check the in-memory map (for backwards compatibility with old agents)
conversationId ??= _queryToConversationMap[message.id];

if (conversationId == null) {
  debugPrint('❌ No conversationId found in map either for message ${message.id}');
  debugPrint('   Current map keys: ${_queryToConversationMap.keys.toList()}');
  debugPrint('🔍 Checking atPlatform for persisted mapping...');
  conversationId = await _atClientService.getQueryMapping(message.id);
  if (conversationId != null) {
    debugPrint('✅ Found persisted mapping: ${message.id} -> $conversationId');
  }
} else {
  debugPrint('📍 Found conversationId: $conversationId');
}
```

### Routing Strategy (Priority Order)

The app now has **three layers** of routing fallback:

1. **Stateless (Preferred)**: Extract `conversationId` from response `metadata['conversationId']`
   - Agent echoes conversationId in every response
   - No persistence needed
   - Works if agent is updated and running

2. **In-Memory Map (Fast fallback)**: Check `_queryToConversationMap[message.id]`
   - Set when query is sent
   - Lost on app restart / provider re-creation
   - Instant lookup

3. **Persistent Mapping (Robust fallback)**: Fetch from atPlatform via `getQueryMapping(message.id)`
   - Saved to atPlatform when query is sent
   - Survives app restarts and @sign switches
   - 1-hour TTL (auto-cleanup)
   - **NEW in this fix**

If all three fail, the message is dropped with a warning (strict matching to prevent misrouting).

## Testing

### Test Scenarios

1. **Normal flow (Stateless routing works)**:
   - Send message → query includes conversationId
   - Agent echoes conversationId in response metadata
   - App extracts conversationId from response → routes correctly
   - ✅ Expected: Message appears in correct conversation immediately

2. **App restart**:
   - Send message → query sent and mapping saved
   - Restart app (before response arrives)
   - Response arrives → conversationId in response OR fetched from atPlatform
   - ✅ Expected: Message routes correctly after restart

3. **@sign switch**:
   - Login as @alice, send message
   - Switch to @bob (conversations reload)
   - Switch back to @alice (conversations reload)
   - Response from @alice's query arrives
   - ✅ Expected: Message routes to correct conversation for @alice

4. **Old agent (no conversationId in response)**:
   - Agent running older code that doesn't echo conversationId
   - Send message → in-memory map set, persistent mapping saved
   - Response arrives without conversationId
   - App checks in-memory map → found
   - ✅ Expected: Message routes via in-memory map

5. **Old agent + app restart**:
   - Agent running older code
   - Send message → persistent mapping saved
   - Restart app before response arrives
   - Response arrives without conversationId
   - App checks in-memory map → empty
   - App fetches from atPlatform → found
   - ✅ Expected: Message routes via persistent mapping

### Manual Testing

1. **Restart agent** to ensure it's running latest code (echoes conversationId):
   ```bash
   cd agent
   ./run_agent.sh
   ```

2. **Restart app** and test normal flow:
   ```bash
   cd app
   ./run_app.sh
   ```

3. **Test @sign switching**:
   - Send message as @cconstab
   - Switch to @colin
   - Switch back to @cconstab
   - Verify message appears in correct conversation

4. **Monitor logs** for:
   - `💾 Saved query mapping ... -> ...`
   - `🔍 Checking atPlatform for persisted mapping...`
   - `✅ Found persisted mapping: ... -> ...`
   - `✅ Found conversation: ... (...)` (not dropped)

## Benefits

1. **Resilient to app lifecycle**: Mappings persist across restarts and sign switches
2. **Backwards compatible**: Works with old agents that don't echo conversationId
3. **Self-cleaning**: 1-hour TTL prevents atPlatform clutter
4. **Non-blocking**: Silent failures fallback to stateless routing
5. **Debuggable**: Verbose logging shows which fallback layer was used

## Cleanup

The persistent mappings auto-expire after 1 hour (TTL). No manual cleanup needed.

If you want to manually inspect/delete mappings:

```dart
// In agent_provider.dart, add debug method:
Future<void> debugListMappings() async {
  final keys = await _atClientService.getAtKeys(regex: 'mapping\\..*\\.personalagent');
  debugPrint('🔍 Query mappings: ${keys.length}');
  for (final key in keys) {
    final result = await _atClientService.get(key);
    debugPrint('   $key -> ${result.value}');
  }
}
```

## Related Documents

- [CONVERSATION_ROUTING_FIX.md](./CONVERSATION_ROUTING_FIX.md) - Initial stateless routing implementation
- [ATCLIENT_RACE_CONDITION_FIX.md](./ATCLIENT_RACE_CONDITION_FIX.md) - Race condition fixes
- [INITIALIZATION_FIX.md](./INITIALIZATION_FIX.md) - AtClient initialization fixes

## Status

✅ Implemented: Persistent mapping with 1-hour TTL  
✅ Compiled: No errors  
⏳ Testing: Manual testing needed (restart app, switch @signs)  
📝 Next: Monitor logs for routing behavior across sessions
