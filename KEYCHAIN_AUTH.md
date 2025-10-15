# Automatic Keychain Authentication

## Overview
The app now automatically checks the macOS/iOS keychain for existing @sign keys and authenticates automatically if found. No need to go through onboarding again!

## How It Works

### First Time Setup
1. User goes through normal onboarding
2. SDK automatically stores keys in OS keychain
3. Keys persist forever in secure OS keychain

### Subsequent App Launches
1. **AuthProvider** checks keychain on startup
2. If @sign keys are found → **automatic authentication** ✅
3. If no keys found → shows onboarding screen

## Code Changes

### `app/lib/providers/auth_provider.dart`
```dart
Future<void> _checkAuthStatus() async {
  // Check OS keychain for existing @signs
  final keychainAtSigns = await KeychainSetup.listKeychainAtSigns();
  
  if (keychainAtSigns.isNotEmpty) {
    // Found keys! Try to authenticate automatically
    final atSign = keychainAtSigns.first;
    await _atClientService.initialize(atSign);
    _isAuthenticated = true;
  }
}
```

## User Experience

### With Keys in Keychain
```
App Launch
    ↓
🔍 Checking keychain...
    ↓
✅ Found @cconstab
    ↓
🔐 Authenticating...
    ↓
✅ Success!
    ↓
Home Screen (ready to chat)
```

### Without Keys
```
App Launch
    ↓
🔍 Checking keychain...
    ↓
ℹ️ No keys found
    ↓
Onboarding Screen
    ↓
Enter .atKeys file
    ↓
Keys stored in keychain
    ↓
Home Screen
```

## Security Benefits

1. **No More File Uploads**: Keys stay in keychain after first setup
2. **OS-Level Security**: Keychain uses hardware encryption (Secure Enclave on Apple Silicon)
3. **Biometric Protection**: Can be protected with Face ID/Touch ID
4. **Persistent**: Keys survive app uninstall/reinstall (unless keychain cleared)

## Testing

### Test Automatic Login
1. Ensure you've completed onboarding once with @cconstab
2. Force quit the app completely
3. Relaunch the app
4. Should go directly to Home Screen without showing onboarding ✅

### Test Fresh Onboarding
1. Clear keychain: `./clear_keychain.sh @cconstab`
2. Launch app
3. Should show onboarding screen
4. Upload .atKeys file
5. Next launch will auto-authenticate

## Logs to Watch

```
🔍 Checking for existing authentication...
📦 Found 1 @signs in keychain: [@cconstab]
✅ Found saved @sign @cconstab in keychain
🔐 Attempting automatic authentication...
✅ Automatic authentication successful for @cconstab
```

## Related Files
- `app/lib/providers/auth_provider.dart` - Main authentication logic
- `app/lib/utils/keychain_setup.dart` - Keychain utilities
- `clear_keychain.sh` - Script to clear keychain for testing
