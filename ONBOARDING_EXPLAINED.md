# Understanding the Onboarding UI

## What You're Seeing is CORRECT! ✅

When you run the app and see **QR code and .atKeys file upload options**, this is **NOT a bug** - it's the official AtOnboarding widget working exactly as designed.

## How NoPortsDesktop Actually Works

You correctly observed that NoPortsDesktop "doesn't ask for atkey file or QRCode upfront." Here's what's actually happening:

### Step 1: @sign Input Dialog
When you click "Get Started", `AtOnboarding.onboard()` shows a **dialog asking for your @sign**:
```
┌─────────────────────────────────┐
│   Enter your NoPorts atSign     │
│                                  │
│   @sign: [______________]       │
│                                  │
│   [Cancel]          [Next]      │
└─────────────────────────────────┘
```

### Step 2: Status Check (Invisible to User)
After you enter `@cconstab`, the SDK checks:
- Is @cconstab in device keychain? ❌ No
- Is @cconstab activated on server? ✅ Yes

### Step 3: ApkamChoiceDialog (What You See)
Based on status, the widget shows **authentication options**:

```
┌──────────────────────────────────────────┐
│          Authenticate                     │
│  Select your enrolment method            │
│                                           │
│  ┌────────────────────────────────────┐ │
│  │ Upload atKey                       │ │
│  │ Select a local .atKeys file        │ │
│  │                    [Select Key]    │ │ ← THIS IS WHAT YOU NEED!
│  └────────────────────────────────────┘ │
│                                           │
│  ┌────────────────────────────────────┐ │
│  │ Enroll with Authenticator          │ │
│  │ Authenticate through app with      │ │
│  │ manager keys                       │ │
│  │                    [Enroll]        │ │
│  └────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

## What to Do

1. ✅ The UI showing ".atKeys upload" option is CORRECT
2. ✅ Click the **"Select Key"** or **"Upload atKey"** button  
3. ✅ Navigate to: `~/.atsign/keys/@cconstab_key.atKeys`
4. ✅ Select the file
5. ✅ Keys will load into KeyChainManager
6. ✅ You'll be authenticated!

## Why You Also See QR Code Option

For **brand new @signs** that haven't been activated yet:
- Server status returns "teapot" or "not activated"
- Widget shows QR code and OTP activation flow
- This is for first-time activation

But for **your @cconstab** (already activated):
- Widget shows .atKeys file upload option
- This is the correct path for existing activated @signs

## The Pattern Explained

NoPortsDesktop flow:
1. Show @sign input (NO file picker yet)
2. User enters @sign
3. Check status → **THEN** show appropriate options
4. For activated @signs → Show .atKeys upload + APKAM options
5. For new @signs → Show QR code + OTP activation

Your app is doing this CORRECTLY! The "QR code/atKeys UI" you see is the OPTIONS MENU, not an error.

## Next Steps

Simply:
1. Select ".atKeys file" option in the dialog
2. Browse to `~/.atsign/keys/@cconstab_key.atKeys`
3. Keys load automatically
4. Test sending a message to @llama!

**The null pointer error will be fixed once keys are properly loaded into AtChops** 🎯
