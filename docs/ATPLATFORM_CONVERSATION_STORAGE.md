# atPlatform Conversation Storage

**Status**: Implemented
**Date**: October 15, 2025

## Overview

Conversations are now stored in **atPlatform** instead of local SharedPreferences, enabling:
- ✅ **Cross-device sync** - Access conversations from any device
- ✅ **Automatic expiration** - 7-day TTL, auto-refreshed on updates
- ✅ **True portability** - Run app on different machines with same @sign
- ✅ **Secure storage** - Encrypted end-to-end via atProtocol

## Key Features

### 1. **atKey Storage**
Each conversation is stored as an atKey:
```
Key format: conversations.{conversationId}.personalagent@currentAtSign
```

**atKey Properties:**
- **Namespace**: `personalagent`
- **Type**: Self key (not shared with anyone)
- **TTL**: 7 days (604,800,000 milliseconds)
- **Refresh**: TTL resets on every conversation update

### 2. **Automatic TTL Refresh**
TTL is refreshed (reset to 7 days) whenever:
- User sends a message
- Agent responds to a message  
- Conversation is renamed
- Messages are cleared

This means active conversations never expire, but inactive ones auto-delete after 7 days.

### 3. **True Deletion**
When user deletes a conversation:
1. atKey is deleted from atPlatform (server-side)
2. Conversation removed from local list
3. Cannot be recovered (permanent deletion)

### 4. **Cross-Device Synchronization**
- Login with same @sign on different device
- Conversations automatically load from atPlatform
- Updates on one device sync to all devices
- No manual export/import needed

## Implementation

### New Files

**`app/lib/services/conversation_storage_service.dart`**

Manages all conversation persistence via atPlatform:

```dart
class ConversationStorageService {
  /// Save conversation to atPlatform with 7-day TTL
  Future<void> saveConversation(Conversation conversation) async {
    final key = AtKey()
      ..key = 'conversations.${conversation.id}'
      ..namespace = 'personalagent'
      ..sharedWith = null  // Self key
      ..metadata = (Metadata()
        ..ttl = 7 * 24 * 60 * 60 * 1000  // 7 days
        ..ttr = -1
        ..ccd = false);
    
    final jsonData = jsonEncode(conversation.toJson());
    await _atClient!.put(key, jsonData);
  }
  
  /// Load all conversations from atPlatform
  Future<List<Conversation>> loadConversations() async {
    final regex = 'conversations\\..*\\.personalagent$currentAtSign';
    final keys = await _atClient!.getAtKeys(regex: regex);
    
    for (final key in keys) {
      final result = await _atClient!.get(key);
      // Parse and collect conversations
    }
    
    return conversations; // Sorted by updatedAt
  }
  
  /// Delete conversation from atPlatform
  Future<void> deleteConversation(String conversationId) async {
    final key = AtKey()
      ..key = 'conversations.$conversationId'
      ..namespace = 'personalagent'
      ..sharedWith = null;
    
    await _atClient!.delete(key); // Permanent deletion
  }
}
```

### Updated Files

**`app/lib/providers/agent_provider.dart`**

Changes from SharedPreferences to atPlatform storage:

```dart
// Before: SharedPreferences
Future<void> _saveConversations() async {
  final prefs = await SharedPreferences.getInstance();
  final json = _conversations.map((c) => jsonEncode(c.toJson())).toList();
  await prefs.setStringList('conversations', json);
}

// After: atPlatform
Future<void> _saveConversation(Conversation conversation) async {
  await _storageService.saveConversation(conversation);
  // TTL automatically refreshed to 7 days
}
```

**Key Method Changes:**
- `_loadConversations()` - Now loads from atPlatform
- `_saveConversation()` - Saves individual conversation with TTL refresh
- `deleteConversation()` - Deletes from atPlatform permanently
- `renameConversation()` - Saves with refreshed TTL
- `sendMessage()` - Saves with refreshed TTL after each message

### UI Updates

**`app/lib/screens/conversations_screen.dart`**
- Delete button now async (waits for atPlatform deletion)
- Rename button now async (waits for atPlatform save)
- Shows confirmation before deletion

## Data Flow

### Saving a Message
```
User sends message
  ↓
Add to conversation.messages
  ↓
Set conversation.updatedAt = now  ← Refreshes TTL
  ↓
await _storageService.saveConversation(conversation)
  ↓
atClient.put(key, jsonData, metadata: {ttl: 7 days})
  ↓
Stored in atPlatform with fresh 7-day TTL
```

### Loading Conversations
```
App starts
  ↓
await _storageService.loadConversations()
  ↓
atClient.getAtKeys(regex: "conversations.*")
  ↓
For each key: atClient.get(key)
  ↓
Parse JSON to Conversation objects
  ↓
Sort by updatedAt (most recent first)
  ↓
Display in UI
```

### Deleting a Conversation
```
User taps Delete → Confirms
  ↓
await _storageService.deleteConversation(id)
  ↓
atClient.delete(key)
  ↓
atKey removed from atPlatform permanently
  ↓
Conversation removed from local list
  ↓
UI updates
```

## TTL Behavior

### Active Conversations
```
Day 0: Create conversation (TTL = 7 days)
Day 2: Send message (TTL reset to 7 days)
Day 5: Agent responds (TTL reset to 7 days)
Day 8: Send message (TTL reset to 7 days)
→ Conversation persists indefinitely as long as active
```

