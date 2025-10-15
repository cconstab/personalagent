# macOS Permissions Configuration

## Overview

The Flutter app requires specific macOS entitlements to access:
- **Network** - To communicate with the atPlatform servers and the local agent
- **Files** - To select and read .atKeys files for authentication

## Entitlements Added

### Both Debug and Release Profiles

#### Network Access
```xml
<key>com.apple.security.network.client</key>
<true/>
```
- Allows outbound network connections
- Required for:
  - atPlatform server communication (root.atsign.org)
  - Sending messages to agent
  - Claude API calls (via agent)
  - Ollama local LLM communication (via agent)

#### User-Selected File Access
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```
- Allows reading/writing files user explicitly selects via file picker
- Required for:
  - Selecting .atKeys files during onboarding
  - Reading authentication keys
  - Future: Exporting chat history, backups, etc.

#### Downloads Folder Access
```xml
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```
- Allows reading/writing files in ~/Downloads
- Required for:
  - Quick access to .atKeys files (often downloaded here)
  - Exporting data to Downloads folder
  - Common location for user files

### Debug Profile Only

```xml
<key>com.apple.security.network.server</key>
<true/>
```
- Allows app to act as network server
- Required for Flutter DevTools and hot reload
- Already present in default configuration

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
```
- Allows Just-In-Time compilation
- Required for Dart VM in debug mode
- Already present in default configuration

## Files Modified

1. **`macos/Runner/DebugProfile.entitlements`**
   - Used for `flutter run` and debug builds
   - Includes all permissions plus JIT and network server for debugging

2. **`macos/Runner/Release.entitlements`**
   - Used for `flutter build macos --release`
   - Includes only production-necessary permissions
   - More restrictive for security

## Security Considerations

### Principle of Least Privilege
- Only requested permissions that are actually needed
- Used most restrictive permission levels possible
- User must explicitly select files (not full filesystem access)

### What We Didn't Request
❌ **Full Filesystem Access** - Not needed, user selects files explicitly  
❌ **Keychain Access** - Not needed, keys stored in app documents  
❌ **Camera/Microphone** - Not needed for current features  
❌ **Location Services** - Not needed  
❌ **Bluetooth** - Not needed  

### App Sandbox
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```
- App remains sandboxed for security
- Limited to explicit entitlements only
- Cannot access system or other apps' data without permission

## Testing Permissions

### Network Access Test
1. Run the app
2. Complete onboarding with your @sign
3. Send a message to the agent
4. Should successfully connect to atPlatform servers
5. Check agent logs for received messages

### File Access Test
1. Run the app
2. Start onboarding
3. Click "Select .atKeys File" button
4. Navigate to `~/.atsign/keys/` or `~/Downloads`
5. Select your `.atKeys` file
6. Should successfully read and authenticate

### Expected Behavior
✅ File picker opens without errors  
✅ Can navigate to any folder user has access to  
✅ Can select .atKeys file  
✅ App can read selected file contents  
✅ Network requests succeed (no "network denied" errors)  

## Troubleshooting

### "Operation not permitted" when selecting files
**Solution**: Verify `com.apple.security.files.user-selected.read-write` is in entitlements

### "Network connection failed" errors
**Solution**: Verify `com.apple.security.network.client` is in entitlements

### App crashes on launch
**Solution**: 
1. Clean build: `flutter clean`
2. Rebuild: `flutter run -d macos`
3. Check Console.app for sandboxing violation messages

### File picker doesn't show certain folders
**Note**: macOS sandbox restricts access to system folders. This is expected behavior.
- Can access: Documents, Downloads, Desktop, user-selected folders
- Cannot access: System folders, other users' folders, protected locations

## Future Permissions

If adding new features, you may need:

### Keychain Access (Secure Key Storage)
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.example.personalagent</string>
</array>
```
Use for: Storing sensitive keys in macOS Keychain instead of files

### URL Schemes (Deep Linking)
Configure in `Info.plist` for opening app via atProtocol URLs

### Background Modes
If you want the app to sync in background

## References

- [Apple App Sandbox Documentation](https://developer.apple.com/documentation/security/app_sandbox)
- [Entitlements Key Reference](https://developer.apple.com/documentation/bundleresources/entitlements)
- [Flutter macOS Setup](https://docs.flutter.dev/platform-integration/macos/building)

## Verification Commands

Check current entitlements in built app:
```bash
codesign -d --entitlements - \
  build/macos/Build/Products/Debug/personal_agent_app.app
```

View app sandbox violations:
```bash
log show --predicate 'subsystem == "com.apple.securityd"' \
  --style syslog --last 1h
```
