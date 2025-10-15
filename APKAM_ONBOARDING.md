# APKAM Onboarding - No File Upload Required!

## The Solution: APKAM Enrollment

You're absolutely right that **NoPortsDesktop never asks for .atKeys file uploads**! Instead, they use **APKAM (atPlatform Key Access Management)** enrollment for already-activated @signs.

## How It Works

### 1. Run the App

```bash
./run_app.sh
```

### 2. Enter Your @sign

When the onboarding screen appears:
- Click "Get Started"
- **Enter: @cconstab**
- Click "Next"

### 3. SDK Detects Already-Activated @sign

The SDK will check the server status and detect that **@cconstab is already activated**.

### 4. APKAM Choice Dialog Appears

You'll see TWO options:

```
┌───────────────────────────────────────────┐
│ How do you want to authenticate?         │
├───────────────────────────────────────────┤
│                                           │
│ ┌─────────────────────────────────────┐  │
│ │ Upload .atKeys File                 │  │ ← DON'T use this
│ │ [Select Key]                        │  │
│ └─────────────────────────────────────┘  │
│                                           │
│ ┌─────────────────────────────────────┐  │
│ │ Enroll with Authenticator           │  │ ← USE THIS!
│ │ Authenticate through app with       │  │
│ │ manager keys                        │  │
│ │ [Enroll]                            │  │
│ └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

### 5. Choose "Enroll with Authenticator"

Click the **[Enroll]** button in the bottom option.

### 6. APKAM Enrollment Process

The app will:
1. Generate an **enrollment request**
2. Send it to your **@atsign authenticator app** (you need the @atsign app on your phone)
3. You'll **approve the request** on your phone
4. The SDK generates **new device-specific keys**
5. Keys are **automatically stored in macOS keychain**
6. **NO .atKeys file required!**

## What You Need

### @atsign Authenticator App

Download from:
- **iOS**: [App Store - @atsign](https://apps.apple.com/app/atsign-authenticator)
- **Android**: [Play Store - @atsign](https://play.google.com/store/apps/details?id=com.atsign.authenticator)

The authenticator app holds your "manager keys" and can approve enrollment requests for new devices.

## Why This Works

APKAM enrollment:
- ✅ **No file uploads** - Keys generated on device
- ✅ **Stored in OS keychain** automatically
- ✅ **Device-specific keys** - More secure than shared .atKeys
- ✅ **Approved via authenticator** - 2FA-style approval
- ✅ **Same pattern as NoPortsDesktop** - This is how they do it!

## After First Enrollment

Once APKAM enrollment completes:
1. Keys are in macOS keychain
2. Every subsequent app launch: Loads from keychain automatically
3. **No UI shown** - Direct authentication
4. Exactly like NoPortsDesktop!

## Alternative: OTP Activation (for new @signs)

If you had a **brand new @sign** (not yet activated), the flow would be:
1. Enter @sign
2. SDK detects `AtSignStatus.teapot` (not activated)
3. Shows OTP dialog
4. Enter 4-digit OTP from email
5. SDK activates @sign and generates keys
6. Keys stored in keychain
7. Also no file upload!

## Your Situation

Since **@cconstab is already activated**:
- ✅ Use APKAM enrollment (with @atsign authenticator app)
- ❌ Don't use file upload option
- Result: Keys generated and stored in keychain automatically

## Summary

The misunderstanding was thinking NoPortsDesktop avoids ALL authentication UI. They actually:
1. **First time**: Show @sign input + authentication method choice
2. **For activated @signs**: Offer APKAM enrollment (NOT file upload)
3. **For new @signs**: Offer OTP activation
4. **Subsequent launches**: Load from keychain silently (no UI)

Your app now follows the exact same pattern!