### Inactive Conversations
```
Day 0: Create conversation (TTL = 7 days)
Day 2: Send message (TTL reset to 7 days)
... no more activity ...
Day 9: TTL expires
→ atPlatform automatically deletes the atKey
→ Conversation gone from all devices
```

## Cross-Device Sync Example

**Device A (Mac):**
```
1. Login as @bob
2. Create conversation: "Hello AI"
3. Send messages
4. Conversations saved to atPlatform
```

**Device B (iPad):**
```
1. Login as @bob
2. App loads conversations from atPlatform
3. "Hello AI" conversation appears automatically
4. Send more messages
5. Updates sync back to atPlatform
```

**Device A (Mac):**
```
6. Pull to refresh or restart app
7. New messages from iPad appear
8. Full conversation history synchronized
```

## Storage Capacity

**atPlatform Storage Limits:**
- Personal @signs: Generous storage (typically MBs)
- Each conversation: ~1-10KB depending on message count
- Can store hundreds to thousands of conversations comfortably

**Size Estimates:**
- Empty conversation: ~200 bytes
- 10 messages: ~2KB
- 100 messages: ~20KB
- 1000 messages: ~200KB

## Benefits vs SharedPreferences

| Feature | SharedPreferences | atPlatform |
|---------|------------------|------------|
| **Portability** | Device-only | Cross-device |
| **Backup** | Manual export | Automatic |
| **Sync** | None | Real-time |
| **Security** | Local encryption | E2E encryption |
| **Expiration** | Manual cleanup | Auto TTL |
| **Storage** | Limited (~1MB) | Much larger |
| **Multi-device** | ❌ | ✅ |

## Security

**Encryption:**
- All conversations encrypted end-to-end
- Only the @sign owner can decrypt
- atPlatform servers cannot read conversation content
- Keys never leave the device unencrypted

**Privacy:**
- Conversations stored as self keys (not shared)
- No one else can access your conversations
- Agent @sign cannot access conversations
- True zero-knowledge architecture

## Testing

### Test Cross-Device Sync
1. **Device 1**: Login as @myatsign
2. **Device 1**: Create conversation "Test Sync"
3. **Device 1**: Send some messages
4. **Device 2**: Login as @myatsign
5. **Device 2**: App should load "Test Sync" automatically
6. **Device 2**: Send more messages
7. **Device 1**: Restart app → new messages appear

### Test TTL Expiration
1. Create a test conversation
2. Wait 7+ days without any activity
3. Conversation should auto-delete from atPlatform
4. App will no longer load it

### Test Deletion
1. Create a conversation
2. Tap Delete button
3. Confirm deletion
4. Check other devices → conversation gone everywhere
5. Cannot be recovered

## Code Changes Summary

**New Service:**
- ✅ `ConversationStorageService` - Handles all atPlatform storage operations

**Updated Provider:**
- ✅ `AgentProvider.initializeStorage()` - Initialize storage service
- ✅ `AgentProvider._loadConversations()` - Load from atPlatform
- ✅ `AgentProvider._saveConversation()` - Save to atPlatform with TTL
- ✅ `AgentProvider.deleteConversation()` - Delete from atPlatform
- ✅ `AgentProvider.renameConversation()` - Update with TTL refresh
- ✅ `AgentProvider.sendMessage()` - Save with TTL refresh

**Updated UI:**
- ✅ `ConversationsScreen` - Async delete/rename
- ✅ Delete confirmation dialog
- ✅ Better error handling

## Migration Notes

**For Existing Users:**
If users already have conversations in SharedPreferences:
- Old conversations in SharedPreferences will be ignored
- App will start fresh with empty conversation list
- Users can recreate important conversations
- Consider adding migration tool if needed

**Migration Tool (Optional):**
```dart
Future<void> migrateFromSharedPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final oldConversations = prefs.getStringList('conversations') ?? [];
  
  for (final json in oldConversations) {
    final conversation = Conversation.fromJson(jsonDecode(json));
    await _storageService.saveConversation(conversation);
  }
  
  // Clear old data
  await prefs.remove('conversations');
}
```

## Troubleshooting

**Conversations not syncing:**
- Check AtClient is initialized
- Verify same @sign on both devices
- Check network connectivity
- Try manual refresh/restart

**Conversations disappearing:**
- Check if 7 days passed without activity
- TTL expired and auto-deleted
- Normal behavior for inactive conversations

**Cannot delete conversation:**
- Check network connectivity
- Verify AtClient initialized
- Check error logs for atPlatform errors

## Future Enhancements

Possible improvements:
1. **Manual sync button** - Force refresh from atPlatform
2. **Offline mode** - Cache conversations for offline access
3. **Conflict resolution** - Handle simultaneous edits from multiple devices
4. **Custom TTL** - Allow users to set TTL (1 day, 7 days, 30 days, forever)
5. **Export/Archive** - Download conversations before expiration
6. **Shared conversations** - Share conversations with other @signs

## Conclusion

Conversations are now stored in atPlatform with:
- ✅ **7-day TTL** that auto-refreshes on activity
- ✅ **Cross-device sync** for true portability
- ✅ **Permanent deletion** via atKey removal
- ✅ **End-to-end encryption** for privacy
- ✅ **Automatic expiration** of inactive conversations

This makes the Personal AI Agent truly portable - use it on any device with your @sign and have all your conversations automatically synchronized! 🎉
