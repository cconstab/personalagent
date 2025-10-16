# Troubleshooting: Conversations Not Appearing After Restart

**Issue**: Conversations disappear after restarting the app

## Quick Diagnostics

### Step 1: Check Debug Logs

Look for these log messages when the app starts:

```
🔍 Loading conversations from atPlatform...
   Current @sign: @youratsign
   Regex pattern: conversations\..*\.personalagent@youratsign
💾 Found X conversation keys
```

**If you see "Found 0 conversation keys"**:
- Conversations were never saved to remote server
- Using different @sign than before
- Keys expired (TTL exceeded 7 days)

### Step 2: Use Debug Tool

1. Open Settings (⚙️ icon)
2. Scroll to bottom
3. Tap **"Debug: List atPlatform Keys"**
4. Check console output

You should see:
```
🔍 DEBUG: Listing all keys for @youratsign
   Total keys: X
   Conversation keys: Y
   All conversation keys:
   - conversations.1234567890.personalagent@youratsign
   - conversations.0987654321.personalagent@youratsign
```

## Common Causes & Fixes

### ❌ Cause 1: Conversations Never Saved to Remote

**Symptom**: Conversations exist during session but disappear on restart

**Why This Happens**:
- Before the fix, conversations were saved to local cache only
- Local cache doesn't persist across app restarts
- Need `useRemoteAtServer = true` to push to remote server

**Fix**: Already implemented in latest version
```dart
// Now uses useRemoteAtServer = true
await _atClient!.put(
  key, 
  jsonData,
  putRequestOptions: PutRequestOptions()
    ..useRemoteAtServer = true,  // ← Critical!
);
```

**What To Do**:
1. Make sure you're running the latest code
2. Create a NEW conversation
3. Send messages
4. Check logs for: `💾 Saved conversation to atPlatform (remote)`
5. Check for: `Commit: success`
6. Restart app
7. Conversation should reappear

### ❌ Cause 2: Storage Service Not Initialized

**Symptom**: Errors like `ConversationStorageService not initialized`

**Why This Happens**:
- Race condition during app startup
- Messages arrive before initialization completes

**Fix**: Already implemented with lazy initialization
```dart
if (!_storageService.isInitialized) {
  await _storageService.initialize();
}
```

**What To Do**:
- This should be automatically fixed
- If still seeing errors, check for other issues

### ❌ Cause 3: Using Different @sign

**Symptom**: Conversations exist but not loading

**Why This Happens**:
- Logged in with different @sign
- Keys are stored per @sign
- Regex pattern filters by current @sign

**How To Check**:
```
🔍 Loading conversations from atPlatform...
   Current @sign: @newatsign  ← Different from before!
```

**Fix**: Log in with the same @sign you used when creating conversations

### ❌ Cause 4: TTL Expired

**Symptom**: Old conversations disappear

**Why This Happens**:
- Conversations have 7-day TTL
- If not updated for 7+ days, they auto-expire
- TTL is refreshed on: send message, receive response, rename, clear

**Fix**: This is by design for privacy
- Important conversations should be used regularly
- Consider exporting important data
- Future: Could add "pin" feature to extend TTL

### ❌ Cause 5: AtClient Not Syncing

**Symptom**: Keys saved but not appearing in getAtKeys()

**Why This Happens**:
- Network issues during save
- AtClient sync issues
- Remote secondary not responding

**How To Check**:
Look for commit result in logs:
```
💾 Saved conversation abc123 to atPlatform (remote)
   Commit: failed  ← Problem!
```

**Fix**:
1. Check network connection
2. Check atPlatform status
3. Try manual reload: Conversations → Pull to refresh (if implemented)
4. Or restart app to trigger new sync

## Testing Persistence

### Test Case 1: Basic Persistence

```bash
# 1. Start app
./run_app.sh

# 2. Create conversation
- Click + button
- Send message "Test persistence"
- Wait for response

# 3. Check logs
# Should see:
#   💾 Saved conversation to atPlatform (remote)
#   Commit: success

# 4. Kill app completely
# Stop from IDE or force quit

# 5. Restart app
./run_app.sh

# 6. Verify
# Should see conversation "Test persistence" in list
```

### Test Case 2: Cross-Device Sync

```bash
# Device 1:
- Create conversation "Device 1 Test"
- Send messages
- Check logs for "Commit: success"

# Device 2 (same @sign):
- Login
- Wait for sync
- Use debug tool to list keys
- Should see conversation keys
- Reload conversations if needed

# Expected:
# Conversation should appear on Device 2
```

## Debug Output Examples

### ✅ Good: Conversations Found

```
🔍 Loading conversations from atPlatform...
   Current @sign: @cconstab
   Regex pattern: conversations\..*\.personalagent@cconstab
💾 Found 3 conversation keys
   ✓ Loaded: What is cheese (2 msgs)
   ✓ Loaded: New Conversation (1 msgs)
   ✓ Loaded: Test sync (5 msgs)
💾 Successfully loaded 3 conversations
📚 Loaded 3 conversations from atPlatform
```

### ⚠️ Warning: No Conversations

```
🔍 Loading conversations from atPlatform...
   Current @sign: @cconstab
   Regex pattern: conversations\..*\.personalagent@cconstab
💾 Found 0 conversation keys
⚠️ No conversation keys found in atPlatform
   This could mean:
   1. First time running app (no conversations yet)
   2. Conversations not saved with useRemoteAtServer=true
   3. Different @sign than before
💾 Successfully loaded 0 conversations
```

### ❌ Error: Service Not Initialized

```
❌ Error loading conversations: Exception: ConversationStorageService not initialized
```
**Fix**: Should auto-initialize now, but if persists, report as bug

## Manual Recovery Steps

If conversations are truly lost:

### Option 1: Check Local Storage (Pre-Migration)

If you had conversations before the atPlatform migration:

```dart
// Old SharedPreferences keys (no longer used)
// Can't recover from this - was only in RAM during session
```

### Option 2: Check Hive Storage (Agent Side)

The agent stores conversation context:

```bash
# Check agent storage
ls -la agent/storage/hive/
cat agent/storage/hive/*.hive

# These are agent's copy of messages
# But won't restore app conversations
```

### Option 3: Start Fresh

Unfortunately, if conversations weren't saved to remote:
1. They can't be recovered
2. Create new conversations going forward
3. Latest code ensures persistence works

## Prevention

To ensure conversations persist going forward:

1. ✅ **Use Latest Code**: Includes `useRemoteAtServer = true` fix
2. ✅ **Check Logs**: Watch for "Commit: success" after sending messages
3. ✅ **Test Restart**: Restart app occasionally to verify persistence
4. ✅ **Same @sign**: Always log in with same @sign
5. ✅ **Regular Use**: Use conversations at least once per week (refreshes TTL)

## Getting Help

If conversations still not persisting:

1. **Run Debug Tool**: Settings → Debug: List atPlatform Keys
2. **Check Logs**: Copy relevant log output
3. **Provide Details**:
   - @sign used
   - When conversation was created
   - Log output from save operation
   - Log output from load operation
   - Debug tool output
4. **Report Issue**: Include all above information

## Related Documentation

- [Storage Fixes](STORAGE_FIXES.md) - Fix for remote sync issue
- [Initialization Fix](INITIALIZATION_FIX.md) - Fix for race condition
- [atPlatform Storage Summary](ATPLATFORM_STORAGE_SUMMARY.md) - How storage works
