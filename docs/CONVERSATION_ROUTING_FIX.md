# Conversation Routing Fix

## Problem

Messages were being dropped with errors like:
```
⚠️ WARNING: No conversation mapping found for message 1760829710607
   This message will be dropped to prevent cross-contamination
```

Additionally, conversations sometimes appeared and sometimes didn't, indicating race conditions.

### Root Causes

1. **In-Memory Mapping Lost**: The app used an **in-memory map** (`_queryToConversationMap`) to track which conversation a query belonged to, which was lost when app restarted or @sign switched.

2. **Wrong conversationId Location**: Agent put `conversationId` in `metadata` but app looked for it at top level of response.

3. **Race Condition - Conversations Not Loaded**: Message listener started immediately in constructor, but `_loadConversations()` was async and might not complete before responses arrived, causing messages to be dropped or added to wrong conversations.

## Solution

Make the system **stateless** and **race-condition free** by:

1. Including `conversationId` in query data and having agent echo it back
2. Extracting `conversationId` from correct location in response (`metadata`)
3. Queuing messages that arrive before conversations are loaded
4. Never falling back to wrong conversation - drop if conversation not found

### Changes Made

#### 1. App-Side Changes

**`app/lib/models/message.dart`**
- Added `conversationId` field to `ChatMessage`
- Updated `toJson()`, `fromJson()`, and `copyWith()` to handle conversationId

**`app/lib/services/at_client_service.dart`**
- Added `conversationId` parameter to `sendQuery()`
- Included conversationId in query data sent to agent
- **FIX**: Extract `conversationId` from `metadata` → `responseData['metadata']['conversationId']` ✅
- Added debug logging for conversationId

**`app/lib/providers/agent_provider.dart`**
- Pass `conversationId` when calling `sendQuery()`
- Updated message listener to use `message.conversationId` from response
- Kept fallback to in-memory map for backwards compatibility
- **FIX**: Queue messages in `_pendingMessages` if conversations not loaded yet ✅
- **FIX**: Process queued messages after conversations load ✅
- **FIX**: Never fall back to wrong conversation - drop if not found ✅
- Added comprehensive debug logging

#### 2. Agent-Side Changes

**`agent/lib/models/message.dart`**
- Added `conversationId` field to `QueryMessage`
- Added `conversationId` field to `ResponseMessage`
- Updated JSON serialization to include conversationId in both directions

**`agent/lib/services/agent_service.dart`**
- Updated all 6 `ResponseMessage` creations to include `conversationId: query.conversationId`
- This ensures all responses (error, streaming chunks, final) include the conversation ID

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User sends query in Conversation A                          │
│    conversationId = "conv-abc-123"                              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. App sends query to agent WITH conversationId                │
│    Query: {                                                     │
│      id: "1760829710607",                                       │
│      content: "what is a constable",                            │
│      conversationId: "conv-abc-123"  ← NEW                      │
│    }                                                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Agent receives query and processes it                       │
│    Extracts conversationId from query                           │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Agent sends response WITH conversationId echoed back        │
│    Response: {                                                  │
│      id: "1760829710607",                                       │
│      content: "A constable is a law enforcement officer...",    │
│      conversationId: "conv-abc-123"  ← ECHOED BACK              │
│    }                                                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. App receives response                                       │
│    - Extracts conversationId from response                      │
│    - Finds Conversation A using conversationId                  │
│    - Adds response to correct conversation                      │
│    - NO in-memory map needed! ✅                                │
└─────────────────────────────────────────────────────────────────┘
```

## Benefits

1. **Resilient to App Restarts**: Responses route correctly even if app restarted between query and response
2. **Resilient to @sign Switching**: Responses route correctly even if user switches @signs
3. **Stateless**: No need to maintain in-memory state
4. **Backwards Compatible**: Falls back to in-memory map if agent doesn't echo conversationId
5. **Multi-Device Support**: Works correctly across devices since routing info travels with the message

## Testing

To verify the fix:

1. **Test with app restart**:
   - Send a query
   - Restart the app before response arrives
   - Verify response appears in correct conversation

2. **Test with @sign switching**:
   - Send a query from @sign A
   - Switch to @sign B before response arrives
   - Switch back to @sign A
   - Verify response appears in correct conversation

3. **Test with delayed responses**:
   - Send multiple queries quickly
   - Verify all responses route to their correct conversations
   - No messages should be dropped

## Migration Notes

- **App and Agent must be updated together** for full functionality
- Old agents without conversationId will still work (backwards compatible via fallback map)
- Once both are updated, the in-memory map is only used as a fallback and can eventually be removed

## Related Files

- `app/lib/models/message.dart` - Added conversationId field
- `app/lib/services/at_client_service.dart` - Added conversationId to queries and responses
- `app/lib/providers/agent_provider.dart` - Uses conversationId from responses
- `agent/lib/models/message.dart` - Added conversationId to query and response models
- `agent/lib/services/agent_service.dart` - Echoes conversationId in all responses
