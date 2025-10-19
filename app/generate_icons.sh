#!/bin/bash

# Icon Generation Script for Personal Agent App
# This script generates all required icon sizes from the base SVG

set -e

echo "🎨 Generating app icons for all platforms..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found. Installing via Homebrew..."
    brew install imagemagick
fi

# Base SVG file
SVG_FILE="assets/icon/app_icon.svg"
ICON_DIR="assets/icon/generated"

# Create output directory
mkdir -p "$ICON_DIR"

# Function to generate PNG from SVG
generate_icon() {
    local size=$1
    local output=$2
    echo "  Generating ${size}x${size} → $output"
    convert -background none -density 300 -resize "${size}x${size}" "$SVG_FILE" "$output"
}

echo ""
echo "📱 iOS Icons..."
mkdir -p "$ICON_DIR/ios"
generate_icon 1024 "$ICON_DIR/ios/app_icon_1024.png"
generate_icon 180 "$ICON_DIR/ios/app_icon_180.png"
generate_icon 167 "$ICON_DIR/ios/app_icon_167.png"
generate_icon 152 "$ICON_DIR/ios/app_icon_152.png"
generate_icon 120 "$ICON_DIR/ios/app_icon_120.png"
generate_icon 87 "$ICON_DIR/ios/app_icon_87.png"
generate_icon 80 "$ICON_DIR/ios/app_icon_80.png"
generate_icon 76 "$ICON_DIR/ios/app_icon_76.png"
generate_icon 60 "$ICON_DIR/ios/app_icon_60.png"
generate_icon 58 "$ICON_DIR/ios/app_icon_58.png"
generate_icon 40 "$ICON_DIR/ios/app_icon_40.png"
generate_icon 29 "$ICON_DIR/ios/app_icon_29.png"
generate_icon 20 "$ICON_DIR/ios/app_icon_20.png"

echo ""
echo "🍎 macOS Icons..."
mkdir -p "$ICON_DIR/macos"
generate_icon 1024 "$ICON_DIR/macos/app_icon_1024.png"
generate_icon 512 "$ICON_DIR/macos/app_icon_512.png"
generate_icon 256 "$ICON_DIR/macos/app_icon_256.png"
generate_icon 128 "$ICON_DIR/macos/app_icon_128.png"
generate_icon 64 "$ICON_DIR/macos/app_icon_64.png"
generate_icon 32 "$ICON_DIR/macos/app_icon_32.png"
generate_icon 16 "$ICON_DIR/macos/app_icon_16.png"

echo ""
echo "🤖 Android Icons..."
mkdir -p "$ICON_DIR/android"
generate_icon 192 "$ICON_DIR/android/ic_launcher.png"
generate_icon 144 "$ICON_DIR/android/ic_launcher_xxhdpi.png"
generate_icon 96 "$ICON_DIR/android/ic_launcher_xhdpi.png"
generate_icon 72 "$ICON_DIR/android/ic_launcher_hdpi.png"
generate_icon 48 "$ICON_DIR/android/ic_launcher_mdpi.png"

# Also create adaptive icons (foreground + background)
echo ""
echo "🎯 Android Adaptive Icons..."
# For adaptive icons, we'll create a foreground with padding
generate_icon 108 "$ICON_DIR/android/ic_launcher_foreground.png"

echo ""
echo "🪟 Windows Icons..."
mkdir -p "$ICON_DIR/windows"
generate_icon 256 "$ICON_DIR/windows/app_icon_256.png"
generate_icon 128 "$ICON_DIR/windows/app_icon_128.png"
generate_icon 64 "$ICON_DIR/windows/app_icon_64.png"
generate_icon 48 "$ICON_DIR/windows/app_icon_48.png"
generate_icon 32 "$ICON_DIR/windows/app_icon_32.png"
generate_icon 16 "$ICON_DIR/windows/app_icon_16.png"

echo ""
echo "🐧 Linux Icons..."
mkdir -p "$ICON_DIR/linux"
generate_icon 512 "$ICON_DIR/linux/app_icon_512.png"
generate_icon 256 "$ICON_DIR/linux/app_icon_256.png"
generate_icon 128 "$ICON_DIR/linux/app_icon_128.png"
generate_icon 64 "$ICON_DIR/linux/app_icon_64.png"
generate_icon 48 "$ICON_DIR/linux/app_icon_48.png"
generate_icon 32 "$ICON_DIR/linux/app_icon_32.png"

echo ""
echo "✅ Icon generation complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Copy icons to their respective platform directories:"
echo "     - macOS: macos/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "     - iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "     - Android: android/app/src/main/res/mipmap-*/"
echo "     - Windows: windows/runner/resources/"
echo "     - Linux: linux/"
echo ""
echo "  2. Or use the install_icons.sh script to copy them automatically"
echo ""
