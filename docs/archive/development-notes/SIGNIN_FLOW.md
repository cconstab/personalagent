# Sign In Flow - Like NoPortsDesktop

## Overview
The app now supports a seamless sign-in flow where users with existing PKAM keys in their OS keychain can sign back in without uploading .atKeys files again.

## User Flows

### First Time User
```
Launch App
    ↓
Onboarding Slides
    ↓
"Get Started" button
    ↓
No keys in keychain detected
    ↓
SDK Onboarding (upload .atKeys)
    ↓
Keys stored in OS keychain
    ↓
Home Screen ✅
```

### Returning User (After Sign Out)
```
Sign Out
    ↓
Return to Onboarding Screen
    ↓
"Get Started" button
    ↓
Keys detected in keychain! 📦
    ↓
Dialog: "Welcome Back!"
    ↓
Shows: @cconstab (clickable)
    ↓
Tap @sign → Authenticate with keychain
    ↓
Home Screen ✅
```

### User with Multiple @signs
```
"Get Started"
    ↓
Dialog shows all @signs:
  • @cconstab
  • @alice
  • @bob
    ↓
Tap any @sign to authenticate
    ↓
Or "Use Different @sign" to add new one
```

## Code Changes

### 1. OnboardingScreen - Check for Existing Keys
**File**: `app/lib/screens/onboarding_screen.dart`

```dart
Future<void> _checkForExistingKeys() async {
  final keychainAtSigns = await KeychainUtil.getAtsignList() ?? [];
  
  if (keychainAtSigns.isNotEmpty) {
    debugPrint('📦 Found existing @signs: $keychainAtSigns');
    // User has keys - offer quick sign in
  } else {
    // No keys - clear stale state and show fresh onboarding
    await _clearSDKStateWithoutInitialization();
  }
}
```

### 2. Welcome Back Dialog
Shows existing @signs as clickable tiles:

```dart
void _showExistingKeysDialog(List<String> atSigns) {
  showDialog(
    builder: (context) => AlertDialog(
      title: const Text('Welcome Back!'),
      content: Column(
        children: [
          const Text('We found your existing @sign:'),
          for (final atSign in atSigns)
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(atSign),
              onTap: () => _authenticateWithExistingKeys(atSign),
            ),
        ],
      ),
    ),
  );
}
```

### 3. Authenticate with Existing Keys
No file upload needed - uses keychain:

```dart
Future<void> _authenticateWithExistingKeys(String atSign) async {
  // SDK automatically uses keys from keychain
  final result = await AtOnboarding.onboard(
    context: context,
    config: AtOnboardingConfig(...),
  );
  
  if (result.status == AtOnboardingResultStatus.success) {
    await _handleSuccessfulOnboarding(result.atsign!);
  }
}
```

### 4. Sign Out Flow
**File**: `app/lib/screens/settings_screen.dart`

```dart
onPressed: () async {
  await context.read<AuthProvider>().signOut();
  if (context.mounted) {
    // Return to onboarding screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
},
```

**File**: `app/lib/providers/auth_provider.dart`

```dart
Future<void> signOut() async {
  // Clear preferences only - keep PKAM keys in keychain!
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('atSign');
  await prefs.setBool('hasCompletedOnboarding', false);
  
  _isAuthenticated = false;
  notifyListeners();
}
```

## Key Benefits

1. **Quick Re-authentication**: No need to find and upload .atKeys file again
2. **Secure**: Keys stay in OS-level encrypted keychain
3. **Multi-@sign Support**: Can switch between multiple @signs
4. **User-Friendly**: Similar to NoPortsDesktop experience
5. **Persistent Keys**: Keys survive app uninstall (until keychain cleared)

## Testing

### Test Sign Out & Sign Back In
1. Sign in to the app with @cconstab
2. Go to Settings → Sign Out
3. App returns to onboarding screen
4. Tap "Get Started"
5. Should see dialog: "Welcome Back! We found your existing @sign: @cconstab"
6. Tap @cconstab
7. Should authenticate immediately without file upload ✅

### Test Fresh User
1. Clear keychain: `./clear_keychain.sh @cconstab`
2. Launch app
3. Tap "Get Started"
4. No dialog shown - goes directly to SDK onboarding
5. Upload .atKeys file
6. Keys stored in keychain for next time

### Test Multiple @signs
1. Add multiple .atKeys to keychain
2. Sign out
3. Tap "Get Started"
4. Should see all @signs listed
5. Can select any @sign to authenticate

## Logs to Watch

```
📦 Found existing @signs in keychain: [@cconstab]
🔐 Authenticating with existing keys for @cconstab
✅ Authenticated successfully
```

Or for new users:
```
ℹ️ No existing keys found - will show onboarding flow
🔥 CLEARING SDK STATE ON SCREEN INIT
```

## Related Files
- `app/lib/screens/onboarding_screen.dart` - Main sign-in flow
- `app/lib/screens/settings_screen.dart` - Sign out button
- `app/lib/providers/auth_provider.dart` - Auth state management
- `app/lib/utils/keychain_setup.dart` - Keychain utilities
