# Multi-Conversation Support

**Status**: Implemented
**Date**: October 15, 2025

## Overview

Added full multi-conversation support to the Flutter app, allowing users to:
- Create and manage multiple conversation threads
- Switch between conversations seamlessly
- Rename and delete conversations
- Automatically generate conversation titles from first message

## New Features

### 1. **Multiple Conversations**
- Each conversation has its own message history
- Conversations are persisted to local storage
- Sorted by most recently updated

### 2. **New Conversation Button**
- Quick access button in the app bar (+ icon)
- Creates a new conversation and switches to it
- Auto-generates title from first message

### 3. **Conversations List Screen**
- View all conversations
- Shows message count and time since last update
- Active conversation is highlighted
- Swipe actions for rename/delete

### 4. **Conversation Management**
- **Create**: Tap + button in app bar
- **Switch**: Tap conversation in list
- **Rename**: Via popup menu on conversation tile
- **Delete**: Via popup menu with confirmation dialog
- **Auto-title**: Generated from first user message

## Implementation

### New Files

**`app/lib/models/conversation.dart`**
```dart
class Conversation {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  
  // Auto-generates title from first message
  void autoUpdateTitle() { ... }
  
  // Persisted to SharedPreferences
  factory Conversation.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

**`app/lib/screens/conversations_screen.dart`**
- Full-screen list of all conversations
- Card-based UI with conversation metadata
- Popup menu for actions (rename, delete)
- FAB for creating new conversation

### Updated Files

**`app/lib/providers/agent_provider.dart`**

Changed from single message list to multi-conversation support:

```dart
// Before
final List<ChatMessage> _messages = [];
List<ChatMessage> get messages => List.unmodifiable(_messages);

// After
final List<Conversation> _conversations = [];
String? _currentConversationId;
Conversation? get currentConversation => ...;
List<ChatMessage> get messages => currentConversation?.messages ?? [];
```

New methods:
- `createNewConversation()` - Create and switch to new conversation
- `switchConversation(id)` - Switch active conversation
- `deleteConversation(id)` - Remove conversation with confirmation
- `renameConversation(id, title)` - Update conversation title
- `_loadConversations()` - Load from SharedPreferences
- `_saveConversations()` - Persist to SharedPreferences

**`app/lib/screens/home_screen.dart`**

Added app bar actions:
```dart
actions: [
  IconButton(
    icon: Icons.chat_bubble_outline,
    onPressed: () => Navigator.push(...ConversationsScreen),
  ),
  IconButton(
    icon: Icons.add,
    onPressed: () => createNewConversation(),
  ),
  IconButton(icon: Icons.settings, ...),
]
```

## User Interface

### Home Screen

```
┌─────────────────────────────────┐
│ @myatsign → @llama      [💬][+][⚙]│  ← New buttons
├─────────────────────────────────┤
│                                 │
│  👤 User: Hi, my name is Bob    │
│                                 │
│  🤖 Agent: Hello Bob! How can   │
│           I help you today?     │
│                                 │
│  👤 User: What's my name?       │
│                                 │
│  🤖 Agent: Your name is Bob.    │
│                                 │
└─────────────────────────────────┘
```

### Conversations Screen

```
┌─────────────────────────────────┐
│ ← Conversations                 │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 💬 Hi, my name is Bob    [⋮]│ │ ← Active
│ │    4 messages • 2m ago      │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 💬 Tell me about AI      [⋮]│ │
│ │    8 messages • 1h ago      │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 💬 Help with code        [⋮]│ │
│ │    12 messages • 3d ago     │ │
│ └─────────────────────────────┘ │
│                                 │
│                          [+]    │ ← FAB
└─────────────────────────────────┘
```

## Data Persistence

Conversations are stored in `SharedPreferences` as JSON:

```json
{
  "conversations": [
    "{\"id\":\"1729...\",\"title\":\"Hi, my name is Bob\",\"messages\":[...],\"createdAt\":\"2025-10-15T...\",\"updatedAt\":\"...\"}"
  ],
  "currentConversationId": "1729..."
}
```

### Storage Keys
- `conversations` - List of JSON-encoded conversation objects
- `currentConversationId` - ID of active conversation

## Features Detail

### Auto-Generated Titles

Titles are automatically generated from the first user message:
- ≤50 chars: Use full message
- \>50 chars: First 47 chars + "..."
- Empty conversation: "New Conversation"

Updates automatically after first message is sent.

### Conversation Switching

When switching conversations:
1. Save current conversation state
2. Update `_currentConversationId`
3. Persist to SharedPreferences
4. Trigger UI update via `notifyListeners()`
5. Messages list automatically updates

### Context Continuity

Each conversation maintains its own complete message history:
- Agent receives full conversation history with each query
- Switching conversations = switching complete context
- No context bleeding between conversations

## Agent Integration

The stateless agent architecture works perfectly with multi-conversation:

```dart
// App sends conversation-specific history
final conversationHistory = currentConversation!.messages
    .sublist(0, messages.length - 1);

