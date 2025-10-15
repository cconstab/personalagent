# @sign Architecture Guide

## 📱 How Many @signs Do I Need?

### Minimum Setup (Personal Use)
**You need 2 @signs:**
1. **Agent @sign** (e.g., `@alice_agent`) - Your backend agent service
2. **User @sign** (e.g., `@alice`) - Your Flutter app

### Why Two @signs?

```
┌─────────────────────┐         ┌──────────────────────┐
│   Flutter App       │         │   Agent Backend      │
│   @alice            │ ◄─────► │   @alice_agent       │
│                     │         │                      │
│ - Sends queries     │         │ - Processes queries  │
│ - Receives answers  │         │ - Stores context     │
└─────────────────────┘         └──────────────────────┘
      User's Device                    Your Server
```

### Multi-User Setup (Family/Team)
**You can share one agent @sign with multiple users:**

```
┌─────────────────┐
│   @alice        │ ─┐
└─────────────────┘  │
                     │
┌─────────────────┐  │      ┌──────────────────────┐
│   @bob          │ ─┼────► │   @family_agent      │
└─────────────────┘  │      └──────────────────────┘
                     │
┌─────────────────┐  │
│   @charlie      │ ─┘
└─────────────────┘
```

**Agent config:**
```env
AT_SIGN=@family_agent
ALLOWED_USERS=@alice,@bob,@charlie
```

---

## 🔐 Security Models

### Model 1: Personal Private Agent (Current Implementation)
**Best for:** Individual users who want maximum privacy

```env
# agent/.env
AT_SIGN=@alice_agent
ALLOWED_USERS=           # Empty = agent processes messages but doesn't restrict
```

**Security:**
- Messages encrypted end-to-end via atPlatform
- Only @alice can decrypt @alice_agent's responses
- Agent stores context locally (not shared between users)
- atPlatform cannot read message contents

**Limitation:** Currently no sender verification (any @sign can send messages to the agent)

### Model 2: Restricted Agent (Enhanced Security)
**Best for:** Shared agents or production deployments

```env
# agent/.env
AT_SIGN=@family_agent
ALLOWED_USERS=@alice,@bob,@charlie
```

**Security:**
- All benefits of Model 1
- Agent validates sender @sign before processing
- Rejected requests logged for security monitoring
- Per-user context isolation (optional enhancement)

**Note:** This requires implementing sender verification in `AtPlatformService.listenForMessages()`

---

## 🎯 Current Architecture

### What the Agent Needs
```env
# agent/.env
AT_SIGN=@your_agent              # The agent's identity
AT_KEYS_FILE_PATH=./keys/@your_agent_key.atKeys  # Agent's encryption keys
```

### What the Flutter App Needs
The app gets its @sign **during onboarding** from the user:
1. User opens app for first time
2. Onboarding screen prompts for @sign
3. User enters their @sign (e.g., `@alice`)
4. App authenticates with atPlatform using their .atKeys file
5. App can now send encrypted messages to agent

**The app @sign is NOT in .env** - it's user-provided at runtime!

---

## 📨 Message Flow

### 1. User Sends Query
```
User types: "What's on my schedule today?"
         ↓
Flutter App (@alice)
         ↓
Encrypts message for @alice_agent
         ↓
atPlatform (encrypted notification)
         ↓
Agent Backend (@alice_agent)
         ↓
Decrypts message
         ↓
Processes with Ollama/Claude
```

### 2. Agent Sends Response
```
Agent has answer
         ↓
Encrypts response for @alice (sender)
         ↓
atPlatform (encrypted notification)
         ↓
Flutter App (@alice)
         ↓
Decrypts response
         ↓
Displays in chat
```

### Key Points:
- **Agent knows sender's @sign** from the notification metadata
- **Agent responds to the sender** using `sendResponse(recipientAtSign, response)`
- **No pre-configuration needed** - the agent learns user @signs dynamically
- **Encryption is automatic** via atPlatform's `sharedWith` parameter

---

## 🔧 Configuration Examples

### Example 1: Personal Setup
```env
# agent/.env
AT_SIGN=@alice_agent
AT_KEYS_FILE_PATH=./keys/@alice_agent_key.atKeys
ALLOWED_USERS=
```

**User's app:** Uses `@alice` (configured during onboarding)

### Example 2: Family Setup
```env
# agent/.env
AT_SIGN=@smith_family_agent
AT_KEYS_FILE_PATH=./keys/@smith_family_agent_key.atKeys
ALLOWED_USERS=@john_smith,@jane_smith,@timmy_smith
```

**Family members' apps:**
- John's app: Uses `@john_smith`
- Jane's app: Uses `@jane_smith`
- Timmy's app: Uses `@timmy_smith`

### Example 3: Development/Testing
```env
# agent/.env
AT_SIGN=@test_agent
AT_KEYS_FILE_PATH=./keys/@test_agent_key.atKeys
ALLOWED_USERS=
```

**Your test apps:** Use `@alice_test`, `@bob_test`, etc.

---

## 🛠️ Getting @signs

### Option 1: Free @signs (Development)
Visit: https://atsign.com/get-an-sign/

### Option 2: Custom @signs (Production)
Purchase: https://atsign.com/

### What You Get:
1. **@sign identifier** (e.g., `@alice`)
2. **.atKeys file** - Contains encryption keys
3. **Activation instructions**

