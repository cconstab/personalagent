# Quick Start: Testing Onboarding

## Current Situation

Your app crashed because it has **cached @cconstab** in SharedPreferences but the keys aren't in the keychain. The AtOnboarding widget tried to initialize with missing keys.

## Solution: Clear Cache and Test Fresh

### Option 1: Delete App Data (Easiest)

On macOS, simply delete the app and reinstall:

```bash
cd /Users/cconstab/Documents/GitHub/cconstab/personalagent

# Kill running app
pkill -f personal_agent_app

# Clean build
cd app
flutter clean
flutter pub get

# Run fresh
flutter run -d macos
```

This clears all cached data including SharedPreferences.

### Option 2: Clear Only Preferences (if you want to keep other data)

The app stores preferences in:
```
~/Library/Containers/com.example.personalAgentApp/Data/Library/Preferences/
```

You can delete this while keeping other app data.

### Option 3: Add Debug Logout Button (Temporary)

If you want to keep testing, temporarily add a logout button to clear cache without reinstalling.

## What You'll See When Testing

### 1. First Launch (After Clearing Cache)
```
App shows onboarding slides
  ↓
Click "Get Started"
  ↓
AtOnboarding widget opens
```

### 2. @sign Input Dialog
```
┌─────────────────────────────────┐
│   Enter your atSign             │
│                                  │
│   @cconstab                     │ ← Type your @sign
│                                  │
│   [Cancel]          [Next]      │
└─────────────────────────────────┘
```

### 3. Status Check (Automatic)
Widget checks:
- ✅ @cconstab exists on server (activated)
- ❌ @cconstab NOT in keychain

### 4. Authentication Options Dialog
```
┌──────────────────────────────────────────┐
│          Authenticate                     │
│  Select your enrolment method            │
│                                           │
│  ┌────────────────────────────────────┐ │
│  │ Upload atKey                       │ │
│  │ Select a local .atKeys file        │ │
│  │                    [Select Key]    │ │ ← CLICK THIS
│  └────────────────────────────────────┘ │
│                                           │
│  ┌────────────────────────────────────┐ │
│  │ Enroll with Authenticator          │ │
│  │                    [Enroll]        │ │
│  └────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

### 5. File Picker Opens
```
Navigate to:
/Users/cconstab/.atsign/keys/@cconstab_key.atKeys

Select the file
```

### 6. Success!
```
Keys load into KeyChainManager
AtClient initializes
You see: "✅ Authenticated as @cconstab"
```

### 7. Home Screen
```
Navigate to chat
Send: "Hello!"
Agent receives encrypted message
Agent responds
No null pointer errors! 🎉
```

## Test Checklist

- [ ] Clear app cache (delete and rebuild)
- [ ] Launch app
- [ ] Click through onboarding slides
- [ ] Click "Get Started"
- [ ] Type @cconstab in dialog
- [ ] See authentication options (this is CORRECT!)
- [ ] Click "Select Key" or "Upload atKey"
- [ ] Navigate to ~/.atsign/keys/@cconstab_key.atKeys
- [ ] Select file
- [ ] Verify "✅ Authenticated as @cconstab" message
- [ ] Navigate to chat screen
- [ ] Send test message
- [ ] Verify agent receives message (check agent logs)
- [ ] Verify response appears in app
- [ ] Success: No null pointer errors!

## Troubleshooting

### If You Don't See File Picker
- Make sure you clicked the "Select Key" button
- Check macOS permissions (System Settings > Privacy & Security > Files and Folders)

### If Authentication Fails
- Verify file path: ~/.atsign/keys/@cconstab_key.atKeys
- Check file is readable (not corrupted)
- Check agent is running: cd agent && dart run bin/agent.dart

### If Null Pointer Still Occurs
- Keys may not have loaded properly
- Check logs for "AtChops" or "signing" errors
- Verify KeyChainManager has keys

## Expected Result

After successful onboarding:
1. Keys loaded into AtChops ✅
2. Messages encrypt/decrypt correctly ✅  
3. Agent can decrypt your messages ✅
4. You receive agent responses ✅
5. No null pointer errors ✅

**The onboarding pattern you saw is CORRECT!** It matches NoPortsDesktop exactly. The dialog showing ".atKeys upload" option is the proper behavior for activated @signs not yet in the keychain.
