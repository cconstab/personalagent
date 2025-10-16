# Conversation Persistence Investigation

**Status**: Debugging 🔍  
**Date**: October 15, 2025

## Problem Report

User reported: "I have restarted the app but do not see the previous conversations"

## Investigation Steps Taken

### 1. Added Enhanced Debug Logging ✅

**File**: `app/lib/services/conversation_storage_service.dart`

Added detailed logging in `loadConversations()`:
```dart
debugPrint('🔍 Loading conversations from atPlatform...');
debugPrint('   Current @sign: $currentAtSign');
debugPrint('   Regex pattern: $regex');
debugPrint('💾 Found ${keys.length} conversation keys');

if (keys.isEmpty) {
  debugPrint('⚠️ No conversation keys found in atPlatform');
  debugPrint('   This could mean:');
  debugPrint('   1. First time running app (no conversations yet)');
  debugPrint('   2. Conversations not saved with useRemoteAtServer=true');
  debugPrint('   3. Different @sign than before');
}
```

This will help identify WHY conversations aren't loading.

### 2. Added Debug Tool ✅

**File**: `app/lib/services/conversation_storage_service.dart`

Created `debugListAllKeys()` method:
```dart
/// Debug method: List all atKeys to diagnose storage issues
Future<void> debugListAllKeys() async {
  // Lists ALL keys in atPlatform
  // Shows total count vs conversation-specific count
  // Prints first 10 keys and all conversation keys
}
```

**File**: `app/lib/providers/agent_provider.dart`

Exposed debug method:
```dart
Future<void> debugListAllKeys() async {
  if (!_storageService.isInitialized) {
    await _storageService.initialize();
  }
  await _storageService.debugListAllKeys();
}
```

**File**: `app/lib/screens/settings_screen.dart`

Added UI button in Settings:
```dart
ListTile(
  leading: const Icon(Icons.bug_report),
  title: const Text('Debug: List atPlatform Keys'),
  subtitle: const Text('Show what conversations are stored'),
  onTap: () async {
    final agent = context.read<AgentProvider>();
    await agent.debugListAllKeys();
  },
),
```

### 3. Created Troubleshooting Guide ✅

**File**: `docs/TROUBLESHOOTING_CONVERSATIONS.md`

Comprehensive guide covering:
- Quick diagnostic steps
- Common causes & fixes
- Debug output examples
- Manual recovery steps
- Prevention tips

## Next Steps for User

### Step 1: Check Current Logs

When you restart the app, look for these logs:

```
🔍 Loading conversations from atPlatform...
   Current @sign: @youratsign
   Regex pattern: conversations\..*\.personalagent@youratsign
💾 Found X conversation keys
```

**Share the output with me!**

### Step 2: Use Debug Tool

1. Open Settings (⚙️ gear icon in top right)
2. Scroll to bottom of settings
3. Tap **"Debug: List atPlatform Keys"**
4. Check the console/logs for output

You should see something like:
```
🔍 DEBUG: Listing all keys for @youratsign
   Total keys: X
   Conversation keys: Y
```

**Share this output with me too!**

### Step 3: Test New Conversation

1. Create a NEW conversation (+ button)
2. Send a message
3. Look for this in logs:
   ```
   💾 Saved conversation abc123 to atPlatform (remote)
      Title: New Conversation
      Messages: 1
      TTL: 7 days
      Commit: success  ← Most important!
   ```
4. **Restart the app**
5. Check if the NEW conversation appears

## Possible Causes

### Cause 1: Old Conversations Never Saved to Remote ❌

**If this is the issue**:
- Old conversations (before the fix) were only in local cache
- Local cache doesn't persist across app restarts
- They are unfortunately lost and can't be recovered
- NEW conversations created after the fix WILL persist

**How to confirm**:
- Debug tool shows 0 conversation keys
- But you remember creating conversations before

**Solution**:
- Start fresh with new conversations
- Latest code ensures they persist

### Cause 2: Using Different @sign ❌

**If this is the issue**:
- You logged in with @atsign1 before
- Now logged in with @atsign2
- Conversations are stored per @sign

**How to confirm**:
- Logs show different @sign than you remember using
- Debug tool shows keys exist but for different @sign

**Solution**:
- Log out and log back in with original @sign

### Cause 3: AtClient Sync Issue ⚠️

**If this is the issue**:
- Conversations were saved but commit failed
- Network issue during save
- Remote server not responding

**How to confirm**:
- Logs show: `Commit: failed`
- Or no commit status at all

**Solution**:
- Check network connection
- Try creating new conversation
- Watch for "Commit: success"

## What I Need From You

Please provide:

1. **Log Output When App Starts**:
   ```
   🔍 Loading conversations from atPlatform...
   (copy everything from this section)
   ```

2. **Debug Tool Output**:
   ```
   🔍 DEBUG: Listing all keys...
   (copy everything from debug tool)
   ```

3. **Info About Old Conversations**:
   - When were they created? (today? yesterday? last week?)
   - Same @sign or different?
   - Did you see "Commit: success" when creating them?

4. **Test New Conversation**:
   - Create a NEW conversation now
   - Send a message
   - Copy the save logs
   - Restart app
   - Does it reappear?

## Expected Behavior After Fixes

With all fixes in place:

1. **When Sending Message**:
   ```
   📤 Attempting to send message...
   💾 Saved conversation to atPlatform (remote)
      Commit: success ✓
   ✅ Query sent successfully!
   ```

2. **When Receiving Response**:
   ```
   📨 Received notification from @llama
   ✅ Response added to conversation: 123 (title)
   💾 Saved conversation to atPlatform (remote)
      Commit: success ✓
   ```

3. **When Loading After Restart**:
   ```
   🔍 Loading conversations from atPlatform...
      Current @sign: @youratsign
   💾 Found X conversation keys
      ✓ Loaded: Title 1 (X msgs)
      ✓ Loaded: Title 2 (X msgs)
   💾 Successfully loaded X conversations
   📚 Loaded X conversations from atPlatform
   ```

## Files Modified for Debugging

1. **`app/lib/services/conversation_storage_service.dart`**
   - Enhanced logging in `loadConversations()`
   - Added `debugListAllKeys()` method

2. **`app/lib/providers/agent_provider.dart`**
   - Added `debugListAllKeys()` public method

3. **`app/lib/screens/settings_screen.dart`**
   - Added "Debug: List atPlatform Keys" button

4. **`docs/TROUBLESHOOTING_CONVERSATIONS.md`**
   - Comprehensive troubleshooting guide

## Summary

We've added:
- ✅ Enhanced debug logging
- ✅ Debug tool UI button
- ✅ Comprehensive troubleshooting guide

Now we need your help to:
1. Collect diagnostic information
2. Determine root cause
3. Verify fix works for new conversations

Please run the debug steps above and share the output! 🔍