### For This Project You Need:
```bash
# For the agent
@your_agent → Save keys to: agent/keys/@your_agent_key.atKeys

# For your app (each user)
@your_name → Save keys to: ~/.atsign/keys/@your_name_key.atKeys
# (The Flutter app finds this automatically via at_onboarding_flutter)
```

---

## 🚀 Setup Workflow

### Step 1: Get @signs
```bash
# Get 2 @signs from https://atsign.com/get-an-sign/
# Example: @alice and @alice_agent
```

### Step 2: Configure Agent
```bash
cd agent
cp .env.example .env
nano .env  # Edit with your agent's @sign
```

```env
AT_SIGN=@alice_agent
AT_KEYS_FILE_PATH=./keys/@alice_agent_key.atKeys
```

### Step 3: Add Agent Keys
```bash
mkdir -p agent/keys
# Download @alice_agent_key.atKeys from atsign.com
mv ~/Downloads/@alice_agent_key.atKeys agent/keys/
```

### Step 4: Run Agent
```bash
cd agent
dart pub get
dart run bin/agent.dart
```

### Step 5: Configure App (During Onboarding)
```bash
cd app
flutter pub get
flutter run
```

When the app starts:
1. Onboarding screen appears
2. Click "Get Started with atPlatform"
3. Enter `@alice` (your user @sign)
4. App finds your .atKeys file automatically
5. App connects to `@alice_agent`

---

## 🔒 Privacy Guarantees

### What atPlatform Sees:
- `@alice` sent a notification to `@alice_agent`
- `@alice_agent` sent a notification to `@alice`
- Encrypted blob of data (cannot be read)

### What atPlatform CANNOT See:
- ❌ Message contents
- ❌ Your queries
- ❌ Agent responses
- ❌ Your context data
- ❌ Any personal information

### Encryption Details:
- **Algorithm:** AES-256
- **Key Exchange:** Diffie-Hellman
- **Authentication:** RSA-2048
- **End-to-End:** Yes (only sender and recipient have keys)

---

## 💡 Advanced: Per-User Context

Want each user to have isolated context? Update the agent service:

```dart
// lib/services/at_platform_service.dart

Future<void> storeContext(String userAtSign, ContextData context) async {
  final atKey = AtKey()
    ..key = 'context.${userAtSign}.${context.key}'  // Include user @sign
    ..namespace = 'personalagent'
    ..sharedWith = atSign;  // Agent only
    
  final jsonData = json.encode(context.toJson());
  await _atClient!.put(atKey, jsonData);
}

Future<ContextData?> getContext(String userAtSign, String key) async {
  final atKey = AtKey()
    ..key = 'context.${userAtSign}.$key'  // User-specific key
    ..namespace = 'personalagent'
    ..sharedWith = atSign;
    
  final value = await _atClient!.get(atKey);
  // ... rest of implementation
}
```

Now each user's context is isolated:
- `@alice`'s context: `context.@alice.work_schedule`
- `@bob`'s context: `context.@bob.work_schedule`

---

## 📊 Comparison: Single vs Multiple @signs

| Aspect | Single @sign | Two @signs (Current) | Multi @signs |
|--------|--------------|----------------------|---------------|
| **Setup** | Simplest | Simple | Moderate |
| **Privacy** | App = Agent | App ≠ Agent | App ≠ Agent |
| **Sharing** | Cannot share | Cannot share | Can share agent |
| **Security** | Good | Better | Best |
| **Cost** | 1 @sign | 2 @signs | 2+ @signs |
| **Use Case** | Testing only | Personal use | Family/team |

---

## ❓ FAQ

**Q: Can I use the same @sign for both app and agent?**
A: Technically yes for testing, but NOT recommended:
- Requires running two atClients with same @sign (complex)
- Loses separation of concerns
- Cannot share agent with others
- Harder to debug

**Q: How does the agent know my @sign?**
A: The agent extracts it from notification metadata:
```dart
notification.from  // Sender's @sign (e.g., "@alice")
```

**Q: Can multiple people use the same agent?**
A: Yes! Each user's app uses their own @sign to communicate with the shared agent @sign.

**Q: Is my data shared between users?**
A: Currently: Context is per-agent (shared)
Future: Implement per-user context isolation (see "Advanced" section)

**Q: What if I lose my .atKeys file?**
A: Unfortunately, keys cannot be recovered (by design for security). You'll need to:
1. Get a new @sign
2. Reconfigure your agent
3. Re-enter context data

**Q: Can I change my @sign later?**
A: Yes, but you'll need to:
1. Get new @sign
2. Update agent/.env
3. Move keys to new path
4. Restart agent

---

## 🎓 Summary

**Current Setup:**
- ✅ Agent has 1 @sign (configured in agent/.env)
- ✅ Each user's app has their own @sign (entered during onboarding)
- ✅ Agent accepts messages from any @sign
- ✅ Messages are end-to-end encrypted
- ✅ Agent responds to sender automatically

**For Enhanced Security (Future):**
- Add `ALLOWED_USERS` validation in `listenForMessages()`
- Implement per-user context isolation
- Add authentication logging

**The .env is correct!** It only needs the agent's @sign because:
1. User @signs are provided at runtime during onboarding
2. Agent learns sender @signs from incoming messages
3. No hardcoding needed - it's dynamic and flexible

---

*This architecture provides privacy, security, and flexibility while keeping setup simple.*
