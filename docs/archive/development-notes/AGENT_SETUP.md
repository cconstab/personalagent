# Agent Backend Setup Guide

## Overview
The agent backend needs to be onboarded with its own @sign to receive and process queries from the Flutter app.

## Prerequisites
- An @sign for the agent (e.g., @llama)
- The @sign must be activated (via my.atsign.com or atSign app)

## Setup Steps

### 1. Get Agent Keys

You have two options:

#### Option A: Use APKAM Enrollment (Recommended)
```bash
cd agent
dart run at_onboarding_cli:onboard \
  --atsign @llama \
  --keys-file ~/.atsign/keys/@llama_key.atKeys \
  --root-domain root.atsign.org
```

This will:
1. Prompt you to approve enrollment via @sign Authenticator app
2. Generate the keys file with APKAM enrollment
3. Store keys in `~/.atsign/keys/@llama_key.atKeys`

#### Option B: Import Existing Keys
If you already have keys for @llama:
1. Place the `@llama_key.atKeys` file in `~/.atsign/keys/`
2. Update `.env` file with the path

### 2. Update Environment Variables

Edit `agent/.env`:
```bash
# Agent @sign configuration
ATSIGN=@llama
ATSIGN_KEYS_FILE=/Users/yourusername/.atsign/keys/@llama_key.atKeys

# AI Service Configuration  
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=llama3
CLAUDE_API_KEY=your_claude_api_key_here
```

### 3. Start the Agent

```bash
cd agent
dart run bin/agent.dart
```

You should see:
```
INFO: Agent initialized for @llama
INFO: Listening for notifications...
```

### 4. Configure App

In the Flutter app:
1. Complete onboarding with your personal @sign (e.g., @cconstab)
2. Go to Settings
3. Set "Agent @sign" to `@llama`
4. Start chatting!

## Storage Locations

- **Agent Keys**: `~/.atsign/keys/@llama_key.atKeys`
- **Agent Storage**: `agent/storage/hive/`
- **Agent Commit Log**: `agent/storage/commit/`

## Troubleshooting

### "AtClient not initialized" error
- Make sure you completed onboarding in the app
- Restart the app after onboarding
- Check that AtClientService initialized successfully (look for ✅ in logs)

### "Agent @sign not configured" error
- Go to Settings → Configure Agent @sign
- Make sure it matches the @sign the agent is using (e.g., @llama)

### Agent not receiving messages
- Check agent is running: `cd agent && dart run bin/agent.dart`
- Check agent @sign matches what's in app settings
- Check agent has valid keys in storage
- Look for "Listening for notifications..." in agent logs

### PKAM_PRIVATE_KEY_NOT_FOUND in agent
- Agent needs to be onboarded first
- Run the onboarding command (Option A above)
- Or import existing keys (Option B above)

## Security Notes

- The agent keys file contains sensitive cryptographic keys
- Store it securely, ideally in `~/.atsign/keys/` with proper permissions
- Don't commit keys to version control (already in .gitignore)
- Each agent instance should have its own unique @sign

## Next Steps

Once both app and agent are running:
1. Test sending a message from the app
2. Check agent logs for incoming notification
3. Verify encrypted response comes back to app
4. Check that conversation history is preserved

## Architecture

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────────┐
│  Flutter App    │         │  atPlatform  │         │  Agent Backend  │
│  (@cconstab)    │◄───────►│   (E2E enc)  │◄───────►│    (@llama)     │
└─────────────────┘         └──────────────┘         └─────────────────┘
        │                                                       │
        │ 1. Send encrypted query                             │
        │ ──────────────────────────────────────────────────► │
        │                                                       │
        │                                             2. Process with
        │                                             Ollama/Claude
        │                                                       │
        │ 3. Receive encrypted response                       │
        │ ◄────────────────────────────────────────────────── │
        │                                                       │
```

All communication is end-to-end encrypted via atPlatform. Only @cconstab can send to @llama, and only @cconstab can decrypt @llama's responses.
