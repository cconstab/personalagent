#!/bin/bash
# Script to clear corrupted keychain entry and app preferences
# This does NOT delete your .atKeys file - you can use that to re-onboard

echo "🔧 Clearing corrupted @cconstab keychain entry and app data..."

# 1. Clear macOS Keychain entries for @cconstab
echo "  → Clearing macOS Keychain..."
# The atPlatform SDK stores keys with these service names
security delete-generic-password -s "@cconstab" 2>/dev/null || true
security delete-generic-password -a "@cconstab" 2>/dev/null || true
security delete-generic-password -s "atSign" -a "@cconstab" 2>/dev/null || true

# 2. Clear Flutter app containers and preferences
echo "  → Clearing Flutter app data..."
rm -rf ~/Library/Containers/com.example.personalAgentApp 2>/dev/null || true
rm -rf ~/Library/Application\ Support/com.example.personalAgentApp 2>/dev/null || true

echo ""
echo "✅ Corrupted keychain entry and app data cleared!"
echo ""
echo "Your @cconstab_key.atKeys file is still safe at:"
echo "  ~/.atsign/keys/@cconstab_key.atKeys"
echo ""
echo "Now run: ./run_app.sh"
echo ""
echo "The app will start fresh and you can onboard using:"
echo "  Option 1: Upload your @cconstab_key.atKeys file (recommended)"
echo "  Option 2: Use APKAM enrollment via @atsign Authenticator app"
