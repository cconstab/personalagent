# Response Routing to Correct Conversations

**Status**: Implemented ✅  
**Date**: October 15, 2025

## Problem

When using multi-conversation support, if a user:
1. Sends a query in Conversation A
2. Switches to Conversation B while waiting
3. Agent responds to the original query

Without proper routing, the response would incorrectly appear in Conversation B (the currently active one) instead of Conversation A (where the query was sent).

## Solution

Implemented **query-to-conversation mapping** that tracks which conversation each query belongs to and routes responses accordingly.

## How It Works

### 1. Track Query Origin

When sending a message:
```dart
// Map query ID → conversation ID
_queryToConversationMap[userMessage.id] = currentConversation.id;
```

### 2. Route Response to Correct Conversation

When receiving a response:
```dart
// Find which conversation this response belongs to
final conversationId = _queryToConversationMap[message.id];

// Add to the correct conversation (not necessarily the current one)
final conversation = _conversations.firstWhere((c) => c.id == conversationId);
conversation.messages.add(message);
```

### 3. Clean Up Mapping

After routing the response:
```dart
// Remove mapping (no longer needed)
_queryToConversationMap.remove(message.id);
```

## Example Scenario

### Without Routing (❌ Bug)
```
User in Conversation "Work Project":
  - Sends: "What's the status of the TPS reports?"
  
User switches to Conversation "Personal":
  - Sends: "What's the weather?"

Agent responds to work query:
  - Response appears in "Personal" ❌ WRONG!
```

### With Routing (✅ Fixed)
```
User in Conversation "Work Project":
  - Sends: "What's the status of the TPS reports?"
  - Query ID: 123
  - Mapped: 123 → "work-conv-id"
  
User switches to Conversation "Personal":
  - Current conversation changes

Agent responds to work query:
  - Message ID: 123
  - Looks up: 123 → "work-conv-id"
  - Adds response to "Work Project" ✅ CORRECT!
```

## Implementation Details

### Data Structure

```dart
class AgentProvider {
  // Conversations list
  final List<Conversation> _conversations = [];
  
  // Active conversation
  String? _currentConversationId;
  
  // Query routing map: message ID → conversation ID
  final Map<String, String> _queryToConversationMap = {};
}
```

### Message Flow

```
┌─────────────────────────────────────────────────────┐
│ 1. User sends message in Conversation A            │
│    Query ID: abc123                                 │
│    Conversation ID: conv-a                          │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 2. Store mapping                                    │
│    _queryToConversationMap["abc123"] = "conv-a"     │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 3. Send query to agent                              │
│    Query ID: abc123                                 │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 4. User switches to Conversation B                  │
│    Current conversation: conv-b                     │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 5. Agent responds                                   │
│    Response ID: abc123 (matches query)              │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 6. Lookup conversation ID                           │
│    abc123 → conv-a                                  │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 7. Add response to Conversation A                   │
│    (NOT Conversation B!)                            │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ 8. Clean up mapping                                 │
│    Remove abc123 from map                           │
└─────────────────────────────────────────────────────┘
```

## Edge Cases Handled

### 1. **No Mapping Found**
If somehow the mapping is missing:
```dart
if (conversationId != null) {
  // Route to correct conversation
} else {
  // Fallback: add to current conversation
  debugPrint('⚠️ No mapping found, using current conversation');
}
```

### 2. **Conversation Deleted**
If the original conversation was deleted before response arrives:
```dart
final conversation = _conversations.firstWhere(
  (c) => c.id == conversationId,
  orElse: () => _conversations.first, // Use first available
);
```

### 3. **Multiple Pending Queries**
Multiple queries can be tracked simultaneously:
```dart
_queryToConversationMap = {
  'query-1': 'conv-a',
  'query-2': 'conv-b',
  'query-3': 'conv-a',
};
// Each response routes to the correct conversation
```

## Benefits

✅ **Accurate Conversation History**
- Responses always appear in the correct conversation
- No cross-conversation pollution

✅ **Better User Experience**
- Users can switch conversations freely while waiting for responses
- No confusion about which conversation a response belongs to

✅ **Multiple Pending Queries**
- Send queries to multiple conversations
- All responses route correctly

✅ **Stateless Agent Compatible**
- Works perfectly with load-balanced agents
- Any agent can respond, routing happens in the app

## Logging

Helpful debug logs added:

```
📍 Mapped query abc123 → conversation work-project-id
✅ Response added to conversation: work-project-id (Work Project)
```

Or if fallback:
```
⚠️ No conversation mapping found for message abc123, adding to current conversation
```

## Testing

### Test Case 1: Basic Routing
```dart
1. Open Conversation A
2. Send message "Hello"
3. Switch to Conversation B
4. Agent responds to "Hello"
5. Verify response appears in Conversation A ✅
```

### Test Case 2: Multiple Conversations
```dart
1. Send message in Conversation A
2. Send message in Conversation B
3. Switch to Conversation C
4. Verify both responses appear in correct conversations ✅
```

### Test Case 3: Deleted Conversation
```dart
1. Send message in Conversation A
2. Delete Conversation A
3. Agent responds
4. Verify response appears in first available conversation ✅
```

## Code Locations

- **AgentProvider**: `/app/lib/providers/agent_provider.dart`
  - Mapping logic
  - Response routing
  - Cleanup

- **Message Model**: `/app/lib/models/message.dart`
  - Message ID used for matching

## Future Enhancements

Possible improvements:
1. **Timeout Cleanup**: Remove mappings after 5 minutes
2. **Visual Indicator**: Show badge when background conversation receives response
3. **Notification**: Alert user when inactive conversation gets response

## Conclusion

Responses now always appear in the correct conversation, regardless of which conversation is currently active. This ensures clean conversation histories and prevents user confusion. 🎯
