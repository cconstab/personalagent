# Quick @sign Setup Guide

## 🎯 What You Need

### You Need 2 @signs

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  @sign #1: For Your Agent Backend                          │
│  ────────────────────────────────────                       │
│  Example: @alice_agent                                      │
│  Where: agent/.env                                          │
│  Keys:  agent/keys/@alice_agent_key.atKeys                  │
│                                                             │
│  @sign #2: For Your Flutter App                            │
│  ──────────────────────────────────                         │
│  Example: @alice                                            │
│  Where: Entered during app onboarding                       │
│  Keys:  ~/.atsign/keys/@alice_key.atKeys                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Step-by-Step Setup

### Step 1: Get Your @signs (5 minutes)

1. Go to: https://atsign.com/get-an-sign/
2. Register for **2 free @signs**:
   - `@alice_agent` (for the backend)
   - `@alice` (for your app)
3. Download both `.atKeys` files

---

### Step 2: Configure the Agent (2 minutes)

```bash
# Navigate to agent directory
cd personalagent/agent

# Copy example config
cp .env.example .env

# Edit with your agent's @sign
nano .env
```

**Edit these lines in agent/.env:**
```env
AT_SIGN=@alice_agent                                    # ← Your agent's @sign
AT_KEYS_FILE_PATH=./keys/@alice_agent_key.atKeys       # ← Path to keys
```

**Save the file**

---

### Step 3: Add Agent Keys (1 minute)

```bash
# Create keys directory
mkdir -p agent/keys

# Copy your agent's keys file
cp ~/Downloads/@alice_agent_key.atKeys agent/keys/

# Verify it's there
ls agent/keys/
# Should show: @alice_agent_key.atKeys
```

---

### Step 4: Prepare Your App Keys (1 minute)

```bash
# Create directory for app keys (standard location)
mkdir -p ~/.atsign/keys

# Copy your personal @sign keys
cp ~/Downloads/@alice_key.atKeys ~/.atsign/keys/

# Verify it's there
ls ~/.atsign/keys/
# Should show: @alice_key.atKeys
```

**Note:** The Flutter app will automatically find keys in `~/.atsign/keys/` during onboarding.

---

### Step 5: Start the Agent (1 minute)

```bash
cd personalagent
./setup.sh              # Installs dependencies and starts services
```

Or manually:
```bash
cd agent
dart pub get
dart run bin/agent.dart
```

You should see:
```
INFO: Starting Private AI Agent
INFO: atSign: @alice_agent
INFO: Ollama: http://localhost:11434 (llama2)
INFO: AtPlatform initialized successfully
INFO: Starting message listener
```

---

### Step 6: Configure the App (During First Launch)

```bash
# In a new terminal
cd app
flutter pub get
flutter run
```

**When the app starts:**

1. **Welcome screen** appears
2. Click **"Get Started with atPlatform"**
3. **Enter your @sign:** `@alice` (or `alice` - app adds @ automatically)
4. App finds your `.atKeys` file in `~/.atsign/keys/`
5. **Done!** You're connected to your agent

---

## 🔄 How They Communicate

```
┌─────────────────────────┐
│   Flutter App           │
│   Uses: @alice          │
│   Keys: ~/.atsign/keys/ │
└────────────┬────────────┘
             │
             │ Encrypted Messages
             │ via atPlatform
             ↓
┌────────────┴────────────┐
│   Agent Backend         │
│   Uses: @alice_agent    │
│   Keys: agent/keys/     │
└─────────────────────────┘
```

**Message Flow:**
1. You type: "What's my schedule?"
2. App encrypts with `@alice`
3. Sends to `@alice_agent`
4. Agent decrypts with `@alice_agent`
5. Agent processes query
6. Agent encrypts response with `@alice_agent`
7. Sends to `@alice`
8. App decrypts and shows you

**atPlatform only sees encrypted data - cannot read contents!**

---

## ✅ Verification Checklist

Before running, verify:

