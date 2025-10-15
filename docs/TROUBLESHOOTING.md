# 🔧 Troubleshooting Guide

Common issues and their solutions for the Private AI Agent.

## 📋 Table of Contents

- [Agent Issues](#agent-issues)
- [Flutter App Issues](#flutter-app-issues)
- [Ollama Issues](#ollama-issues)
- [Authentication Issues](#authentication-issues)
- [macOS Specific Issues](#macos-specific-issues)

## 🤖 Agent Issues

### Agent Not Responding

**Symptoms**: Queries sent from app but no response received

**Solutions**:
1. Check agent is running:
   ```bash
   ps aux | grep "dart run agent"
   ```

2. Restart the agent:
   ```bash
   pkill -f "dart run agent"
   ./run_agent.sh
   ```

3. Check agent logs:
   ```bash
   tail -f agent/logs/agent.log
   ```

4. Verify atPlatform connection:
   - Look for "✅ Agent is now listening for queries..." in logs
   - Check for "PKAM authentication successful"

### Agent Crashes on Startup

**Symptoms**: Agent exits immediately after starting

**Common Causes**:

1. **Missing .env file**:
   ```bash
   cd agent
   cp .env.example .env
   # Edit .env with your settings
   ```

2. **Invalid .atKeys file**:
   - Ensure file exists: `agent/keys/@your_agent_key.atKeys`
   - Verify file is valid JSON
   - Check @sign in .env matches .atKeys filename

3. **Ollama not running**:
   ```bash
   # Check Ollama
   curl http://localhost:11434/api/tags
   
   # Start Ollama if needed
   docker run -d -p 11434:11434 ollama/ollama
   ```

### Claude API Errors

**Symptoms**: "Claude API error" in logs

**Solutions**:
1. Verify API key in `agent/.env`:
   ```bash
   echo $CLAUDE_API_KEY
   ```

2. Test API key:
   ```bash
   curl https://api.anthropic.com/v1/messages \
     -H "x-api-key: YOUR_KEY" \
     -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":100,"messages":[{"role":"user","content":"Hi"}]}'
   ```

3. Check API quota/billing at https://console.anthropic.com

4. Enable Ollama-only mode if Claude is not needed:
   - Open app settings
   - Toggle "Use Ollama Only" ON

## 📱 Flutter App Issues

### App Won't Build

**Symptoms**: Flutter build fails

**Solutions**:
1. Clean and rebuild:
   ```bash
   cd app
   flutter clean
   flutter pub get
   flutter run
   ```

2. Check Flutter version:
   ```bash
   flutter --version
   # Should be 3.0+
   ```

3. Update dependencies:
   ```bash
   flutter pub upgrade
   ```

### Authentication Fails

**Symptoms**: "Authentication failed" error

**Solutions**:
1. Check .atKeys file exists in keychain:
   ```bash
   # macOS
   security find-generic-password -s "atsign_@yoursign"
   ```

2. Re-run onboarding:
   - Clear app data (uninstall/reinstall or clear SharedPreferences)
   - Launch app
   - Complete onboarding flow

3. Verify @sign is activated:
   - Visit https://my.atsign.com
   - Ensure your @sign shows as "Activated"

### No Response from Agent

**Symptoms**: Messages sent but no replies

**Solutions**:
1. Verify agent is running (see [Agent Issues](#agent-issues))

2. Check @signs match:
   - App knows the agent's @sign
   - Agent is using correct @sign

3. Check notification pattern:
   - Agent should be listening on `query.personalagent@`
   - Check agent logs for "🎉 NOTIFICATION RECEIVED!"

4. Test atPlatform connectivity:
   - Try sending a test message
   - Check for network issues

### Ollama-Only Mode Not Working

**Symptoms**: Toggle enabled but Claude still used

**Solutions**:
1. Restart the agent after enabling toggle
2. Check agent logs for "Ollama-Only Mode: ENABLED 🔒"
3. Clear app cache and restart
4. Verify agent is latest version with useOllamaOnly support

## 🦙 Ollama Issues

### Ollama Not Running

**Symptoms**: "Connection refused" to port 11434

**Solutions**:
1. Start Ollama:
   ```bash
   # Docker
   docker run -d -p 11434:11434 ollama/ollama
   
   # Or native install
   ollama serve
   ```

2. Verify it's running:
   ```bash
   curl http://localhost:11434/api/tags
   ```

### Model Not Found

**Symptoms**: "model not found" error

**Solutions**:
1. List available models:
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. Pull the model:
   ```bash
   docker exec -it <ollama-container> ollama pull llama3
   # Or native
   ollama pull llama3
   ```

3. Verify model in agent/.env:
   ```env
   OLLAMA_MODEL=llama3
   ```

### Slow Response Times

**Symptoms**: Ollama takes >10 seconds per query

**Solutions**:
1. Use smaller/faster model:
   ```bash
   ollama pull llama3:8b  # Instead of llama3:70b
   ```

2. Allocate more resources to Docker:
   - Docker Desktop → Settings → Resources
   - Increase CPU and Memory

3. Use GPU acceleration (if available):
   - Ensure CUDA/ROCm drivers installed
   - Restart Ollama with GPU support

## 🔐 Authentication Issues

### Keys Not Found in Keychain

**Symptoms**: "No keys found in keychain"

**Solutions**:
1. Run onboarding to generate keys:
   - Open app
   - Follow onboarding flow
   - Complete PKAM authentication

2. Manually store keys (advanced):
   ```bash
   cd app
   dart run lib/tools/import_keys.dart
   ```

3. Check keychain access:
   ```bash
   # macOS
   security find-generic-password -l "atsign"
   ```

### PKAM Authentication Failed

**Symptoms**: "PKAM authentication failed"

**Solutions**:
1. Verify .atKeys file is valid JSON
2. Check @sign in .atKeys matches requested @sign
3. Ensure @sign is activated at https://my.atsign.com
4. Try regenerating keys:
   - Delete existing .atKeys
   - Run onboarding again

### Sign Out Loses Keys

**Symptoms**: Can't log back in after sign out

**This should NOT happen** - keys are preserved in keychain.

If you're experiencing this:
1. Check app version (should be v1.0+)
2. Keys should remain in OS keychain after sign out
3. Look for "Welcome Back!" dialog on next launch
4. Report as bug if keys are actually being deleted

## 🍎 macOS Specific Issues

### Keychain Access Denied

**Symptoms**: "Keychain access denied" errors

**Solutions**:
1. Grant keychain access:
   - System Settings → Privacy & Security → Keychain
   - Allow app to access keychain

2. Reset keychain if corrupted:
   ```bash
   ./clear_keychain.sh @yoursign
   ```
   Then re-run onboarding

### Entitlements Issues

**Symptoms**: App crashes with entitlements error

**Solutions**:
1. Check `macos/Runner/DebugProfile.entitlements`:
   ```xml
   <key>keychain-access-groups</key>
   <array>
       <string>$(AppIdentifierPrefix)com.example.personalAgentApp</string>
   </array>
   ```

2. Rebuild app:
   ```bash
   cd app
   flutter clean
   flutter pub get
   flutter run
   ```

### Network Sandbox Issues

**Symptoms**: atPlatform connection fails

**Solutions**:
1. Check entitlements include network access:
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   ```

2. Temporarily disable sandbox for testing (development only)
3. Check firewall settings allow outgoing connections

## 🔍 Debugging Tips

### Enable Verbose Logging

**Agent**:
```dart
// In agent/bin/agent.dart
Logger.root.level = Level.ALL; // Show all logs
```

**Flutter App**:
```bash
flutter run --verbose
```

### Monitor Network Traffic

```bash
# Watch atPlatform connections
tcpdump -i any -n port 64 or port 443

# Check local Ollama calls
tcpdump -i lo0 -n port 11434
```

### Check Process Status

```bash
# Agent
ps aux | grep "dart run agent"

# Ollama
docker ps | grep ollama
# Or
ps aux | grep ollama

# Flutter app
ps aux | grep flutter
```

### Validate Configuration

**Agent**:
```bash
cd agent
cat .env
ls -la keys/
```

**App**:
```bash
cd app
flutter doctor -v
flutter pub get
```

## 📊 Health Check Script

Create `check_health.sh`:

```bash
#!/bin/bash
echo "🔍 System Health Check"
echo ""

echo "✓ Checking Ollama..."
curl -s http://localhost:11434/api/tags > /dev/null && echo "  ✅ Ollama running" || echo "  ❌ Ollama NOT running"

echo "✓ Checking Agent..."
pgrep -f "dart run agent" > /dev/null && echo "  ✅ Agent running" || echo "  ❌ Agent NOT running"

echo "✓ Checking Flutter..."
which flutter > /dev/null && echo "  ✅ Flutter installed" || echo "  ❌ Flutter NOT installed"

echo "✓ Checking Dart..."
which dart > /dev/null && echo "  ✅ Dart installed" || echo "  ❌ Dart NOT installed"

echo "✓ Checking Agent .env..."
test -f agent/.env && echo "  ✅ .env exists" || echo "  ❌ .env NOT found"

echo "✓ Checking Agent keys..."
ls agent/keys/*.atKeys > /dev/null 2>&1 && echo "  ✅ Keys found" || echo "  ❌ Keys NOT found"

echo ""
echo "Done!"
```

## 🆘 Getting Help

If you're still experiencing issues:

1. **Check Logs**:
   - Agent: `agent/logs/agent.log`
   - Flutter: Run with `flutter run --verbose`

2. **Search Issues**: [GitHub Issues](https://github.com/cconstab/personalagent/issues)

3. **Ask for Help**: [GitHub Discussions](https://github.com/cconstab/personalagent/discussions)

4. **Report Bug**: 
   - Include error messages
   - Include relevant logs
   - Include system info (OS, versions, etc.)
   - Steps to reproduce

## 📚 Related Documentation

- [README.md](../README.md) - Getting started
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [ATSIGN_ARCHITECTURE.md](guides/ATSIGN_ARCHITECTURE.md) - atPlatform details
- [OLLAMA_ONLY_MODE.md](guides/OLLAMA_ONLY_MODE.md) - Privacy mode
- [KEYCHAIN_AUTH.md](guides/KEYCHAIN_AUTH.md) - Authentication flow

---

**Last Updated**: October 14, 2025
