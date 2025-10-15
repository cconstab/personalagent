# Notification Auto-Decryption Fix

## Problem
Notifications were arriving at the agent encrypted, despite using `shouldDecrypt: true`. The SDK wasn't automatically decrypting them.

## Root Cause
Using complex dynamic key names (`query.${timestamp}`) instead of simple static key names prevented the SDK's auto-decryption from working properly.

## Solution
Follow the **at_talk_gui** pattern:
1. Use **simple static key names**: `query` instead of `query.${timestamp}`
2. Use **specific regex pattern**: `query.personalagent@` instead of `query.*`
3. Move message ID to **JSON payload** instead of key name
4. Set proper metadata: `isPublic: false, isEncrypted: true, namespaceAware: true`

## Code Changes

### App - Sending Notifications
**File**: `app/lib/services/at_client_service.dart`

```dart
// BEFORE (didn't work)
final atKey = AtKey()
  ..key = 'query.${message.id}'  // ❌ Complex dynamic key
  ..namespace = 'personalagent'
  ..sharedWith = _agentAtSign;

// AFTER (works!)
final metadata = Metadata()
  ..isPublic = false
  ..isEncrypted = true
  ..namespaceAware = true;

final atKey = AtKey()
  ..key = 'query'  // ✅ Simple static key
  ..namespace = 'personalagent'
  ..sharedWith = _agentAtSign
  ..metadata = metadata;

// Move ID to JSON payload
final queryData = {
  'id': message.id,  // ID in payload, not key
  'content': message.content,
  // ...
};
```

### Agent - Receiving Notifications
**File**: `agent/lib/services/at_platform_service.dart`

```dart
// BEFORE (didn't work)
.subscribe(regex: 'query.*', shouldDecrypt: true)  // ❌ Generic pattern

stream.listen((notification) {
  // Value arrives encrypted! 😞
  // Manual decryption attempts fail
});

// AFTER (works!)
.subscribe(regex: 'query.personalagent@', shouldDecrypt: true)  // ✅ Specific pattern

stream.listen((notification) {
  // Value auto-decrypted by SDK! 🎉
  final jsonData = json.decode(notification.value!);  // Just works!
});
```

## Why It Works

The atPlatform SDK's auto-decryption feature needs:

1. **Simple key names** for encryption key lookup
2. **Specific namespace patterns** to match shared keys
3. **Proper metadata** to signal encryption intent
4. **Consistent naming** between sender and receiver

Using complex dynamic keys (`query.12345678`) breaks the key lookup mechanism because:
- Each message creates a unique key
- SDK can't find the matching encryption key
- Transient notification keys don't persist in keystore

## Results

### Before Fix
```
INFO: 🎉 NOTIFICATION RECEIVED!
WARNING: ⚠️ Value appears to be encrypted
Value: uFlPsWToiec4Vm1CBcJF2XXgbRykb0ZwkV6KagcnvtP8...
```

### After Fix
```
INFO: 🎉 NOTIFICATION RECEIVED!
INFO: ✅ JSON decoded successfully (auto-decrypted!)
Value: {"id":"1760494671472","type":"query","content":"what is the moon"...}
```

## Testing

### Verify Auto-Decryption Working
1. Send message from app: "what is the moon"
2. Check agent logs for:
   ```
   ✅ JSON decoded successfully (auto-decrypted!)
   ```
3. Should NOT see:
   ```
   ⚠️ Value appears to be encrypted
   ```

### Real Example from Logs
```
INFO: 2025-10-14 19:17:52.574088: 🎉 NOTIFICATION RECEIVED!
INFO: 2025-10-14 19:17:52.574145:    From: @cconstab
INFO: 2025-10-14 19:17:52.574161:    Key: @llama:query.personalagent@cconstab
INFO: 2025-10-14 19:17:52.574202:    Value preview: {"id":"1760494671472","type":"query"...
INFO: 2025-10-14 19:17:52.574244: ✅ JSON decoded successfully (auto-decrypted!)
```

## Reference Implementation
Pattern based on: **cconstab/at_talk_gui**
- File: `lib/core/services/at_talk_service.dart`
- Pattern that works: `message.${namespace}@`
- Key naming: Simple static names (`message`)
- Result: Auto-decryption works flawlessly

## Related Files
- `app/lib/services/at_client_service.dart` - Notification sending
- `agent/lib/services/at_platform_service.dart` - Notification receiving
- `at_talk_gui` - Reference implementation
