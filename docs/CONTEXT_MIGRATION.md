# Context Storage Migration Guide

## Overview

As of the latest update, the Personal Agent app now stores user context as **self-owned** data rather than sharing it with the agent @sign. This improves privacy and security.

## What Changed?

**Before:**
- Context was stored with `sharedWith = agentAtSign`
- Agent had direct access to your context data from atPlatform storage
- Context key: `user_context.personalagent@youratSign` (shared with agent)

**After:**
- Context is stored with `sharedWith = null` (self-owned)
- Agent receives context only through conversation history (sent by app)
- Context key: `user_context.personalagent@youratSign` (private)
- Agent cannot read your context directly from storage

## Why This Matters

### Privacy Benefits
1. **Data Ownership**: Your context stays private to your @sign
2. **Reduced Attack Surface**: Agent cannot access raw context data
3. **Clear Architecture**: App owns context, agent processes what it receives

### Functional Impact
- **No change in functionality**: Agent still receives and uses context
- **Context still works**: App sends enabled context with each query
- **Better security**: Context is never exposed to agent's storage

## Do I Need to Migrate?

### If you're a new user:
✅ **No action needed** - Your context is automatically stored as self-owned

### If you've used the app before this update:
⚠️ **Migration recommended** - You may have old shared context keys

## How to Migrate

### Option 1: Automatic (Easiest)

The app will automatically handle the migration:

1. **Update the app** to the latest version
2. **Use the app normally** - Next time you add/edit context, it will be saved as self-owned
3. **Old shared keys** will remain but won't be used

### Option 2: Manual (Complete Cleanup)

To completely remove old shared keys:

```bash
# From the project root directory
./migrate_context.sh @youratSign @agentAtSign

# Example
./migrate_context.sh @alice @agent
```

Or run the tool directly:

```bash
cd tools
dart pub get
dart run delete_shared_context.dart @youratSign @agentAtSign
```

## Migration Tool Details

### What the tool does:
1. ✅ Connects to your @sign using existing credentials
2. 🔍 Searches for old shared context keys
3. ℹ️ Shows what will be deleted
4. ⚠️ Asks for confirmation
5. 🗑️ Deletes the old shared key
6. ✨ Context will be recreated as self-owned when you next use the app

### Safety Features:
- **Non-destructive**: Only deletes old shared keys
- **Data preserved**: Context data remains in app's local state
- **Confirmation required**: Always asks before deleting
- **Reversible**: App recreates context automatically

### Requirements:
- You must have previously authenticated with your @sign
- Your `.atKeys` file must exist in `~/.atsign/keys/`
- Dart SDK must be installed

## Troubleshooting

### "Keys file not found"
**Problem**: Your @sign credentials aren't stored locally

**Solution**: 
1. Open the Personal Agent app
2. Sign in with your @sign
3. Try the migration again

### "No shared context keys found"
**Result**: ✅ You're all set! 

Either:
- You're a new user (context already self-owned)
- Migration already completed
- You haven't created any context yet

### Migration completed but context is empty
**Expected behavior**: Context will be recreated from app's local storage next time you:
- Add new context
- Edit existing context
- Send a query (app will recreate enabled context)

## Technical Details

### Context Storage Format

**Old Format (Shared):**
```dart
AtKey()
  ..key = 'user_context'
  ..namespace = 'personalagent'
  ..sharedWith = '@agent'  // ❌ Shared with agent
```

**New Format (Self-Owned):**
```dart
AtKey()
  ..key = 'user_context'
  ..namespace = 'personalagent'
  ..sharedWith = null  // ✅ Private to user
```

### How Context Reaches the Agent

**App-side injection** (implemented in `agent_provider.dart`):

1. User sends a query
2. App reads enabled context from local storage
3. App formats context as system message
4. App prepends context to conversation history
5. App sends query + conversation history to agent
6. Agent processes everything as normal conversation

**Agent never reads context from atPlatform directly**

## FAQ

**Q: Will I lose my context data?**
A: No. Your context remains in the app's local state and will be recreated as self-owned.

**Q: Do I need to restart the agent?**
A: No. The agent code hasn't changed - it never needed to read context directly.

**Q: Can I keep the old shared keys?**
A: Yes, but they won't be used. They'll just take up space on your secondary server.

**Q: What if I skip the migration?**
A: The app will work fine. New context is automatically self-owned. Old shared keys just remain unused.

**Q: Is this a breaking change?**
A: No. The app is backward compatible and handles both formats gracefully.

## Support

If you encounter issues:

1. Check the [tools/README.md](tools/README.md) for detailed tool documentation
2. Review the [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) guide
3. Check logs in the app for error messages
4. Open an issue on GitHub with details

## Version History

- **v1.0** (Oct 2025): Context now self-owned, migration tool released
- **v0.x** (Prior): Context shared with agent @sign
