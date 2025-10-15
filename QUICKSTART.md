# Quick Setup Guide 🚀

## What We Just Fixed ✅

1. **Removed QR code/file upload UI** - Only APKAM enrollment now (cleaner, more secure)
2. **Fixed "AtClient not initialized" error** - Proper initialization after onboarding
3. **Added agent @sign configuration** - Configure in Settings UI
4. **Fixed communication flow** - App sends TO agent, receives FROM agent (was backwards!)
5. **Wired up agent processing** - Agent now processes queries and sends responses back

## Current Status

### Flutter App ✅
- Onboarding works (no more PKAM errors)
- Agent @sign configurable in Settings
- Sends queries TO @llama
- Listens for responses FROM @llama
- Shows "Connected to @llama" in UI

### Agent Backend ⏳
- Ready to listen for queries
- Will process with Ollama/Claude
- Will send responses back
- **NEEDS**: Onboarding with @llama @sign

## Quick Start

### 1. Test the App (Optional)
Your app should already be running. Try:
- Go to Settings → you should see "Agent @sign: @llama"
- The home screen should show "Connected to @llama"
- The onboarding UI is now cleaner (no QR code option)

### 2. Setup Agent Backend (REQUIRED) ⚠️

The agent needs to be onboarded with its own @sign. You have two options:

#### Option A: Use at_onboarding_cli (if you have it)
```bash
cd agent

# Make sure at_onboarding_cli is installed
dart pub global activate at_onboarding_cli

# Onboard the agent
dart pub global run at_onboarding_cli:at_onboarding \
  --atsign @llama \
  --keys-file ~/.atsign/keys/@llama_key.atKeys \
  --root-domain root.atsign.org
```

This will prompt you to approve via @sign Authenticator app on your phone.

#### Option B: Import Existing Keys (if you have them)
```bash
# If you already have @llama keys
mkdir -p ~/.atsign/keys/
cp /path/to/your/@llama_key.atKeys ~/.atsign/keys/
```

#### Option C: Manual Setup (Most Common)
1. Go to https://my.atsign.com
2. Get/activate @llama (or another @sign for your agent)
3. Download the keys file
4. Save it as `~/.atsign/keys/@llama_key.atKeys`

### 3. Configure Agent Environment

Make sure `agent/.env` has:
```bash
ATSIGN=@llama
ATSIGN_KEYS_FILE=/Users/yourusername/.atsign/keys/@llama_key.atKeys

OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3
CLAUDE_API_KEY=your_key_here  # Optional
```

### 4. Start the Agent

```bash
cd agent
dart run bin/agent.dart
```

**Expected output:**
```
INFO: Starting Private AI Agent
INFO: atSign: @llama
INFO: Agent initialized successfully
🔔 Starting notification listener for queries from users
✅ Notification listener started
✅ Agent is now listening for queries...
```

### 5. Send Your First Message! 🎉

1. In the app, type: "Hello, are you there?"
2. Watch the agent terminal - you should see:
   ```
   📨 Received query from @cconstab
   ⚡ Handling query from @cconstab
   Processing query...
   ✅ Sent response to @cconstab
   ```
3. The response should appear in your app!

## Troubleshooting

### Agent Error: "AT_SIGN and AT_KEYS_FILE_PATH must be set"
- Check `agent/.env` file exists
- Verify `ATSIGN=@llama` is set
- Verify `ATSIGN_KEYS_FILE` points to valid file

### Agent Error: "PKAM_PRIVATE_KEY_NOT_FOUND"
- Agent needs to be onboarded first
- Follow Step 2 above
- Make sure keys file exists at the path in `.env`

### Agent Error: "Ollama is not available"
```bash
# Start Ollama
ollama serve

# Verify it's running
curl http://localhost:11434
```

### App: "Agent @sign not configured"
- Go to Settings
- Tap "Agent @sign"
- Enter `@llama`
- Tap Save

### App: "Not connected to atPlatform"
- Complete onboarding again
- Restart the app
- Check you see your @sign in Settings

### No messages being received
1. Verify agent is running and shows "listening"
2. Check agent @sign in app Settings matches actual agent @sign
3. Look at agent logs for errors
4. Try restarting both app and agent

## Architecture

```
┌──────────────┐           ┌────────────┐           ┌──────────────┐
│ Flutter App  │           │ atPlatform │           │    Agent     │
│  @cconstab   │◄─────────►│   (E2EE)   │◄─────────►│   @llama     │
└──────────────┘           └────────────┘           └──────────────┘
      │                                                      │
      │ 1. Send 'query.*' notification                     │
      │ ──────────────────────────────────────────────────►│
      │                                        2. Process   │
      │                                        with Ollama  │
      │ 3. Receive 'message.*' notification               │
      │◄────────────────────────────────────────────────── │
      │                                                      │
```

## What's Next?

Once you have end-to-end messaging working:
1. Test privacy features (95% local processing)
2. Try queries that need external knowledge (Claude)
3. Build up context over time
4. Explore context management in Settings

## Documentation

- **COMMUNICATION_FLOW.md** - Detailed message flow explanation
- **AGENT_SETUP.md** - Complete agent setup guide
- **README.md** - Project overview

## Success Checklist ✅

- [ ] App shows "Connected to @llama"
- [ ] Agent shows "✅ Agent is now listening..."
- [ ] Can send message in app
- [ ] Agent logs show "📨 Received query"
- [ ] Response appears in app
- [ ] End-to-end encryption working!

---

**The main blocker now is getting the agent onboarded with @llama keys!**

Everything else is ready to go. Once you have the keys file set up, it should just work! 🚀
