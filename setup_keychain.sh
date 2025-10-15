#!/bin/bash

# One-time setup: Import .atKeys file into macOS keychain
# After this runs once, you never need to touch .atKeys files again!

ATSIGN="@cconstab"
ATKEYS_FILE="$HOME/.atsign/keys/${ATSIGN}_key.atKeys"

echo "🔐 Keychain Setup for Personal Agent"
echo "===================================="
echo ""

# Check if .atKeys file exists
if [ ! -f "$ATKEYS_FILE" ]; then
    echo "❌ Error: .atKeys file not found at: $ATKEYS_FILE"
    echo ""
    echo "Please ensure your .atKeys file is at:"
    echo "  $ATKEYS_FILE"
    exit 1
fi

echo "✅ Found .atKeys file: $ATKEYS_FILE"
echo ""

# The secret: We'll use the SDK's onboarding to import it
echo "📱 Starting Flutter app to import keys into keychain..."
echo ""
echo "INSTRUCTIONS:"
echo "1. App will open to onboarding screen"
echo "2. Click 'Get Started'"
echo "3. The SDK will show authentication options"
echo "4. Click 'Upload .atKeys file'"
echo "5. Select: $ATKEYS_FILE"
echo "6. Keys will be imported into macOS keychain"
echo "7. ✅ DONE! From now on, keys load automatically from keychain"
echo ""
echo "Press Enter to launch app..."
read

cd "$(dirname "$0")"
./run_app.sh
