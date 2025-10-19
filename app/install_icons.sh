#!/bin/bash

# Install Generated Icons to Platform Directories
# Run this after generate_icons.sh

set -e

ICON_DIR="assets/icon/generated"

echo "📦 Installing icons to platform directories..."

# macOS
echo ""
echo "🍎 Installing macOS icons..."
if [ -d "macos/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
    cp "$ICON_DIR/macos/app_icon_1024.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
    cp "$ICON_DIR/macos/app_icon_512.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
    cp "$ICON_DIR/macos/app_icon_256.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
    cp "$ICON_DIR/macos/app_icon_128.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
    cp "$ICON_DIR/macos/app_icon_64.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
    cp "$ICON_DIR/macos/app_icon_32.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
    cp "$ICON_DIR/macos/app_icon_16.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
    echo "  ✓ macOS icons installed"
else
    echo "  ⚠️  macOS directory not found"
fi

# iOS (if exists)
echo ""
echo "📱 Installing iOS icons..."
if [ -d "ios/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
    cp "$ICON_DIR/ios/"*.png "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
    echo "  ✓ iOS icons installed"
else
    echo "  ⚠️  iOS directory not found (create it if needed)"
fi

# Android (if exists)
echo ""
echo "🤖 Installing Android icons..."
if [ -d "android/app/src/main/res" ]; then
    # Create mipmap directories if they don't exist
    mkdir -p android/app/src/main/res/mipmap-mdpi
    mkdir -p android/app/src/main/res/mipmap-hdpi
    mkdir -p android/app/src/main/res/mipmap-xhdpi
    mkdir -p android/app/src/main/res/mipmap-xxhdpi
    mkdir -p android/app/src/main/res/mipmap-xxxhdpi
    
    cp "$ICON_DIR/android/ic_launcher_mdpi.png" "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
    cp "$ICON_DIR/android/ic_launcher_hdpi.png" "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
    cp "$ICON_DIR/android/ic_launcher_xhdpi.png" "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
    cp "$ICON_DIR/android/ic_launcher_xxhdpi.png" "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
    cp "$ICON_DIR/android/ic_launcher.png" "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
    echo "  ✓ Android icons installed"
else
    echo "  ⚠️  Android directory not found"
fi

# Windows
echo ""
echo "🪟 Installing Windows icons..."
if [ -d "windows/runner/resources" ]; then
    cp "$ICON_DIR/windows/app_icon_256.png" "windows/runner/resources/app_icon.png"
    echo "  ✓ Windows icon installed"
else
    echo "  ⚠️  Windows directory not found"
fi

# Linux
echo ""
echo "🐧 Installing Linux icons..."
if [ -d "linux" ]; then
    cp "$ICON_DIR/linux/app_icon_128.png" "linux/app_icon.png"
    echo "  ✓ Linux icon installed"
else
    echo "  ⚠️  Linux directory not found"
fi

echo ""
echo "✅ Icon installation complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Clean and rebuild your app: flutter clean && flutter pub get"
echo "  2. Run on each platform to verify icons appear correctly"
echo ""