```bash
# ✅ Agent configuration
cat agent/.env | grep AT_SIGN
# Should show: AT_SIGN=@alice_agent

# ✅ Agent keys exist
ls agent/keys/@alice_agent_key.atKeys
# Should show: agent/keys/@alice_agent_key.atKeys

# ✅ Your personal keys exist
ls ~/.atsign/keys/@alice_key.atKeys
# Should show: /Users/you/.atsign/keys/@alice_key.atKeys

# ✅ Dependencies installed
cd agent && dart pub get
cd ../app && flutter pub get

# ✅ Ollama running (if using Docker)
docker ps | grep ollama
# Should show ollama container running
```

---

## ❓ Common Questions

### Q: Why do I need 2 @signs?

**A:** Separation of concerns:
- **Agent @sign** = The "server" that processes requests
- **Your @sign** = Your "client" that makes requests

This allows:
- Multiple people to use the same agent
- Different apps to connect to the same agent
- Clear security boundaries

### Q: Can I use the same @sign for both?

**A:** Technically yes, but **not recommended**:
- More complex to configure
- Can't share the agent
- Harder to debug
- Loses security benefits

### Q: What if I already have an @sign?

**A:** Great! You only need **1 new @sign** for the agent.
- Use your existing @sign for the app
- Get 1 new @sign for the agent (e.g., `@yourname_agent`)

### Q: How much do @signs cost?

**A:** Free @signs available at: https://atsign.com/get-an-sign/
Premium @signs available for purchase.

### Q: Where does the app find my keys?

**A:** Standard locations:
- **macOS/Linux:** `~/.atsign/keys/`
- **Windows:** `%USERPROFILE%\.atsign\keys\`
- The `at_onboarding_flutter` package searches these automatically

### Q: Can I move my keys elsewhere?

**A:** Yes, but you'll need to specify the path during onboarding or use custom onboarding flow.

---

## 🚨 Troubleshooting

### "AT_SIGN and AT_KEYS_FILE_PATH must be set"

**Problem:** Agent can't find configuration

**Solution:**
```bash
cd agent
ls .env                    # Verify .env exists
cat .env | grep AT_SIGN    # Verify AT_SIGN is set
ls keys/                   # Verify keys file exists
```

### "Failed to initialize atPlatform"

**Problem:** Keys file not found or invalid

**Solution:**
```bash
# Check keys file path in .env matches actual file
cd agent
cat .env | grep AT_KEYS_FILE_PATH
ls ./keys/                           # Should list your .atKeys file

# Path should match, e.g.:
# .env says: AT_KEYS_FILE_PATH=./keys/@alice_agent_key.atKeys
# File exists: ./keys/@alice_agent_key.atKeys ✅
```

### App can't connect during onboarding

**Problem:** Keys not found or incorrect @sign

**Solution:**
```bash
# Verify your personal keys are in the standard location
ls ~/.atsign/keys/                # macOS/Linux
ls %USERPROFILE%\.atsign\keys\    # Windows

# Make sure @sign matches the keys filename
# If keys are @alice_key.atKeys, use @alice (or just "alice")
```

---

## 🎓 Next Steps

Once setup is complete:

1. **Test the connection:**
   - Send a message in the app
   - Check agent logs for "Received message"
   - Verify response appears in app

2. **Add context:**
   - Go to Settings → Manage Context
   - Add your personal information
   - This context stays encrypted on atPlatform

3. **Customize:**
   - Adjust `PRIVACY_THRESHOLD` in agent/.env
   - Add Claude API key for hybrid mode
   - See [ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md) for advanced config

---

## 📚 Further Reading

- **[ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md)** - Detailed architecture and security
- **[COMMUNICATION_FLOW.md](COMMUNICATION_FLOW.md)** - How messages flow
- **[QUICKSTART.md](QUICKSTART.md)** - Development guide
- **[atPlatform Documentation](https://atsign.com/docs/)** - Official docs

---

## 🎉 You're Ready!

With both @signs configured, you have:
- ✅ Private, encrypted communication
- ✅ Local AI processing (Ollama)
- ✅ Optional cloud intelligence (Claude)
- ✅ Your data under your control

**Start chatting with your private AI agent!**

---

*Need help? Check [ATSIGN_ARCHITECTURE.md](ATSIGN_ARCHITECTURE.md) or open an issue.*
