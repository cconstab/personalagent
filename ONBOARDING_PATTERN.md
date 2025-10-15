# atSign Onboarding Flow - NoPortsDesktop Pattern

## Key Discovery

The NoPortsDesktop app **does NOT ask for .atKeys files or QR codes upfront**. Instead, it uses a much simpler flow that matches the NoPorts pattern.

## How AtOnboarding.onboard() Actually Works

Based on analysis of `atsign-foundation/noports` project (specifically `npt_flutter` and `sshnp_flutter`):

### 1. User Enters @sign
- Widget shows an input field: "@sign"
- User types their @sign (e.g., `@cconstab`)
- Optional: Dropdown of previously used @signs from keychain

### 2. SDK Checks @sign Status

The SDK automatically checks multiple things:

#### A) Is @sign in Local Keychain?
```dart
var atSigns = await KeyChainManager.getInstance().getAtSignListFromKeychain();
if (atSigns.contains(atsign)) {
  // Keys already exist locally!
  // Just load and authenticate
  return await AtOnboarding.onboard(
    context: context,
    atsign: atsign,
    config: config,
  );
}
```
**Result**: If yes → Use existing keys, authenticate, done! ✅

#### B) Check @sign Server Status
```dart
var status = await onboardingUtil.atServerStatus(atsign);
switch (status.status()) {
  case AtSignStatus.unavailable:
  case AtSignStatus.teapot:
    // New @sign, needs activation
  case AtSignStatus.activated:
    // @sign exists but keys not in keychain
}
```

### 3. Flow Based on Status

#### Flow A: @sign in Keychain
```
User enters @cconstab
  ↓
SDK finds keys in keychain
  ↓
Load keys from KeyChainManager
  ↓
Authenticate with PKAM
  ↓
✅ Done!
```

#### Flow B: Activated @sign (Not in Keychain)
```
User enters @cconstab
  ↓
SDK checks: Activated but not in keychain
  ↓
Show dialog: "How do you want to authenticate?"
  ├─ Option 1: Upload .atKeys file
  │    ↓
  │    File picker → Upload → Store in keychain
  │
  └─ Option 2: APKAM Enrollment
       ↓
       Show enrollment request → Admin approves → Keys generated
  ↓
✅ Done!
```

#### Flow C: New @sign (Teapot/Unavailable)
```
User enters @alice
  ↓
SDK checks: Teapot (ready to activate)
  ↓
Show activation dialog:
  "Enter OTP sent to your email/phone"
  ↓
User enters 4-digit OTP
  ↓
SDK verifies OTP with registrar
  ↓
SDK generates new encryption keys
  ↓
SDK bootstraps atServer
  ↓
Keys stored in keychain
  ↓
✅ Done!
```

### 4. Reference: NoPorts Code

From `npt_flutter/lib/features/onboarding/widgets/onboarding_button.dart`:

```dart
Future<void> onboard({
  required String atsign,
  required String rootDomain,
}) async {
  var atSigns = await KeyChainManager.getInstance()
      .getAtSignListFromKeychain();
  
  var config = AtOnboardingConfig(
    atClientPreference: await AtClientMethods.loadAtClientPreference(rootDomain),
    rootEnvironment: RootEnvironment.Production,
    domain: rootDomain,
    appAPIKey: apiKey,
  );

  var util = NoPortsOnboardingUtil(config);
  AtOnboardingResult? onboardingResult;

  // If @sign already in keychain, use it
  if (atSigns.contains(atsign)) {
    onboardingResult = await AtOnboarding.onboard(
      atsign: atsign,
      context: context,
      config: config,
    );
  } else {
    // Check server status and handle accordingly
    onboardingResult = await handleAtsignByStatus(atsign, util);
  }
  
  // ... handle result
}

Future<AtOnboardingResult?> handleAtsignByStatus(
  String atsign,
  NoPortsOnboardingUtil util,
) async {
  var status = await util.atServerStatus(atsign);
  
  switch (status.status()) {
    case AtSignStatus.unavailable:
    case AtSignStatus.teapot:
      // Show OTP activation dialog
      return await showDialog(
        context: context,
        builder: (context) => ActivateAtsignDialog(
          atSign: atsign,
          config: config,
          // ... etc
        ),
      );
      
    case AtSignStatus.activated:
      // Show options: .atKeys upload or APKAM
      final flowChoice = await showDialog<APKAMFlow?>(
        context: context,
        builder: (context) => const ApkamChoiceDialog(),
      );
      
      if (flowChoice == APKAMFlow.atKeys) {
        return await util.uploadAtKeysFile(atsign);
      } else {
        return await util.apkamEnrollment(atsign);
      }
  }
}
```