await _atClientService.sendQuery(
  userMessage,
  conversationHistory: conversationHistory, // ← Per-conversation
);
```

Each conversation is independent, so agents get the correct context regardless of which conversation is active.

## User Workflows

### Starting a New Conversation
1. Tap [+] button in app bar
2. New conversation created with title "New Conversation"
3. Automatically switched to new conversation
4. Send first message
5. Title auto-updates to first message content

### Switching Conversations
1. Tap [💬] button in app bar
2. See list of all conversations
3. Tap desired conversation
4. Automatically navigates back to home with that conversation

### Renaming a Conversation
1. Open conversations list
2. Tap [⋮] menu on conversation
3. Select "Rename"
4. Enter new title
5. Title updates immediately

### Deleting a Conversation
1. Open conversations list
2. Tap [⋮] menu on conversation
3. Select "Delete"
4. Confirm in dialog
5. Conversation removed
6. If current conversation deleted, switches to most recent or creates new

## Benefits

✅ **Organized Conversations** - Keep different topics separate
✅ **Context Switching** - Easily switch between different conversations
✅ **History Preservation** - All conversations saved and retrievable
✅ **Clean UI** - Active conversation shown in home screen
✅ **Intuitive Management** - Standard mobile UI patterns
✅ **Auto-Persistence** - Conversations saved automatically
✅ **Agent Compatible** - Works seamlessly with stateless agents

## Testing Checklist

- [x] Create new conversation
- [x] Send messages in new conversation
- [x] Title auto-updates from first message
- [x] Switch between conversations
- [x] Message history preserved per conversation
- [x] Rename conversation
- [x] Delete conversation
- [x] Delete active conversation (switches automatically)
- [x] App restart preserves conversations
- [x] Active conversation restored on restart
- [x] Agent receives correct conversation history
- [x] Multi-agent support still works

## Future Enhancements

Possible improvements:
1. **Search**: Search across all conversations
2. **Tags/Categories**: Organize conversations
3. **Export**: Export conversation to text/PDF
4. **Archive**: Archive old conversations
5. **Pin**: Pin important conversations to top
6. **Conversation Sharing**: Share conversations with other atSigns

## Technical Notes

### Performance
- Conversations loaded once at startup
- Saved after each message/action
- In-memory list for fast access
- JSON serialization is lightweight

### Storage Limits
- SharedPreferences has ~1MB limit on iOS
- Each conversation ~1-5KB depending on message count
- Can store 200-1000 conversations comfortably
- Consider migration to local database if needed

### State Management
- Provider pattern for reactive updates
- All conversation state in AgentProvider
- UI rebuilds automatically on changes
- Minimal prop drilling

## Conclusion

Multi-conversation support is fully implemented and integrated with the existing stateless agent architecture. Users can now maintain multiple conversation threads, each with its own complete context and history. The UI is clean, intuitive, and follows standard mobile patterns.

🎉 **Feature Complete and Ready for Use!**
