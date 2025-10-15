# Multi-@sign Support

The app now supports multiple @signs in the keychain, just like NoPorts Desktop!

## 🎯 Features

### 1. Multiple @signs in Keychain
- Store unlimited @signs in your OS keychain
- Each @sign's keys are preserved separately
- Switch between them instantly

### 2. @sign Selection on Launch
When you open the app with existing @signs:
- See a list of all your stored @signs
- Click any @sign to sign in instantly
- Delete unwanted @signs with the trash icon
- Add new @signs with "Add New @sign" button

### 3. Switch @signs from Settings
While signed in:
- Tap "Current @sign" in Settings
- See all available @signs
- Switch to any other @sign instantly
- Current @sign is highlighted with a checkmark

### 4. Manage @signs
From Settings → "Manage @signs":
- View all stored @signs
- Current @sign is shown (cannot be removed while active)
- Remove other @signs from keychain
- Clean up old or unused @signs

## 📱 User Flows

### First Time User
```
Open App
  ↓
Onboarding Screens
  ↓
"Get Started" button
  ↓
Import keys or activate @sign
  ↓
@sign saved to keychain
  ↓
Sign in to app
```

### Returning User (One @sign)
```
Open App
  ↓
"Select @sign" dialog shows your @sign
  ↓
Click your @sign
  ↓
Instant sign in (PKAM from keychain)
```

### Returning User (Multiple @signs)
```
Open App
  ↓
"Select @sign" dialog shows all @signs
  ↓
Choose which @sign to use
  ↓
Instant sign in with chosen @sign
```

### Adding Another @sign
```
While signed in OR from @sign selection:
  ↓
Click "Add New @sign"
  ↓
Import keys or activate new @sign
  ↓
New @sign added to keychain
  ↓
Sign in with new @sign
```

### Switching @signs
```
Settings → Current @sign
  ↓
"Switch @sign" dialog
  ↓
Select different @sign
  ↓
App signs out and returns to selection screen
  ↓
Select the @sign you switched to
  ↓
Signed in with new @sign
```

### Removing @sign
```
Option 1: From @sign selection dialog
  ↓
Click trash icon next to @sign
  ↓
Confirm removal
  ↓
@sign removed from keychain
  
Option 2: From Settings
  ↓
Settings → Manage @signs
  ↓
Click delete icon (only for non-current @signs)
  ↓
Confirm removal
  ↓
@sign removed from keychain
```

## 🔐 Security

### What's Stored in Keychain
- Each @sign's `.atKeys` file (PKAM private key)
- Stored securely by OS (macOS Keychain, Windows Credential Manager, etc.)
- Encrypted by the operating system
- Requires system authentication to access

### What's in App Storage
- Only the CURRENT @sign name
- No private keys in app storage
- Cleared on sign out

### Privacy
- Each @sign is isolated
- Switching @signs clears app data
- Context and messages are per-@sign
- Ollama-only mode preference is global (applies to all @signs)

## 🛠️ Implementation Details

### Keychain Management
- Uses `at_client_mobile`'s KeychainUtil
- Platform-specific implementation:
  - **macOS**: macOS Keychain (security command)
  - **iOS**: iOS Keychain
  - **Android**: Android Keystore
  - **Windows**: Windows Credential Manager
  - **Linux**: Secret Service API

### @sign Storage Format
Each @sign is stored with account name = @sign:
```
Service: atsign
Account: @alice
Password: <encrypted .atKeys JSON>
```

### Selection Dialog
- Shows on app launch if @signs exist
- Cannot be dismissed (must select an option)
- Lists all @signs from keychain
- Delete button removes from keychain
- "Add New @sign" button for onboarding

### Switch Mechanism
1. User clicks "Current @sign" in Settings
2. Shows "Switch @sign" dialog
3. User selects different @sign
4. App signs out (preserves keychain)
5. App returns to onboarding screen
6. User sees selection dialog
7. User clicks the @sign they switched to
8. Instant sign in with new @sign

## 🔄 Migration from Single @sign

If you're upgrading from a version that only supported one @sign:
- Your existing @sign is already in the keychain
- No action needed
- On next launch, you'll see the selection dialog
- Can add more @signs using "Add New @sign"

## 📝 Best Practices

### For Users
- Keep backup of `.atKeys` files before removing from keychain
- Use meaningful @sign names if activating multiple @signs
- Remove @signs you no longer use to keep list clean

### For Developers
- Never clear keychain unless explicitly requested by user
- Always preserve all @signs when signing out
- Use `KeychainUtil.getAtsignList()` to list available @signs
- Respect user's choice of which @sign to use

## 🐛 Troubleshooting

### "Add New @sign" logs me in as existing @sign
- This is now fixed! The app clears local storage but preserves keychain
- The onboarding flow will let you import new keys

### Can't remove current @sign
- By design - must switch to another @sign first
- Or sign out, then remove from selection dialog

### @sign disappeared from list
- Check keychain directly (macOS: Keychain Access app)
- Search for service "atsign" and account matching your @sign
- Restore from backup `.atKeys` file if needed

### Want to use same @sign on multiple devices
- Export `.atKeys` file from first device
- Import on second device using "Add New @sign"
- Both devices will have access to the same @sign

---

**This matches NoPorts Desktop behavior!** 🎉