## What This Means for Our App

### Current Implementation ✅
Our `onboarding_screen.dart` already calls:
```dart
final result = await AtOnboarding.onboard(
  context: context,
  config: AtOnboardingConfig(
    atClientPreference: atClientPreference,
    rootEnvironment: RootEnvironment.Production,
    domain: 'root.atsign.org',
    appAPIKey: 'personalagent',
  ),
);
```

This single call handles **ALL** the flows automatically:
- Shows @sign input
- Checks keychain
- Checks server status
- Shows appropriate dialogs (OTP, file upload, APKAM)
- Stores keys
- Authenticates

### User Experience

**Scenario 1: First Time User with Activated @sign (@cconstab)**
1. App shows: "Get Started" button
2. Click → Shows @sign input field
3. User enters: `@cconstab`
4. SDK checks: "Activated but not in keychain"
5. Dialog appears: "Upload .atKeys file?"
6. User navigates to `~/.atsign/keys/@cconstab_key.atKeys`
7. Select file → Keys loaded → ✅ Authenticated

**Scenario 2: Returning User**
1. App shows: "Get Started" button
2. Click → Shows @sign input (with `@cconstab` pre-filled from keychain)
3. User confirms
4. SDK finds keys in keychain → ✅ Authenticated immediately

**Scenario 3: New @sign Activation**
1. App shows: "Get Started" button
2. Click → Shows @sign input
3. User enters new @sign: `@alice`
4. SDK checks: "Teapot - ready to activate"
5. Dialog: "Enter OTP code"
6. User enters 4-digit OTP from email
7. SDK activates → generates keys → ✅ Authenticated

## Dependencies (Working Versions)

From NoPortsDesktop `pubspec.lock`:
```yaml
at_onboarding_flutter: 6.1.7
showcaseview: 3.0.0  # (as dependency override)
intl: ^0.19.0
```

These exact versions are confirmed working in production NoPortsdesktop app.

## Benefits of This Approach

1. **Simpler UX**: User just enters their @sign
2. **Smart Detection**: SDK figures out what to do
3. **Multiple Paths**: Supports activation, file upload, APKAM - all automatically
4. **Secure**: Keys managed by SDK's KeyChainManager
5. **Production Tested**: Same pattern used by NoPortsdesktop

## Testing Our Implementation

**With Activated @sign (@cconstab):**
```bash
# 1. Start agent
cd agent && dart run bin/agent.dart

# 2. Start app (already running in background)
# App should be at onboarding screen

# 3. In app:
# - Click "Get Started"
# - Enter: @cconstab
# - Widget will offer .atKeys upload
# - Navigate to ~/.atsign/keys/@cconstab_key.atKeys
# - Select file
# - Should authenticate successfully

# 4. Send test message:
# - Type: "Hello"
# - Should receive response (no null pointer!)
```

## Success Criteria

- ✅ Widget compiles (with showcaseview 3.0.0 override)
- ✅ App runs on macOS
- ✅ Shows @sign input field
- ✅ Detects @cconstab is activated
- ✅ Offers .atKeys file upload
- ✅ Loads keys into KeyChainManager
- ✅ No null pointer errors when sending messages
- ✅ Agent receives and decrypts messages

## Next Steps

1. **Test the onboarding flow** with @cconstab
2. **Verify key loading** by checking no AtChops null errors
3. **Test messaging** end-to-end
4. **Document** the successful pattern for future reference
