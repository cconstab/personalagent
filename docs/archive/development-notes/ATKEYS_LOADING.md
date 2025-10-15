# atKeys Loading Status

## ✅ SOLUTION FOUND - OS Keychain Pattern

**Status**: SOLVED! The secret is passing the `atsign` parameter to skip UI when keys are in keychain.

**The Discovery:**
NoPortsDesktop NEVER shows "upload .atKeys" UI because they check the OS keychain first:
```dart
// If @sign in keychain: Pass atsign parameter → NO UI, loads directly
await AtOnboarding.onboard(atsign: '@cconstab', config: ...)

// If @sign NOT in keychain: Don't pass atsign → Shows authentication options
await AtOnboarding.onboard(config: ...)
```

**Key Insights:**
1. `AtOnboarding.onboard(atsign: '@cconstab')` → Loads from OS keychain, **NO UI**!
2. `AtOnboarding.onboard()` without atsign → Shows authentication options menu
3. The "QR code and upload keys" UI is the **authentication options menu** - it's correct!
4. Once keys are in keychain, passing atsign parameter bypasses all UI
5. Working dependency versions: `at_onboarding_flutter: 6.1.7`, `showcaseview: 3.0.0`

See `ONBOARDING_PATTERN.md` for full details.

---

## Problem

When sending messages from the Flutter app to the @llama agent, we encounter a null pointer error:
```
Null check operator used on a null value
at at_chops.src.algorithm.at_algorithm_impl.AtChopsImpl._getSigningAlgorithmV2
```

This indicates encryption keys are not properly loaded into the AtChops signing layer.

## Root Cause

The atPlatform SDK requires keys to be:
1. Decrypted and parsed from .atKeys file
2. Stored in KeyChainManager
3. Initialized in AtChops for signing/encryption operations

Simply calling `AtClientManager.getInstance().setCurrentAtSign()` is NOT sufficient.

## Solution Attempts

### Attempt 1: Official AtOnboarding.onboard() Widget ✅ **SOLVED**
- **Goal**: Use `at_onboarding_flutter` package's official widget
- **Implementation**: Call `AtOnboarding.onboard()` which handles everything
- **Status**: ✅ **WORKING** - Found solution by matching NoPortsDesktop dependencies
- **Solution**: Use exact versions from working NoPortsDesktop app:
  ```yaml
  at_onboarding_flutter: 6.1.7
  showcaseview: 3.0.0  # as dependency_override
  intl: ^0.19.0
  ```
- **Key Discovery**: Widget doesn't ask for .atKeys upfront - it shows @sign input and handles all flows automatically!

### Attempt 2: Manual Key Loading ⏳
- **Goal**: Manually load .atKeys file and initialize AtChops
- **Status**: **NEEDS IMPLEMENTATION**
- **Required Steps**:
  1. Read .atKeys JSON file
  2. Parse encryption keys (pkamPublicKey, pkamPrivateKey, etc.)
  3. Create KeyChainManager instance
  4. Store keys using `storeAtSign()` and individual key storage methods
  5. Initialize AtClient with keys
  6. Initialize AtChops with signing keys

## Recommended Path Forward

### Option A: Fix Showcaseview Conflicts (Clean but Complex)
1. Try showcaseview from git trunk:
   ```yaml
   dependency_overrides:
     showcaseview:
       git:
         url: https://github.com/simformsolutions/flutter_showcaseview.git
         ref: main
   ```
2. Or fork at_onboarding_flutter and remove showcaseview dependency
3. Use official AtOnboarding.onboard() widget

### Option B: Implement Manual Key Loading (Pragmatic)
1. Keep custom onboarding dialog  
2. Get .atKeys file path from user
3. Properly load keys using this pattern:
   ```dart
   // Read .atKeys file
   final atKeysFile = File(atKeysPath);
   final atKeysString = await atKeysFile.readAsString();
   final atKeysJson = jsonDecode(atKeysString);
   
   // Get encryption keys
   final aesEncryptPrivateKey = atKeysJson['aesEncryptPrivateKey'];
   
   // Store in KeyChainManager
   final keyChainManager = KeyChainManager.getInstance();
   await keyChainManager.storeAtSign(atSign: atSign);
   await keyChainManager.storeCredentialToKeychain(
     atSign,
     secret: aesEncryptPrivateKey,
     appName: 'personalagent',
     option: KeyChainAccessOption.sameProcess,
   );
   
   // Initialize AtClient properly
   final atClientService = AtClientService();
   await atClientService.init(
     atSign: atSign,
     atClientPreference: atClientPreference,
     atKeysFilePath: atKeysPath, // Let SDK handle key loading
   );
   ```

### Option C: Use atPlatform CLI to Pre-load Keys (Quick Test)
1. Use `at_activate` CLI tool to onboard
2. Keys stored in `~/.atsign/keys/`  
3. App automatically picks up keys on initialization
4. **Limitation**: Not suitable for production distribution

## Next Steps

**Immediate**: Try Option B - Manual key loading with proper AtClient initialization

**File to Update**: `app/lib/screens/onboarding_screen.dart`

**Key Changes Needed**:
- Don't just set current @sign
- Actually initialize AtClient with keys using `AtClientService.init()`
- Ensure AtChops is initialized with signing keys
- Verify keys loaded: Check that `AtClientManager.getInstance().atClient.atChops` is not null

## Testing Procedure

1. Run agent: `cd agent && dart run bin/agent.dart`
2. Run app: `cd app && flutter run -d macos`  
3. Upload @cconstab .atKeys file from `~/.atsign/keys/@cconstab_key.atKeys`
4. Send test message: "Hello"
5. **Expected**: Agent receives and decrypts message successfully
6. **Success Criteria**: No null pointer errors, response appears in app

## References

- atPlatform SDK Documentation: https://pub.dev/documentation/at_client/latest/
- noports Reference Implementation: https://github.com/atsign-foundation/noports
- KeyChainManager API: https://pub.dev/documentation/at_client_mobile/latest/at_client_mobile/KeyChainManager-class.html
